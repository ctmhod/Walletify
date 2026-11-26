package com.ivy.legacy.utils

// Walletify is fully offline: no crash reporting or telemetry.
fun sendToCrashlytics(
    msg: String
) {
    DeveloperException(msg)
}

@Suppress("UnusedReceiverParameter", "UNUSED_PARAMETER")
fun Exception.sendToCrashlytics(
    clarification: String? = null
) {
    // no-op
}

@Suppress("UNUSED_PARAMETER")
fun logToCrashlytics(msg: String) {
    // no-op
}

class DeveloperException(msg: String) : Exception(msg)
