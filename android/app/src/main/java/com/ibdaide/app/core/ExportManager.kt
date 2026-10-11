package com.ibdaide.app.core

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.Appointment
import com.ibdaide.app.data.BowelMovementEntry
import com.ibdaide.app.data.DoseEvent
import com.ibdaide.app.data.FoodEntry
import com.ibdaide.app.data.HydrationEntry
import com.ibdaide.app.data.Medication
import com.ibdaide.app.data.Provider
import com.ibdaide.app.data.QoLCheckin
import com.ibdaide.app.data.SymptomEntry
import com.ibdaide.app.data.TriggerFood
import com.ibdaide.app.data.UserProfile
import com.ibdaide.app.data.VisitQuestion
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * FR-14b: manual encrypted export/import.
 * File layout: [16-byte salt][12-byte nonce][ciphertext+16-byte GCM tag]
 * Key: PBKDF2-HMAC-SHA256, 600,000 iterations → AES-256.
 * JSON schema and byte layout match the iOS export for future cross-platform restore.
 */

// DTO field names mirror the iOS ExportEnvelope (dates as ISO-8601 strings).
class ExportEnvelope {
    var schemaVersion = 1
    var app = "IBD Aide Android"
    var exportedAt = ""

    class ProfileDTO { var name = ""; var diagnosis = ""; var diagnosisDate: String? = null; var flareMode = false }
    class SymptomDTO {
        var date = ""; var abdominalPain: Int? = null; var wellbeing: Int? = null; var fatigue: Int? = null
        var nausea = false; var jointPain = false; var skinIssues = false; var eyeIssues = false; var mouthUlcers = false
        var weightLbs: Double? = null; var sleepHours: Double? = null; var mood: Int? = null; var notes = ""
    }
    class BMDTO { var date = ""; var bristol = 4; var blood = false; var urgency = 0; var nighttime = false }
    class FoodDTO { var date = ""; var name = ""; var caffeine = false; var alcohol = false; var source = "manual" }
    class TriggerDTO { var name = ""; var origin = "user" }
    class HydrationDTO { var date = ""; var glasses = 1 }
    class MedDTO {
        var id = ""; var name = ""; var dose = ""; var kind = ""; var prescriber = ""
        var scheduleTimes: List<Int> = emptyList(); var intervalWeeks: Int? = null
        var pillsRemaining: Int? = null; var refillDate: String? = null; var active = true
    }
    class DoseDTO { var medicationID = ""; var scheduledAt = ""; var recordedAt = ""; var status = "taken" }
    class ProviderDTO {
        var id = ""; var name = ""; var role = ""; var phone = ""; var email = ""
        var address = ""; var portalURL = ""; var notes = ""
    }
    class ApptDTO {
        var type = ""; var date = ""; var providerID: String? = null; var locationNote = ""
        var recurringWeeks: Int? = null; var reminderOffsetsHours: List<Int> = emptyList()
        var preVisitNotes = ""; var postVisitNotes = ""; var prepDone: List<String> = emptyList()
    }
    class QuestionDTO { var text = ""; var createdAt = ""; var asked = false }
    class QoLDTO { var date = ""; var answers: List<Int> = emptyList(); var total = 0 }

    var profile: ProfileDTO? = null
    var symptoms: List<SymptomDTO> = emptyList()
    var bowelMovements: List<BMDTO> = emptyList()
    var foods: List<FoodDTO> = emptyList()
    var triggers: List<TriggerDTO> = emptyList()
    var hydration: List<HydrationDTO> = emptyList()
    var medications: List<MedDTO> = emptyList()
    var doses: List<DoseDTO> = emptyList()
    var providers: List<ProviderDTO> = emptyList()
    var appointments: List<ApptDTO> = emptyList()
    var questions: List<QuestionDTO> = emptyList()
    var qolCheckins: List<QoLDTO> = emptyList()
}

object ExportManager {

    private val gson: Gson = GsonBuilder().disableHtmlEscaping().create()

