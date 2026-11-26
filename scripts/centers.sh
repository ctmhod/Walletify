#!/usr/bin/env bash
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell wm size 1080x2400; adb shell wm density 420
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-700)" | tee -a "$OUT/screens.txt"; }
alive() { adb shell pidof $PKG >/dev/null 2>&1 && echo alive || { echo "APP DIED at $1" | tee -a "$OUT/screens.txt"; }; }
back() { adb shell input keyevent 4; sleep 2; }
# agreement, once
sleep 5
python3 $U tap-first CheckBox; sleep 1
for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
snap agreement-ticked
python3 $U tap-bottom; sleep 5
# onboarding: loop until Home is visible
for k in $(seq 1 12); do
  T=$(python3 $U texts)
  case "$T" in *"Adjust your initial balance"*|*"No transactions"*) break;; esac
  case "$T" in
    *"Offline account"*) python3 $U tap-text "Offline account"; sleep 4;;
    *"Start fresh"*) python3 $U tap-text "Start fresh"; sleep 3;;
    *"Set currency"*) python3 $U tap-text "Set"; sleep 3;;
    *"Add accounts"*|*"Add categories"*) python3 $U tap-text "Skip"; sleep 3;;
    *) sleep 3;;
  esac
done
snap home
python3 $U tap-text prompt_dismiss; sleep 2
snap home-after-dismiss
python3 $U centers | tee "$OUT/centers.txt"
adb shell uiautomator dump /sdcard/u.xml >/dev/null; adb exec-out cat /sdcard/u.xml > "$OUT/home.xml"
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
