#!/usr/bin/env bash
# README screenshots with plain demo data. No music, no personal data.
set -u
PKG=com.ctmhod.walletify; OUT=out; U=scripts/ui.py; mkdir -p "$OUT"
adb install -r app.apk >/dev/null
adb shell wm size 1080x2400; adb shell wm density 420
n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1] $(python3 $U texts | cut -c1-300)" | tee -a "$OUT/screens.txt"; }
T() { python3 $U tap-text "$1"; sleep ${2:-2}; }
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 10
python3 $U tap-first CheckBox; sleep 1
for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
python3 $U tap-bottom; sleep 5
for k in $(seq 1 12); do
  X=$(python3 $U texts)
  case "$X" in *"Adjust your initial balance"*|*"No transactions"*) break;; esac
  case "$X" in
    *"Offline account"*) python3 $U tap-text "Offline account"; sleep 4;;
    *"your name"*|*"What's your name"*) adb shell input text Demo; sleep 1; T Next 3;;
    *"Start fresh"*) python3 $U tap-text "Start fresh"; sleep 3;;
    *"Set currency"*) python3 $U tap-text "Set"; sleep 3;;
    *"Add accounts"*|*"Add categories"*) python3 $U tap-text "Skip"; sleep 3;;
    *) sleep 3;;
  esac
done
snap onboarding-end
python3 $U tap-text prompt_dismiss; sleep 2
snap home
add_expense() { adb shell input tap 540 1767; sleep 2; T "ADD EXPENSE" 3; for d in $1; do T $d 1; done; T Enter 3; T "$2" 3; T Add 3; }
add_expense "4 5" "Groceries"; snap after-first
add_expense "1 2 0" "Bills & Fees"
add_expense "3 0" "Transport"
python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 1
snap home-with-data
adb shell input tap 540 1767; sleep 2; snap fab
T "ADD EXPENSE" 3; T 5; T 0; snap keypad
adb shell input keyevent 4; sleep 1; adb shell input keyevent 4; sleep 1
adb shell am force-stop $PKG; adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 7
python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 1
adb shell input tap 975 179; sleep 3; snap menu
T Settings 3; snap settings
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
