#!/usr/bin/env bash
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-900)" | tee -a "$OUT/screens.txt"; echo "   CLICK: $(python3 $U clickables | cut -c1-900)" | tee -a "$OUT/screens.txt"; }
adb shell wm size 1080x2400; adb shell wm density 420
W=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f2)
swipe_up() { adb shell input swipe $((W/2)) $((H*75/100)) $((W/2)) $((H*25/100)) 300; sleep 1; }
adb shell wm size 1080x2400; adb shell wm density 420; sleep 3
snap launch
python3 $U tap-first CheckBox; sleep 2; snap checkboxes

swipe_up; swipe_up; snap scrolled
adb shell input tap $((W/2)) $((H*90/100)); sleep 5; snap accepted
python3 $U tap-text "Offline account"; sleep 6; snap offline
for k in $(seq 1 10); do
  hit=0
  for t in "Offline account" "Continue" "Next" "Skip" "Done" "Finish" "Start" "Get started" "Let's go" "Later" "Not now" "OK" "Close" "Maybe later" "No thanks" "Set" "Create"; do python3 $U tap-text "$t" && { sleep 3; snap "step$k-$t"; hit=1; break; }; done
  if [ $hit = 0 ]; then adb shell input tap $((W/2)) $((H*90/100)); sleep 3; snap "step$k-bottom"; fi
done
adb logcat -d > "$OUT/logcat.txt"
adb shell pidof $PKG | tee "$OUT/pid.txt"
grep -E "FATAL EXCEPTION" -A12 "$OUT/logcat.txt" | head -40
true
