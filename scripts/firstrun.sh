#!/usr/bin/env bash
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-300)" | tee -a "$OUT/screens.txt"; }
for size in "1080x2400 420" "720x1560 320" "1080x1920 420"; do
  set -- $size
  adb shell wm size $1; adb shell wm density $2
  for mode in no yes; do
    adb shell cmd uimode night $mode
    adb shell pm clear $PKG >/dev/null
    adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 2; snap "splash-$1-night$mode"
    sleep 8; snap "next-$1-night$mode"
  done
done
adb shell wm size 1080x2400; adb shell wm density 420; adb shell cmd uimode night no
adb shell settings put system font_scale 1.3
adb shell pm clear $PKG >/dev/null
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10; snap bigfont-first
adb shell settings put system font_scale 1.0
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
