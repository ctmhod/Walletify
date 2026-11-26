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
python3 $U tap-class CheckBox; sleep 1
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
# crawl: tap every clickable on a screen, snapshot, back
crawl() {
  name="$1"; max="$2"
  python3 $U centers > /tmp/centers.txt
  i=0
  while read -u 3 x y label && [ $i -lt $max ]; do
    i=$((i+1))
    adb shell input tap $x $y; sleep 3
    snap "$name-$i-$label"; alive "$name-$i-$label"
    back
    # if app left the foreground, relaunch
    adb shell dumpsys window | grep -q "mCurrentFocus.*$PKG" || { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 4; }
  done 3< /tmp/centers.txt
}
opendrawer() { python3 $U centers > /tmp/c0.txt; l=$(sed -n 7p /tmp/c0.txt); set -- $l; adb shell input tap $1 $2; sleep 3; }
for sec in Settings Categories Reports Budgets Loans "Planned Payments"; do
  opendrawer
  python3 $U tap-text "$sec"; sleep 3
  snap "sec-$sec"; alive "$sec"
  crawl "sec-$sec" 14
  for b in 1 2 3; do back; done
  adb shell dumpsys window | grep -q "mCurrentFocus.*$PKG" || { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 4; }
done
adb logcat -d > "$OUT/logcat.txt"
grep -E "FATAL EXCEPTION" -A14 "$OUT/logcat.txt" | head -60 | tee "$OUT/crash.txt"
true