    private val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }
    private fun fmt(millis: Long): String = iso.format(Date(millis))
    private fun parse(s: String?): Long = s?.let { runCatching { iso.parse(it)?.time }.getOrNull() } ?: System.currentTimeMillis()

    // MARK: Build / apply

    suspend fun buildEnvelope(dao: AppDao): ExportEnvelope {
        val env = ExportEnvelope()
        env.exportedAt = fmt(System.currentTimeMillis())
        dao.profile()?.let { p ->
            env.profile = ExportEnvelope.ProfileDTO().apply {
                name = p.name; diagnosis = p.diagnosisRaw
                diagnosisDate = p.diagnosisDate?.let(::fmt); flareMode = p.flareMode
            }
        }
        env.symptoms = dao.symptoms().map { s ->
            ExportEnvelope.SymptomDTO().apply {
                date = fmt(s.date); abdominalPain = s.abdominalPain; wellbeing = s.wellbeing; fatigue = s.fatigue
                nausea = s.nausea; jointPain = s.jointPain; skinIssues = s.skinIssues; eyeIssues = s.eyeIssues
                mouthUlcers = s.mouthUlcers; weightLbs = s.weightLbs; sleepHours = s.sleepHours; mood = s.mood; notes = s.notes
            }
        }
        env.bowelMovements = dao.bms().map { b ->
            ExportEnvelope.BMDTO().apply { date = fmt(b.date); bristol = b.bristol; blood = b.blood; urgency = b.urgency; nighttime = b.nighttime }
        }
        env.foods = dao.foods().map { f ->
            ExportEnvelope.FoodDTO().apply { date = fmt(f.date); name = f.name; caffeine = f.caffeine; alcohol = f.alcohol; source = f.source }
        }
        env.triggers = dao.triggers().map { t -> ExportEnvelope.TriggerDTO().apply { name = t.name; origin = t.origin } }
        env.hydration = dao.hydration().map { h -> ExportEnvelope.HydrationDTO().apply { date = fmt(h.date); glasses = h.glasses } }
        env.medications = dao.meds().map { m ->
            ExportEnvelope.MedDTO().apply {
                id = m.id; name = m.name; dose = m.dose; kind = m.kindRaw; prescriber = m.prescriber
                scheduleTimes = m.times; intervalWeeks = m.intervalWeeks
                pillsRemaining = m.pillsRemaining; refillDate = m.refillDate?.let(::fmt); active = m.active
            }
        }
        env.doses = dao.doses().map { d ->
            ExportEnvelope.DoseDTO().apply { medicationID = d.medicationID; scheduledAt = fmt(d.scheduledAt); recordedAt = fmt(d.recordedAt); status = d.status }
        }
        env.providers = dao.providers().map { p ->
            ExportEnvelope.ProviderDTO().apply {
                id = p.id; name = p.name; role = p.roleRaw; phone = p.phone; email = p.email
                address = p.address; portalURL = p.portalURL; notes = p.notes
            }
        }
        env.appointments = dao.appointments().map { a ->
            ExportEnvelope.ApptDTO().apply {
                type = a.typeRaw; date = fmt(a.date); providerID = a.providerID; locationNote = a.locationNote
                recurringWeeks = a.recurringWeeks; reminderOffsetsHours = a.offsets
                preVisitNotes = a.preVisitNotes; postVisitNotes = a.postVisitNotes; prepDone = a.prepDoneSet.toList()
            }
        }
        env.questions = dao.questions().map { q ->
            ExportEnvelope.QuestionDTO().apply { text = q.text; createdAt = fmt(q.createdAt); asked = q.asked }
        }
        env.qolCheckins = dao.qol().map { q ->
            ExportEnvelope.QoLDTO().apply {
                date = fmt(q.date); answers = q.answers.split(",").mapNotNull { it.trim().toIntOrNull() }; total = q.total
            }
        }
        return env
    }

    /** Replaces all data with the envelope contents. */
    suspend fun apply(env: ExportEnvelope, dao: AppDao) {
        dao.wipeAll()
        val p = UserProfile(
            name = env.profile?.name ?: "",
            diagnosisRaw = env.profile?.diagnosis ?: "Crohn's disease",
            diagnosisDate = env.profile?.diagnosisDate?.let(::parse),
            flareMode = env.profile?.flareMode ?: false,
            onboarded = true,
        )
        dao.upsertProfile(p)
        env.symptoms.forEach { d ->
            dao.insert(SymptomEntry(date = parse(d.date), abdominalPain = d.abdominalPain, wellbeing = d.wellbeing,
                fatigue = d.fatigue, nausea = d.nausea, jointPain = d.jointPain, skinIssues = d.skinIssues,
                eyeIssues = d.eyeIssues, mouthUlcers = d.mouthUlcers, weightLbs = d.weightLbs,
                sleepHours = d.sleepHours, mood = d.mood, notes = d.notes))
        }
        env.bowelMovements.forEach { d ->
            dao.insert(BowelMovementEntry(date = parse(d.date), bristol = d.bristol, blood = d.blood,
                urgency = d.urgency, nighttime = d.nighttime))
        }
        env.foods.forEach { d ->
            dao.insert(FoodEntry(date = parse(d.date), name = d.name, caffeine = d.caffeine, alcohol = d.alcohol, source = d.source))
        }
        env.triggers.forEach { d -> dao.insert(TriggerFood(name = d.name, origin = d.origin)) }
        env.hydration.forEach { d -> dao.insert(HydrationEntry(date = parse(d.date), glasses = d.glasses)) }
        env.medications.forEach { d ->
            dao.upsert(Medication(id = d.id.ifEmpty { java.util.UUID.randomUUID().toString() },
                name = d.name, dose = d.dose, kindRaw = d.kind, prescriber = d.prescriber,
                scheduleTimes = d.scheduleTimes.joinToString(","), intervalWeeks = d.intervalWeeks,
                pillsRemaining = d.pillsRemaining, refillDate = d.refillDate?.let(::parse), active = d.active))
        }
        env.doses.forEach { d ->
            dao.insert(DoseEvent(medicationID = d.medicationID, scheduledAt = parse(d.scheduledAt),
                recordedAt = parse(d.recordedAt), status = d.status))
        }
        env.providers.forEach { d ->
            dao.upsert(Provider(id = d.id.ifEmpty { java.util.UUID.randomUUID().toString() },
                name = d.name, roleRaw = d.role, phone = d.phone, email = d.email,
                address = d.address, portalURL = d.portalURL, notes = d.notes))
        }
        env.appointments.forEach { d ->
            dao.upsert(Appointment(typeRaw = d.type, date = parse(d.date), providerID = d.providerID,
                locationNote = d.locationNote, recurringWeeks = d.recurringWeeks,
                reminderOffsetsHours = d.reminderOffsetsHours.joinToString(","),
                preVisitNotes = d.preVisitNotes, postVisitNotes = d.postVisitNotes,
                prepDone = d.prepDone.joinToString("\n")))
        }
        env.questions.forEach { d -> dao.upsert(VisitQuestion(text = d.text, createdAt = parse(d.createdAt), asked = d.asked)) }
        env.qolCheckins.forEach { d ->
            dao.insert(QoLCheckin(date = parse(d.date), answers = d.answers.joinToString(","), total = d.total))
        }
    }

    // MARK: Crypto (same layout as iOS: salt(16) + nonce(12) + ciphertext+tag)

    fun pbkdf2Key(passphrase: CharArray, salt: ByteArray, iterations: Int = 600_000): SecretKeySpec {
        val spec = PBEKeySpec(passphrase, salt, iterations, 256)
        val key = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        return SecretKeySpec(key, "AES")
    }

    fun encrypt(env: ExportEnvelope, passphrase: String): ByteArray {
        val json = gson.toJson(env).toByteArray(Charsets.UTF_8)
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, pbkdf2Key(passphrase.toCharArray(), salt), GCMParameterSpec(128, nonce))
        return salt + nonce + cipher.doFinal(json)
    }

    class BadPassphraseException : Exception("Wrong passphrase, or the file is damaged.")

    fun decrypt(data: ByteArray, passphrase: String): ExportEnvelope {
        if (data.size < 16 + 12 + 16) throw BadPassphraseException()
        val salt = data.copyOfRange(0, 16)
        val nonce = data.copyOfRange(16, 28)
        val ciphertext = data.copyOfRange(28, data.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, pbkdf2Key(passphrase.toCharArray(), salt), GCMParameterSpec(128, nonce))
        val json = try {
            cipher.doFinal(ciphertext)
        } catch (e: Exception) {
            throw BadPassphraseException()
        }
        return gson.fromJson(String(json, Charsets.UTF_8), ExportEnvelope::class.java)
            ?: throw BadPassphraseException()
    }
}
