package com.ivy.settings

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Checks GitHub Releases of the app's own repo for a newer version, downloads
 * the right APK and hands it to Android's installer. The repo is public, so
 * the releases API needs no account and no token.
 */
object UpdateChecker {

    private const val REPO = "ctmhod/Walletify"
    private const val LATEST_URL =
        "https://api.github.com/repos/$REPO/releases/latest"
    private const val ASSET_PREFIX = "Walletify-v"

    data class Update(
        val tag: String,
        val assetName: String,
        val assetUrl: String,
        val sizeBytes: Long,
    )

    sealed class CheckResult {
        data object Latest : CheckResult()
        data class Available(val update: Update) : CheckResult()
        data class Error(val message: String) : CheckResult()
    }

    suspend fun check(currentVersion: String): CheckResult = withContext(Dispatchers.IO) {
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(LATEST_URL).openConnection() as HttpURLConnection).apply {
                setRequestProperty("Accept", "application/vnd.github+json")
                setRequestProperty("User-Agent", "Walletify-update-check")
                connectTimeout = 15000
                readTimeout = 20000
            }
            if (conn.responseCode != 200) {
                return@withContext CheckResult.Error("GitHub returned HTTP ${conn.responseCode}")
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val rel = JSONObject(body)
            val tag = rel.optString("tag_name", "")
            if (!isNewer(tag, currentVersion)) {
                return@withContext CheckResult.Latest
            }
            val assets = rel.optJSONArray("assets")
            var update: Update? = null
            if (assets != null) {
                // Prefer the APK for the device's own ABI (arm64 on most phones).
                for (abi in Build.SUPPORTED_ABIS) {
                    for (i in 0 until assets.length()) {
                        val a = assets.getJSONObject(i)
                        val n = a.optString("name", "")
                        if (n.startsWith(ASSET_PREFIX) && n.endsWith(".apk") && n.contains(abi)) {
                            update = Update(
                                tag = tag,
                                assetName = n,
                                assetUrl = a.optString("browser_download_url"),
                                sizeBytes = a.optLong("size"),
                            )
                            break
                        }
                    }
                    if (update != null) break
                }
                // Fall back to the universal APK.
                if (update == null) {
                    for (i in 0 until assets.length()) {
                        val a = assets.getJSONObject(i)
                        val n = a.optString("name", "")
                        if (n.startsWith(ASSET_PREFIX) && n.endsWith(".apk") &&
                            n.contains("universal")
                        ) {
                            update = Update(
                                tag = tag,
                                assetName = n,
                                assetUrl = a.optString("browser_download_url"),
                                sizeBytes = a.optLong("size"),
                            )
                            break
                        }
                    }
                }
            }
            val found = update
            if (found == null || found.assetUrl.isBlank()) {
                CheckResult.Error("No APK found in release $tag")
            } else {
                CheckResult.Available(found)
            }
        } catch (e: Exception) {
            CheckResult.Error(e.message ?: e.javaClass.simpleName)
        } finally {
            conn?.disconnect()
        }
    }

    suspend fun download(
        url: String,
        dest: File,
        onProgress: (percent: Int) -> Unit,
    ): Result<File> = withContext(Dispatchers.IO) {
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                setRequestProperty("User-Agent", "Walletify-update-check")
                connectTimeout = 15000
                readTimeout = 30000
            }
            if (conn.responseCode != 200) {
                return@withContext Result.failure(Exception("HTTP ${conn.responseCode}"))
            }
            val total = conn.contentLength.toLong()
            dest.parentFile?.mkdirs()
            conn.inputStream.use { input ->
                dest.outputStream().use { out ->
                    val buf = ByteArray(16384)
                    var got = 0L
                    var lastPct = -1
                    while (true) {
                        val n = input.read(buf)
                        if (n == -1) break
                        out.write(buf, 0, n)
                        got += n
                        if (total > 0) {
                            val pct = (got * 100 / total).toInt()
                            if (pct != lastPct) {
                                lastPct = pct
                                onProgress(pct)
                            }
                        }
                    }
                }
            }
            if (total > 0 && dest.length() != total) {
                return@withContext Result.failure(Exception("Download incomplete"))
            }
            Result.success(dest)
        } catch (e: Exception) {
            dest.delete()
            Result.failure(e)
        } finally {
            conn?.disconnect()
        }
    }

    /** True when the app may request package installs without asking the user first. */
    fun canInstall(activity: Activity): Boolean =
        Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()

    /** Opens the system screen where the user allows this app to install APKs. */
    fun openInstallPermission(activity: Activity) {
        activity.startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            )
        )
    }

    /** Hands the downloaded APK to Android's package installer (shows the install prompt). */
    fun install(activity: Activity, apk: File) {
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    /** Numeric compare: "v0.1.52" is newer than "0.1.51". Missing parts count as 0. */
    fun isNewer(tag: String, current: String): Boolean {
        val a = parts(tag)
        val b = parts(current)
        val len = maxOf(a.size, b.size)
        for (i in 0 until len) {
            val x = a.getOrElse(i) { 0 }
            val y = b.getOrElse(i) { 0 }
            if (x != y) return x > y
        }
        return false
    }

    private fun parts(version: String): List<Int> {
        var v = version.trim()
        if (v.startsWith("v") || v.startsWith("V")) v = v.substring(1)
        if (v.isEmpty()) return emptyList()
        return v.split('.', '-').map { part ->
            part.takeWhile { it.isDigit() }.toIntOrNull() ?: 0
        }
    }
}
