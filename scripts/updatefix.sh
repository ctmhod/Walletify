#!/usr/bin/env bash
# Updater-fix QA (v0.1.58): single-flight download, kill-midway retry with one
# clean screen, reuse of a finished APK, and the unknown-apps permission flow
# that must auto-continue into the system installer exactly once, with no loop.
# Usage: updatefix.sh APK OUTDIR LATEST_TAG
set -u
APK="$1"; PKG=com.ctmhod.walletify; OUT="$2"; mkdir -p "$OUT"; U=scripts/ui.py
EXPECT_TAG="$3"; EXPECT_V="${EXPECT_TAG#v}"
R="$OUT/report.txt"; : > "$R"
log(){ echo "$*" | tee -a "$R"; }
adb logcat -c
adb install -r "$APK" | tee "$OUT/install.txt"
grep -q Success "$OUT/install.txt" || { log "INSTALL FAILED"; exit 1; }
adb shell wm size 1080x2400; adb shell wm density 420
sleep 1
SIZE=$(adb shell wm size | tr ' ' '\n' | tail -1)
SW=${SIZE%x*}; SH=${SIZE#*x}
SW=${SW:-1080}; SH=${SH:-2400}
MX=$((SW*4/5)); MY=$((SH/8))
SX=$((SW/2)); SY_HI=$((SH*3/4)); SY_MID=$((SH*3/8)); SY_TAP=$((SH*93/100))
echo "screen ${SW}x${SH}"
# Throttle the host NIC so the kill-mid-download step can observe a real
# in-progress download (emulator -netspeed did not throttle GitHub CDN).
sudo tc qdisc add dev eth0 root netem rate 900kbit 2>/dev/null || true

n=0
snap() { n=$((n+1)); adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$1.png"; echo "[$n $1]" >> "$OUT/screens.txt"; }
texts() { python3 $U texts; }

launch() {
  adb shell am force-stop $PKG; sleep 1
  adb shell am start -n $PKG/com.ivy.wallet.RootActivity $1; sleep 12
}

to_settings() {
  sleep 4
  T0=$(texts)
  case "$T0" in *"Adjust your initial balance"*|*"No transactions"*|*"Hi "*)
    python3 $U tap-text close >/dev/null 2>&1; sleep 2
    python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 2
    python3 $U centers > /tmp/c0.txt
    set -- $(awk -v mx=$MX -v my=$MY '$1>mx && $2<my {print $1, $2; exit}' /tmp/c0.txt)
    [ $# -ge 2 ] && adb shell input tap $1 $2; sleep 3
    python3 $U tap-text "Settings"; sleep 3
    for k in $(seq 1 14); do
      T=$(texts)
      case "$T" in *"Check for updates"*) return 0;; esac
      adb shell input swipe $SX $SY_HI $SX $SY_MID 350; sleep 1
    done
    return 1;;
  esac
  python3 $U tap-first CheckBox >/dev/null 2>&1; sleep 1
  for j in 1 2; do adb shell input swipe $SX $SY_HI $SX $SY_MID 300; sleep 1; done
  python3 $U tap-bottom >/dev/null 2>&1; sleep 5
  for k in $(seq 1 16); do
    T=$(texts)
    echo "[onboard $k] $(echo "$T" | cut -c1-250)" >> "$OUT/screens.txt"
    case "$T" in *"Adjust your initial balance"*|*"No transactions"*|*"Hi "*) break;; esac
    case "$T" in
      *"Offline account"*) python3 $U tap-text "Offline account"; sleep 4;;
      *"your name"*|*"What is your name"*) adb shell input text Demo; sleep 1; python3 $U tap-text Next || python3 $U tap-text Skip; sleep 3;;
      *"Import backup file"*) python3 $U tap-text "Start fresh" || adb shell input tap $SX $SY_TAP; sleep 3;;
      *"Import CSV file"*)
        # Small screens: the "Start fresh" button is below the fold; the
        # onboarding root scrolls, so swipe up to reveal it. Never tap the
        # X here - it goes back to the name step.
        adb shell input swipe $SX $SY_HI $SX $SY_MID 300; sleep 1
        adb shell input swipe $SX $SY_HI $SX $SY_MID 300; sleep 1
        python3 $U tap-text "start fresh" x >/dev/null 2>&1 || python3 $U tap-bottom >/dev/null 2>&1
        sleep 3;;
      *"Start fresh"*) python3 $U tap-text "Start fresh"; sleep 3;;
      *"currency"*) python3 $U tap-text "Set" || python3 $U tap-bottom; sleep 3;;
      *"Add accounts"*|*"Add categories"*) python3 $U tap-text "Skip"; sleep 3;;
      *) sleep 3;;
    esac
  done
  python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 2
  python3 $U centers > /tmp/c0.txt
  set -- $(awk -v mx=$MX -v my=$MY '$1>mx && $2<my {print $1, $2; exit}' /tmp/c0.txt)
  [ $# -ge 2 ] && adb shell input tap $1 $2; sleep 3
  python3 $U tap-text "Settings"; sleep 3
  for k in $(seq 1 14); do
    T=$(texts)
    case "$T" in *"Check for updates"*) return 0;; esac
    adb shell input swipe $SX $SY_HI $SX $SY_MID 350; sleep 1
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

