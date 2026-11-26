package com.ivy.base.errorlog

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Local-only error log. Stores redacted errors and uncaught crashes in a private file.
 * Nothing is ever sent anywhere.
 */
object ErrorLog {
    private const val FILE_NAME = "walletify-error.log"
    private const val MAX_BYTES = 200_000
    private const val SEPARATOR = "\n----\n"

    @Volatile
    private var file: File? = null

    private val redactions = listOf(
        Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}") to "<email>",
        Regex("(?i)(https?://[^\\s?#]+)[^\\s]*") to "$1",
        Regex("(?i)(token|password|passwd|secret|authorization|api[_-]?key)\\s*[=:]\\s*\\S+") to "$1=<redacted>",
        Regex("\\+?\\d[\\d\\s().-]{7,}\\d") to "<number>",
        Regex("/(?:data|storage|sdcard)/[^\\s:)]+") to "<path>",
    )

    fun init(context: Context) {
        file = File(context.applicationContext.filesDir, FILE_NAME)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                record("CRASH on thread ${thread.name}", throwable)
            } catch (ignored: Throwable) {
                // never block the original crash handling
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    @Synchronized
    fun record(message: String, throwable: Throwable? = null) {
        val f = file ?: return
        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val body = buildString {
            append(message)
            if (throwable != null) {
                append('\n').append(throwable.stackTraceToString())
            }
        }
        val entry = "[$time] ${redact(body)}"
        val old = if (f.exists()) f.readText() else ""
        var all = if (old.isEmpty()) entry else old + SEPARATOR + entry
        if (all.length > MAX_BYTES) all = all.takeLast(MAX_BYTES)
        f.writeText(all)
    }

    @Synchronized
    fun read(): String = file?.takeIf { it.exists() }?.readText().orEmpty()

    @Synchronized
    fun clear() {
        file?.delete()
    }

    fun redact(text: String): String =
        redactions.fold(text) { acc, (regex, replacement) -> regex.replace(acc, replacement) }
}
