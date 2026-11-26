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
python3 $U tap-class CheckBox; sleep 2; snap checkboxes

swipe_up; swipe_up; snap scrolled
for k in 1 2 3 4 5 6 7 8; do
  done_step=0
  for t in "Continue" "Next" "Skip" "Done" "Finish" "Start" "Agree" "Accept" "Get started" "Set" "OK" "Close"; do python3 $U tap-text "$t" && { sleep 3; snap "step-$t"; done_step=1; break; }; done
  [ $done_step = 0 ] && { swipe_up; snap "scroll$k"; }
done
adb logcat -d > "$OUT/logcat.txt"
adb shell pidof $PKG | tee "$OUT/pid.txt"
grep -E "FATAL EXCEPTION" -A12 "$OUT/logcat.txt" | head -40
true