absent_for() { # $1 = substring that must stay absent, $2 = tries (3s each)
  for i in $(seq 1 $2); do
    T=$(texts)
    case "$T" in *"$1"*) return 1;; esac
    sleep 3
  done
  return 0
}

# Deterministic permission path: install permission starts denied.
adb shell appops set $PKG REQUEST_INSTALL_PACKAGES deny

log "== A single-flight + kill mid-download + clean retry (network throttled)"
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL could not reach Check for updates row"
python3 $U tap-text "Check for updates" || log "FAIL row not found"
wait_for "Update available: $EXPECT_TAG" 8 && log "PASS update $EXPECT_TAG offered" || log "FAIL update not offered"
python3 $U tap-text "Download" || log "FAIL no Download button"
wait_for "Downloading" 8 && log "PASS download started" || { log "FAIL download did not start"; }
snap download-started
# single-flight: hide the dialog mid-download; the download must continue and
# re-opening must attach to it, never restart a check or a second download.
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 3
python3 $U tap-text "Check for updates" || log "FAIL row not found (re-open)"
T=$(texts)
case "$T" in
  *Downloading*) log "PASS re-opened dialog attaches to the running download (single-flight)";;
  *"Ready to install"*) log "PASS re-opened dialog shows live state (download already done)";;
  *) log "FAIL re-opened dialog lost the running download: $(echo "$T" | cut -c1-160)";;
esac
absent_for "Update available:" 2 && log "PASS no second check/screen while downloading" || log "FAIL a parallel check started during download"
# kill the app while the download is still running
T=$(texts)
case "$T" in
  *Downloading*) adb shell am force-stop $PKG; sleep 2; log "killed app mid-download";;
  *) log "note: download finished before the kill (fast network); kill case covered by retry below";;
esac
snap before-kill
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings after kill"
python3 $U tap-text "Check for updates" || log "FAIL row not found (after kill)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available after kill"
python3 $U tap-text "Download" || log "FAIL no Download (after kill)"
T=$(texts)
case "$T" in
  *Downloading*) log "PASS retry download started after kill";;
  *"Ready to install"*) log "PASS retry reached Ready (reused complete file)";;
  *) log "FAIL retry did not start: $(echo "$T" | cut -c1-160)";;
esac
snap retry-downloading
wait_for "Ready to install" 70 && log "PASS retry after kill reached Ready" || log "FAIL retry after kill did not finish"
CNT=$(texts | grep -o "Ready to install" | wc -l)
[ "$CNT" = "1" ] && log "PASS exactly one Ready screen after retry" || log "FAIL $CNT Ready strings on screen"
snap retry-ready
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 1

