package com.ivy.settings

import android.app.Activity
import android.content.Context
import com.ivy.base.errorlog.ErrorLog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * Process-wide owner of the self-update flow. The settings dialog only shows
 * this state, so closing the dialog never cancels a check, a download or an
 * install, and a second tap attaches to the run already in flight instead of
 * starting a parallel one (which used to flip the dialog between old and new
 * states and download several copies of the same APK).
 */
object UpdateManager {

    sealed interface State {
        data object Idle : State
        data object Checking : State
        data object Latest : State
        data class Available(val update: UpdateChecker.Update) : State
        data class Downloading(val update: UpdateChecker.Update, val percent: Int) : State
        data class Ready(val update: UpdateChecker.Update, val needPermission: Boolean = false) : State
        data class Failed(val update: UpdateChecker.Update?, val wasDownload: Boolean) : State
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state.asStateFlow()

    private lateinit var appContext: Context
    private var checkJob: Job? = null
    private var downloadJob: Job? = null

    /**
     * Set when the user is sent to the system "install unknown apps" screen.
     * On the next resume with the permission granted, the installer starts
     * directly, exactly once, then the flag is consumed. Returning from the
     * installer itself never re-triggers it, so there is no loop.
     */
    private var installAfterPermission = false

    fun init(context: Context) {
        if (!::appContext.isInitialized) appContext = context.applicationContext
    }

    private fun updatesDir(): File = File(appContext.cacheDir, "updates")
    private fun apkFor(tag: String): File = File(updatesDir(), "walletify-update-$tag.apk")

    private fun log(message: String) {
        runCatching { ErrorLog.record("UpdateManager: $message") }
    }

    /** Single-flight check: a tap while one runs just re-shows its state. */
    fun check(currentVersion: String) {
        if (checkJob?.isActive == true || downloadJob?.isActive == true) return
        checkJob = scope.launch {
            _state.value = State.Checking
            log("check started (installed $currentVersion)")
            _state.value = when (val r = UpdateChecker.check(currentVersion)) {
                UpdateChecker.CheckResult.Latest -> {
                    log("already on the latest version")
                    State.Latest
                }
                is UpdateChecker.CheckResult.Available -> {
                    log("update available: ${r.update.tag}")
                    State.Available(r.update)
                }
                is UpdateChecker.CheckResult.Error -> {
                    log("check failed: ${r.message}")
                    State.Failed(null, wasDownload = false)
                }
            }
        }
    }

    /**
     * Single-flight download. A second tap while a download runs attaches to
     * it. A complete APK for the same tag (size matches the release asset) is
     * reused instead of downloading again. The download goes to a .part file
     * that is renamed only when complete, and every other file in updates/
     * (old versions, partial downloads) is deleted first.
     */
    fun download(update: UpdateChecker.Update) {
        if (downloadJob?.isActive == true) return

        val apk = apkFor(update.tag)
        if (apk.exists() && (update.sizeBytes <= 0 || apk.length() == update.sizeBytes)) {
            val removed = cleanExcept(apk)
            log("reusing complete APK for ${update.tag} (removed $removed stale file(s))")
            _state.value = State.Ready(update)
            return
        }

        downloadJob = scope.launch {
            _state.value = State.Downloading(update, 0)
            val removed = cleanExcept(null)
            val part = File(updatesDir(), apk.name + ".part")
            part.delete()
            log("download started: ${update.tag} (removed $removed stale file(s))")
            val res = UpdateChecker.download(update.assetUrl, part) { p ->
                _state.value = State.Downloading(update, p)
            }
            _state.value = if (res.isSuccess) {
                apk.delete()
                if (part.renameTo(apk)) {
                    log("download complete: ${update.tag}")
                    State.Ready(update)
                } else {
                    part.delete()
                    log("download failed: could not finalize file")
                    State.Failed(update, wasDownload = true)
                }
            } else {
                part.delete()
                val msg = res.exceptionOrNull()?.message ?: "unknown error"
                log("download failed: $msg")
                State.Failed(update, wasDownload = true)
            }
        }
    }

    /** Tap on Install: ask for the permission when needed, else install now. */
    fun install(activity: Activity) {
        val s = _state.value as? State.Ready ?: return
        val apk = apkFor(s.update.tag)
        if (!apk.exists()) {
            log("install failed: APK missing")
            _state.value = State.Failed(s.update, wasDownload = true)
            return
        }
        if (!UpdateChecker.canInstall(activity)) {
            installAfterPermission = true
            _state.value = s.copy(needPermission = true)
            log("unknown-apps permission needed, opening system settings")
            UpdateChecker.openInstallPermission(activity)
        } else {
            log("installer launched for ${s.update.tag}")
            UpdateChecker.install(activity, apk)
        }
    }

    /**
     * Called on every activity resume. When the user comes back from the
     * permission screen with the permission granted, the installer starts
     * directly, exactly once. No extra screen, no duplicate installer, no loop.
     */
    fun onActivityResumed(activity: Activity) {
        if (!installAfterPermission) return
        val s = _state.value as? State.Ready ?: return
        if (!UpdateChecker.canInstall(activity)) return
        installAfterPermission = false
        _state.value = s.copy(needPermission = false)
        val apk = apkFor(s.update.tag)
        if (apk.exists()) {
            log("permission granted, launching installer once")
            UpdateChecker.install(activity, apk)
        }
    }

    /** Deletes every file in updates/ except [keep]; returns how many were removed. */
    private fun cleanExcept(keep: File?): Int {
        var removed = 0
        updatesDir().listFiles()?.forEach { f ->
            if (keep == null || f.absolutePath != keep.absolutePath) {
                if (f.delete()) removed++
            }
        }
        return removed
    }
}
