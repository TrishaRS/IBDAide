package com.ibdaide.app.core

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.ibdaide.app.MainActivity
import com.ibdaide.app.R
import com.ibdaide.app.data.AppDatabase
import com.ibdaide.app.data.Appointment
import com.ibdaide.app.data.DoseEvent
import com.ibdaide.app.data.Medication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * FR-7/FR-8 reminders via AlarmManager + local notifications.
 * Privacy: notification text is generic — no medication names or health details
 * on the lock screen. Med alarms reschedule themselves daily; boot receiver restores them.
 */
object Reminders {

    const val CHANNEL_ID = "reminders"

    fun createChannel(context: Context) {
        val channel = NotificationChannel(CHANNEL_ID, "Reminders", NotificationManager.IMPORTANCE_HIGH)
        channel.description = "Medication, refill, and appointment reminders"
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun alarmManager(context: Context) = context.getSystemService(AlarmManager::class.java)

    private fun canExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || alarmManager(context).canScheduleExactAlarms()

    private fun schedule(context: Context, at: Long, requestCode: Int, extras: Intent.() -> Unit) {
        if (at <= System.currentTimeMillis()) return
        val intent = Intent(context, ReminderReceiver::class.java).apply(extras)
        val pi = PendingIntent.getBroadcast(context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val am = alarmManager(context)
        if (canExact(context)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    }

    private fun cancel(context: Context, requestCode: Int) {
        val pi = PendingIntent.getBroadcast(context, requestCode, Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager(context).cancel(pi)
    }

    // Deterministic request codes from string ids
    private fun code(vararg parts: Any): Int = parts.joinToString("-").hashCode() and 0x7FFFFFFF

    // MARK: Medications — next occurrence of each daily time

    fun scheduleMedReminders(context: Context, med: Medication) {
        cancelMedReminders(context, med)
        if (!med.active || med.times.isEmpty()) return
        for (minutes in med.times) {
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, minutes / 60)
            cal.set(Calendar.MINUTE, minutes % 60)
            cal.set(Calendar.SECOND, 0)
            if (cal.timeInMillis <= System.currentTimeMillis()) cal.add(Calendar.DAY_OF_YEAR, 1)
            schedule(context, cal.timeInMillis, code("med", med.id, minutes)) {
                putExtra("kind", "med"); putExtra("medicationID", med.id); putExtra("minutes", minutes)
            }
        }
    }

    fun cancelMedReminders(context: Context, med: Medication) {
        for (minutes in med.times) cancel(context, code("med", med.id, minutes))
    }

    fun scheduleRefillAlert(context: Context, med: Medication, daysBefore: Int = 5) {
        cancel(context, code("refill", med.id))
        val refill = med.refillDate ?: return
        schedule(context, refill - daysBefore * 86_400_000L, code("refill", med.id)) {
            putExtra("kind", "refill")
        }
    }

    // MARK: Appointments

    fun scheduleAppointmentReminders(context: Context, appt: Appointment) {
        cancelAppointmentReminders(context, appt)
        for (hours in appt.offsets) {
            schedule(context, appt.date - hours * 3_600_000L, code("appt", appt.id, hours)) {
                putExtra("kind", "appt")
            }
        }
    }

    fun cancelAppointmentReminders(context: Context, appt: Appointment) {
        for (hours in appt.offsets) cancel(context, code("appt", appt.id, hours))
    }

    /** Restore all alarms (after boot or app start). */
    fun rescheduleAll(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            val dao = AppDatabase.get(context).dao()
            dao.meds().forEach {
                scheduleMedReminders(context, it)
                scheduleRefillAlert(context, it)
            }
            dao.appointments().filter { it.date > System.currentTimeMillis() }
                .forEach { scheduleAppointmentReminders(context, it) }
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.createChannel(context)
        val kind = intent.getStringExtra("kind") ?: "med"
        val medicationID = intent.getStringExtra("medicationID")
        val minutes = intent.getIntExtra("minutes", -1)

        val body = when (kind) {
            "appt" -> "You have an upcoming appointment."
            "refill" -> "A refill is coming up."
            else -> "You have a medication reminder."
        }

        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val builder = NotificationCompat.Builder(context, Reminders.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentTitle("IBD Aide")
            .setContentText(body)             // generic on purpose — no health details
            .setContentIntent(open)
            .setAutoCancel(true)

        if (kind == "med" && medicationID != null) {
            fun action(label: String, status: String): NotificationCompat.Action {
                val actionIntent = Intent(context, DoseActionReceiver::class.java).apply {
                    putExtra("medicationID", medicationID)
                    putExtra("minutes", minutes)
                    putExtra("status", status)
                }
                val pi = PendingIntent.getBroadcast(context, ("$medicationID-$minutes-$status").hashCode(),
                    actionIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                return NotificationCompat.Action(0, label, pi)
            }
            builder.addAction(action("Taken", "taken")).addAction(action("Skip", "skipped"))
        }

        runCatching {
            context.getSystemService(NotificationManager::class.java)
                .notify(("$kind-$medicationID-$minutes").hashCode(), builder.build())
        }

        // Reschedule tomorrow's occurrence for daily med reminders.
        if (kind == "med" && medicationID != null) {
            CoroutineScope(Dispatchers.IO).launch {
                AppDatabase.get(context).dao().med(medicationID)?.let {
                    Reminders.scheduleMedReminders(context, it)
                }
            }
        }
    }
}

class DoseActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val medicationID = intent.getStringExtra("medicationID") ?: return
        val minutes = intent.getIntExtra("minutes", 0)
        val status = intent.getStringExtra("status") ?: "taken"
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val dao = AppDatabase.get(context).dao()
                val cal = Calendar.getInstance()
                cal.set(Calendar.HOUR_OF_DAY, minutes / 60); cal.set(Calendar.MINUTE, minutes % 60); cal.set(Calendar.SECOND, 0)
                dao.insert(DoseEvent(medicationID = medicationID, scheduledAt = cal.timeInMillis, status = status))
                if (status == "taken") {
                    dao.med(medicationID)?.let { med ->
                        med.pillsRemaining?.takeIf { it > 0 }?.let { dao.upsert(med.copy(pillsRemaining = it - 1)) }
                    }
                }
                context.getSystemService(NotificationManager::class.java)
                    .notify(("med-$medicationID-$minutes").hashCode(), // replace with silent dismissal
                        NotificationCompat.Builder(context, Reminders.CHANNEL_ID)
                            .setSmallIcon(R.mipmap.ic_launcher_foreground)
                            .setContentTitle("IBD Aide").setContentText("Recorded.").setTimeoutAfter(1500).build())
            } finally {
                pending.finish()
            }
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.rescheduleAll(context)
    }
}