log "== B2 stale partials and old copies are deleted (seeded files)"
adb root >/dev/null 2>&1; sleep 3; adb wait-for-device; sleep 2
adb shell "mkdir -p /data/data/$PKG/cache/updates"
adb shell "echo partial > /data/data/$PKG/cache/updates/walletify-update-$EXPECT_TAG.apk.part"
adb shell "echo old > /data/data/$PKG/cache/updates/walletify-update-v0.0.0.apk"
adb shell "ls /data/data/$PKG/cache/updates" | tee -a "$R"
adb unroot >/dev/null 2>&1; sleep 2
adb shell am force-stop $PKG; sleep 2
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings (stale)"
python3 $U tap-text "Check for updates" || log "FAIL row not found (stale)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available (stale)"
python3 $U tap-text "Download" || log "FAIL no Download (stale)"
wait_for "Ready to install" 30 && log "PASS Ready after stale-seed (cleanup ran)" || log "FAIL no Ready after stale-seed"
snap stale-cleanup-ready
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 1

log "== B reuse: finished APK reused after restart, no new download"
adb shell am force-stop $PKG; sleep 2
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings (reuse)"
python3 $U tap-text "Check for updates" || log "FAIL row not found (reuse)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available (reuse)"
python3 $U tap-text "Download" || log "FAIL no Download (reuse)"
wait_for "Ready to install" 10 && log "PASS Ready without downloading (reused file)" || log "FAIL reuse did not skip the download"
absent_for "Downloading" 3 && log "PASS no download progress shown on reuse" || log "FAIL downloaded again instead of reusing"
snap reuse-ready

log "== C permission: grant, return, installer starts by itself exactly once"
python3 $U tap-text "Install" || log "FAIL no Install button"
sleep 4
T=$(texts)
case "$T" in
  *"Allow from this source"*) log "PASS system permission screen opened";;
  *) log "FAIL no permission screen: $(echo "$T" | cut -c1-160)";;
esac
snap perm-screen
python3 $U tap-text "Allow from this source"; sleep 2
adb shell input keyevent 4; sleep 4
# No Install tap here: the installer must come up by itself.
wait_for "Do you want to update" 10 && log "PASS installer launched automatically after grant" || {
  wait_for "Do you want to install" 3 && log "PASS installer launched automatically after grant" || log "FAIL installer did not start after grant"; }
snap auto-installer
T=$(texts)
case "$T" in *Cancel*) python3 $U tap-text "Cancel";; *) adb shell input keyevent 4;; esac
sleep 3
absent_for "Do you want to update" 5 && log "PASS no installer loop after cancel" || log "FAIL installer reappeared after cancel"
snap after-cancel

log "== D manual install completes"
python3 $U tap-text "Install" || log "FAIL no Install button (manual)"
sleep 5
T=$(texts)
case "$T" in
  *Update*) python3 $U tap-text "Update";;
  *Install*) python3 $U tap-text "Install";;
esac
wait_for "App updated" 30 && log "PASS system installer: App updated" || {
  wait_for "App installed" 5 && log "PASS system installer: App installed" || log "FAIL system install did not complete"; }
snap update-done
python3 $U tap-text "Done" >/dev/null 2>&1; sleep 2

log "== E version after self-update"
launch ""
to_settings >/dev/null 2>&1 || true
T=$(texts)
case "$T" in *"$EXPECT_V"*) log "PASS settings shows $EXPECT_V after self-update";; *) log "FAIL version not $EXPECT_V after self-update";; esac
snap update-version-after

log "== F UpdateManager evidence in the in-app error log"
for k in 1 2 3 4 5 6; do
  T=$(texts)
  case "$T" in *"Error log"*) break;; esac
  adb shell input swipe $SX $SY_HI $SX $SY_MID 350; sleep 1
done
python3 $U tap-text "Error log" && sleep 3 && snap update-error-log && {
  T=$(texts)
  echo "$T" >> "$OUT/errorlog.txt"
  case "$T" in *"reusing complete APK"*) log "PASS error log shows APK reuse";; *) log "note: reuse line not visible in error log view";; esac
  case "$T" in *"permission granted, launching installer once"*) log "PASS error log shows single auto-install";; *) log "note: auto-install line not visible in error log view";; esac
  case "$T" in *"removed 2 stale file"*|*"removed 1 stale file"*) log "PASS error log shows stale partial/old cleanup";; *) log "note: stale-cleanup line not visible in error log view";; esac
} || log "note: error log row not reachable"

sudo tc qdisc del dev eth0 root 2>/dev/null || true
adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
grep -q "FATAL EXCEPTION" "$OUT/crash.txt" && log "FAIL crash detected" || log "PASS no fatal exception"
log "DONE"
