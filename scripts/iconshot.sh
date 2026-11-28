#!/usr/bin/env bash
# Screenshot the launcher icon on the emulator home screen and app drawer.
# Usage: iconshot.sh APK OUTDIR
set -u
APK="$1"; OUT="$2"; mkdir -p "$OUT"
adb install -r "$APK"
adb shell wm size 1080x2400; adb shell wm density 420
sleep 2
adb shell input keyevent KEYCODE_HOME; sleep 5
adb exec-out screencap -p > "$OUT/home.png"
adb shell input swipe 540 2200 540 800 400; sleep 5
adb exec-out screencap -p > "$OUT/drawer.png"
adb shell input swipe 540 800 540 2200 400; sleep 2
adb exec-out screencap -p > "$OUT/home2.png"
