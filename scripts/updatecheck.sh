#!/usr/bin/env bash
# Update-flow QA: install the new APK, verify "You are on the latest version",
# then pose as an older version and run the whole download + system-install loop.
# Usage: updatecheck.sh APK OUTDIR
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
EXPECT_TAG="$3"; EXPECT_V="${EXPECT_TAG#v}"
R="$OUT/report.txt"; : > "$R"
log(){ echo "$*" | tee -a "$R"; }
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
grep -q Success "$OUT/install.txt" || { log "INSTALL FAILED"; exit 1; }
adb shell wm size 1080x2400; adb shell wm density 420

n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1]" >> "$OUT/screens.txt"; }
texts() { python3 $U texts; }

launch() { # $1 = extra args
  adb shell am force-stop $PKG; sleep 1
  # applicationId is com.ctmhod.walletify but the activity class lives in the
  # com.ivy.wallet namespace, so the component must name the class in full.
  adb shell am start -n $PKG/com.ivy.wallet.RootActivity $1; sleep 12
}

to_settings() { # from a fresh launch: finish onboarding if needed, open Settings
  sleep 4
  python3 $U tap-first CheckBox >/dev/null 2>&1; sleep 1
  for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
  python3 $U tap-bottom >/dev/null 2>&1; sleep 5
  for k in $(seq 1 16); do
    T=$(texts)
    echo "[onboard $k] $(echo "$T" | cut -c1-250)" >> "$OUT/screens.txt"
    case "$T" in *"Adjust your initial balance"*|*"No transactions"*|*"Hi "*) break;; esac
    case "$T" in
      *"Offline account"*) python3 $U tap-text "Offline account"; sleep 4;;
      *"your name"*|*"What is your name"*) adb shell input text Demo; sleep 1; python3 $U tap-text Next; sleep 3;;
      *"Import backup file"*) python3 $U tap-text "Start fresh" || adb shell input tap 540 2235; sleep 3;;
      *"Start fresh"*) python3 $U tap-text "Start fresh"; sleep 3;;
      *"currency"*) python3 $U tap-text "Set" || python3 $U tap-bottom; sleep 3;;
      *"Add accounts"*|*"Add categories"*) python3 $U tap-text "Skip"; sleep 3;;
      *) sleep 3;;
    esac
  done
  python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 2
  # top-right more menu, then Settings
  python3 $U centers > /tmp/c0.txt
  set -- $(awk '$1>900 && $2<300 {print $1, $2; exit}' /tmp/c0.txt)
  [ $# -ge 2 ] && adb shell input tap $1 $2; sleep 3
  python3 $U tap-text "Settings"; sleep 3
  # scroll until "Check for updates" is visible
  for k in $(seq 1 14); do
    T=$(texts)
    case "$T" in *"Check for updates"*) return 0;; esac
    adb shell input swipe 540 1700 540 900 350; sleep 1
  done
  return 1
}

wait_for() { # $1 = wanted substring, $2 = tries (5s each)
  for i in $(seq 1 $2); do
    T=$(texts)
    case "$T" in *"$1"*) return 0;; esac
    sleep 5
  done
  return 1
}

log "== A latest build says on latest version"
launch ""
to_settings || log "FAIL could not reach Check for updates row"
snap settings-update-row
python3 $U tap-text "Check for updates" && log "tapped Check for updates" || log "FAIL row not found"
wait_for "You are on the latest version" 8 && log "PASS latest build says on latest version" || log "FAIL no latest-version message"
snap update-latest
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 1

log "== B update flow from a posed old version"
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL could not reach Check for updates row (2nd)"
python3 $U tap-text "Check for updates" || log "FAIL row not found (2nd)"
wait_for "Update available: $EXPECT_TAG" 8 && log "PASS update $EXPECT_TAG offered" || log "FAIL update not offered"
snap update-available
python3 $U tap-text "Download" || log "FAIL no Download button"
wait_for "Ready to install" 60 && log "PASS APK downloaded in app" || log "FAIL download did not finish"
snap update-downloaded
python3 $U tap-text "Install" || log "FAIL no Install button"
sleep 5
T=$(texts)
case "$T" in
  *"Allow from this source"*)
    snap update-permission
    python3 $U tap-text "Allow from this source"; sleep 2
    adb shell input keyevent 4; sleep 2
    python3 $U tap-text "Install"; sleep 5;;
esac
snap update-installer
T=$(texts)
case "$T" in
  *Update*) python3 $U tap-text "Update";;
  *Install*) python3 $U tap-text "Install";;
esac
wait_for "App updated" 30 && log "PASS system installer: App updated" || {
  wait_for "App installed" 5 && log "PASS system installer: App installed" || log "FAIL system install did not complete"; }
snap update-done
python3 $U tap-text "Done" >/dev/null 2>&1; sleep 2

log "== C version after self-update"
launch ""
to_settings >/dev/null 2>&1 || true
T=$(texts)
case "$T" in *"$EXPECT_V"*) log "PASS settings shows $EXPECT_V after self-update";; *) log "FAIL version not $EXPECT_V after self-update";; esac
snap update-version-after

adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
grep -q "FATAL EXCEPTION" "$OUT/crash.txt" && log "FAIL crash detected" || log "PASS no fatal exception"
log "DONE"
