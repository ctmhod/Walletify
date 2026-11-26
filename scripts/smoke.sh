#!/usr/bin/env bash
# Runs inside the emulator: install the APK, launch, screenshot, check for crashes.
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"
adb logcat -c
adb install -r "$APK" 2>&1 | tee "$OUT/install.txt"
grep -q Success "$OUT/install.txt" || { echo "INSTALL FAILED"; exit 1; }
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 12
adb exec-out screencap -p > "$OUT/01-launch.png"
# tap through onboarding a few times (centre-bottom area), screenshot each step
W=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f2)
for i in 2 3 4 5; do
  adb shell input tap $((W/2)) $((H*85/100)); sleep 4
  adb exec-out screencap -p > "$OUT/0$i-step.png"
done
adb logcat -d > "$OUT/logcat.txt"
PID=$(adb shell pidof $PKG | tr -d '\r')
echo "pid=$PID" | tee "$OUT/result.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then echo "CRASH DETECTED" | tee -a "$OUT/result.txt"; grep -A15 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -40 | tee -a "$OUT/result.txt"; exit 2; fi
[ -n "$PID" ] && echo "APP ALIVE after launch and taps" | tee -a "$OUT/result.txt" || { echo "APP NOT RUNNING" | tee -a "$OUT/result.txt"; exit 3; }
