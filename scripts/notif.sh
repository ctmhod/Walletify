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
sleep 5
python3 $U tap-class CheckBox; sleep 1
for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
python3 $U tap-bottom; sleep 5
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
python3 $U tap-text prompt_dismiss; sleep 2
python3 $U centers > /tmp/c0.txt; set -- $(sed -n 7p /tmp/c0.txt); adb shell input tap $1 $2; sleep 3
python3 $U tap-text "Settings"; sleep 3
adb shell input swipe 540 1700 540 700 400; sleep 1
snap settings-default-off
adb shell input swipe 540 700 540 1500 400; sleep 1; snap export-csv-row
adb shell input swipe 540 1500 540 700 400; sleep 1
python3 $U tap-text "Show notifications"; sleep 3
snap after-toggle-permission-dialog
python3 $U tap-text "Allow"; sleep 3
snap after-allow-on
adb shell pm list permissions -g >/dev/null 2>&1
adb shell dumpsys package $PKG | grep -i "POST_NOTIFICATIONS" | tee -a "$OUT/screens.txt"
adb shell dumpsys jobscheduler | grep -i "$PKG" | head -20 | tee "$OUT/jobs.txt"
JID=$(adb shell dumpsys jobscheduler | grep -o "JOB #u0a[0-9]*/[0-9]*: .*$PKG" | head -1 | sed 's/.*\/\([0-9]*\):.*/\1/')
echo "jobid=$JID" | tee -a "$OUT/screens.txt"
adb shell cmd jobscheduler run -f $PKG ${JID:-0}; sleep 8
adb shell input keyevent 3; sleep 1
adb shell cmd statusbar expand-notifications; sleep 2
snap notification-shade
adb shell dumpsys notification --noredact | grep -i -A3 "pkg=$PKG" | head -20 | tee -a "$OUT/screens.txt"
# denied path: reinstall fresh perms
adb shell pm revoke $PKG android.permission.POST_NOTIFICATIONS
adb shell am force-stop $PKG; adb logcat -d > "$OUT/logcat.txt"
adb logcat -d | grep -E "FATAL|AndroidRuntime" | head > "$OUT/crash.txt"; true
