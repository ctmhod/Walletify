#!/usr/bin/env bash
# README screenshots with plain demo data. No music, no personal data.
# One screenshot per screen. Status bar is cropped later, before committing.
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
snap onboarding-agree
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
add_expense() { adb shell input tap 540 1767; sleep 2; T "ADD EXPENSE" 3; for d in $1; do T $d 1; done; T Enter 3; T "$2" 3; T Add 3; }
add_expense "4 5" "Groceries"
add_expense "1 2 0" "Bills & Fees"
add_expense "3 0" "Transport"
for k in 1 2 3; do python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 2; done
snap home
adb shell input swipe 300 1700 300 900 400; sleep 2; snap home-more
adb shell input swipe 300 900 300 1700 400; sleep 1
adb shell input tap 540 1767; sleep 2; snap add-sheet
T "ADD EXPENSE" 3; T 5; T 0; snap add-expense-keypad
adb shell input keyevent 4; sleep 1; adb shell input keyevent 4; sleep 1
# More menu pages. go_menu lands on the Quick access menu from any state.
go_menu() {
  for i in $(seq 1 8); do
    X=$(python3 $U texts)
    case "$X" in
      *"Quick access"*) return 0;;
      *"Hi Demo"*)
        python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 1
        adb shell input tap 975 179; sleep 3; return 0;;
    esac
    adb shell input keyevent 4; sleep 2
  done
  adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 7
  python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 1
  adb shell input tap 975 179; sleep 3
}
adb shell am force-stop $PKG
go_menu; snap menu
go_menu; T Categories 3; snap categories
go_menu; T "Planned Payments" 3; snap planned-payments
go_menu; T Budgets 3; snap budgets
go_menu; T Reports 3; sleep 3; snap reports
go_menu; T Settings 3; snap settings
for k in $(seq 1 14); do
  X=$(python3 $U texts)
  case "$X" in *"Check for updates"*) break;; esac
  adb shell input swipe 540 1700 540 900 350; sleep 1
done
snap settings-more
T "Check for updates" 2
for i in $(seq 1 10); do
  X=$(python3 $U texts)
  case "$X" in *"You are on the latest version"*|*"Update available"*) break;; esac
  sleep 4
done
snap check-updates
python3 $U tap-text Close >/dev/null 2>&1; sleep 1
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
true
