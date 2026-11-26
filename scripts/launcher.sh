#!/usr/bin/env bash
APK="$1"; OUT="$2"; mkdir -p "$OUT"
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell wm size 1080x2400; adb shell wm density 420
adb shell monkey -p com.ctmhod.walletify -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 8
adb shell input keyevent 3; sleep 3
adb exec-out screencap -p > "$OUT/home-screen.png"
adb shell input swipe 540 1900 540 500 300; sleep 3
adb exec-out screencap -p > "$OUT/app-drawer.png"
adb shell monkey -p com.ctmhod.walletify -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 8
adb exec-out screencap -p > "$OUT/splash-or-first.png"
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
