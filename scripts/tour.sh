#!/usr/bin/env bash
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
adb shell wm size 1080x2400; adb shell wm density 420
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10
n=0
snap0() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-700)" | tee -a "$OUT/screens.txt"; }
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

snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-400)" | tee -a "$OUT/screens.txt"; }
# shot NAME: capture, then scroll and capture the rest (max 4 extra)
shot() {
  snap "$1"; prev=$(python3 $U texts | md5sum)
  for k in 2 3 4 5; do
    adb shell input swipe 540 1700 540 600 400; sleep 1.5
    cur=$(python3 $U texts | md5sum); [ "$cur" = "$prev" ] && break
    snap "$1-part$k"; prev=$cur
  done
  for k in 1 2 3 4 5; do adb shell input swipe 540 500 540 1800 300; done; sleep 1
}
opendrawer() { python3 $U centers > /tmp/c0.txt; l=$(awk '$1>900 && $2<300 {print; exit}' /tmp/c0.txt); set -- $l; adb shell input tap $1 $2; sleep 3; }
python3 $U tap-text prompt_dismiss; sleep 2
shot home
python3 $U tap-xy 540 1767; sleep 3
shot add-transaction-menu
back
python3 $U tap-xy 846 1840; sleep 3
shot accounts-tab
python3 $U tap-xy 233 1840; sleep 2
opendrawer; shot quick-access-menu
for sec in "Categories" "Planned Payments" "Savings goal" "Reports" "Budgets" "Loans"; do
  python3 $U tap-text "$sec"; sleep 3
  shot "$sec"
  back; alive "$sec"
  adb shell dumpsys window | grep -q "mCurrentFocus.*$PKG" || { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 4; }
  python3 $U texts | grep -q "Quick access" || opendrawer
done
python3 $U tap-xy 975 130 ; sleep 3   # gear
shot settings
python3 $U tap-text "Import data"; sleep 3
shot import-picker
back; sleep 1
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
