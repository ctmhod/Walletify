#!/usr/bin/env bash
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell wm size 1080x2400; adb shell wm density 420
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-300)" | tee -a "$OUT/screens.txt"; }
snap agreement-initial
python3 $U tap-first CheckBox; sleep 1
snap agree-all-ticked
python3 $U tap-text "I understand there is no warranty for the accuracy, reliability, or completeness of my data. Manual data backup is my responsibility, and I agree to not hold the app liable for any data loss."; sleep 1
snap one-unticked
python3 $U tap-first CheckBox; sleep 1
snap agree-all-again
for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
snap bottom
python3 $U tap-bottom; sleep 5
snap after-agree
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
