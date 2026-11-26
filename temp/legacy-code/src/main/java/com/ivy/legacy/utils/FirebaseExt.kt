package com.ivy.legacy.utils

import com.ivy.base.errorlog.ErrorLog

// Walletify never sends errors anywhere: they go to the local, redacted error log only.
fun sendToCrashlytics(
    msg: String
) {
    ErrorLog.record(msg, DeveloperException(msg))
}

fun Exception.sendToCrashlytics(
    clarification: String? = null
) {
    ErrorLog.record(clarification ?: "Handled error", this)
}

fun logToCrashlytics(msg: String) {
    ErrorLog.record(msg)
}

class DeveloperException(msg: String) : Exception(msg)
