package com.ibdaide.app

import android.app.Application
import com.ibdaide.app.core.Reminders
import com.ibdaide.app.data.AppDatabase

class IBDAideApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AppDatabase.get(this)
        Reminders.createChannel(this)
        Reminders.rescheduleAll(this)
    }
}
