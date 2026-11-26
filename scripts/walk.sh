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
# onboarding
python3 $U tap-class CheckBox; sleep 1
adb shell input tap 540 2160; sleep 5
python3 $U tap-text "Offline account"; sleep 5
python3 $U tap-text "Start fresh"; sleep 3
python3 $U tap-text "Set"; sleep 3
python3 $U tap-text "Skip"; sleep 3
python3 $U tap-text "Skip"; sleep 4
snap home
# crawl: tap every clickable on a screen, snapshot, back
crawl() {
  name="$1"; max="$2"
  python3 $U centers > /tmp/centers.txt
  i=0
  while read x y label && [ $i -lt $max ]; do
    i=$((i+1))
    adb shell input tap $x $y; sleep 3
    snap "$name-$i-$label"; alive "$name-$i-$label"
    back
    # if app left the foreground, relaunch
    adb shell dumpsys window | grep -q "mCurrentFocus.*$PKG" || { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 4; }
  done < /tmp/centers.txt
}
crawl home 8
adb shell input tap 840 1840; sleep 3; snap accounts
crawl accounts 8
adb logcat -d > "$OUT/logcat.txt"
grep -E "FATAL EXCEPTION" -A14 "$OUT/logcat.txt" | head -60 | tee "$OUT/crash.txt"
true
