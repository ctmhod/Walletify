package com.ivy.wallet

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.ivy.base.errorlog.ErrorLog
import com.ivy.base.legacy.appContext
import dagger.hilt.android.HiltAndroidApp
import timber.log.Timber
import timber.log.Timber.DebugTree
import javax.inject.Inject

private class ErrorLogTree : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        if (priority >= android.util.Log.ERROR) {
            ErrorLog.record("${tag.orEmpty()}: $message", t)
        }
    }
}

/**
 * Created by iliyan on 24.02.18.
 */
@HiltAndroidApp
class IvyAndroidApp : Application(), Configuration.Provider,
    com.ivy.wallet.domain.deprecated.logic.notification.TransactionReminderDepsOwner {
    @Inject lateinit var rTransactionDao: com.ivy.data.db.dao.read.TransactionDao
    @Inject lateinit var rNotificationService: com.ivy.wallet.android.notification.NotificationService
    @Inject lateinit var rSharedPrefs: com.ivy.base.legacy.SharedPrefs
    @Inject lateinit var rAppStarter: com.ivy.domain.AppStarter
    @Inject lateinit var rTimeProvider: com.ivy.base.time.TimeProvider
    @Inject lateinit var rTimeConverter: com.ivy.base.time.TimeConverter

    override fun reminderDeps() =
        com.ivy.wallet.domain.deprecated.logic.notification.TransactionReminderDeps(
            rTransactionDao, rNotificationService, rSharedPrefs,
            rAppStarter, rTimeProvider, rTimeConverter
        )

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        appContext = this
        ErrorLog.init(this)
        Timber.plant(ErrorLogTree())

        if (BuildConfig.DEBUG) {
            Timber.plant(DebugTree())
        }
    }
}
