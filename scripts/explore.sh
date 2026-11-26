#!/usr/bin/env bash
# Discovery crawl: install, launch, dump texts and screenshots at each step.
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts)" | tee -a "$OUT/screens.txt"; }
snap launch
python3 $U tap-checkables; sleep 2; snap checked
for t in "Continue" "Accept" "I agree" "Agree" "Next" "Start" "Get started" "Skip" "Done" "OK" "Later" "Not now" "Maybe later"; do
  for k in 1 2; do python3 $U tap-text "$t" && { sleep 3; snap "after-$t"; }; done
done
for k in 1 2 3 4 5 6; do
  for t in "Continue" "Next" "Skip" "Done" "Finish" "Start" "Set" "Set up" "OK" "Close" "Dismiss"; do python3 $U tap-text "$t" && { sleep 3; snap "step-$t"; break; }; done
done
sleep 2; snap final
adb logcat -d > "$OUT/logcat.txt"
adb shell pidof $PKG | tee "$OUT/pid.txt"
grep -E "FATAL EXCEPTION" -A12 "$OUT/logcat.txt" | head -40
true
