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
    set -- $(awk '$1>900 && $2<300 {print $1, $2; exit}' /tmp/c0.txt)
    [ $# -ge 2 ] && adb shell input tap $1 $2; sleep 3
    python3 $U tap-text "Settings"; sleep 3
    for k in $(seq 1 14); do
      T=$(texts)
      case "$T" in *"Check for updates"*) return 0;; esac
      adb shell input swipe 540 1700 540 900 350; sleep 1
    done
    return 1;;
  esac
  python3 $U tap-first CheckBox >/dev/null 2>&1; sleep 1
  for j in 1 2; do adb shell input swipe 540 1800 540 600 300; sleep 1; done
  python3 $U tap-bottom >/dev/null 2>&1; sleep 5
  for k in $(seq 1 16); do
    T=$(texts)
    echo "[onboard $k] $(echo "$T" | cut -c1-250)" >> "$OUT/screens.txt"
    case "$T" in *"Adjust your initial balance"*|*"No transactions"*|*"Hi "*) break;; esac
    case "$T" in
      *"Offline account"*) python3 $U tap-text "Offline account"; sleep 4;;
      *"your name"*|*"What is your name"*) adb shell input text Demo; sleep 1; python3 $U tap-text Next || python3 $U tap-text Skip; sleep 3;;
      *"Import backup file"*) python3 $U tap-text "Start fresh" || adb shell input tap 540 2235; sleep 3;;
      *"Start fresh"*) python3 $U tap-text "Start fresh"; sleep 3;;
      *"currency"*) python3 $U tap-text "Set" || python3 $U tap-bottom; sleep 3;;
      *"Add accounts"*|*"Add categories"*) python3 $U tap-text "Skip"; sleep 3;;
      *) sleep 3;;
    esac
  done
  python3 $U tap-text prompt_dismiss >/dev/null 2>&1; sleep 2
  python3 $U centers > /tmp/c0.txt
  set -- $(awk '$1>900 && $2<300 {print $1, $2; exit}' /tmp/c0.txt)
  [ $# -ge 2 ] && adb shell input tap $1 $2; sleep 3
  python3 $U tap-text "Settings"; sleep 3
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

log "== A single-flight: re-opening during a download attaches to it"
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL could not reach Check for updates row"
python3 $U tap-text "Check for updates" || log "FAIL row not found"
wait_for "Update available: $EXPECT_TAG" 8 && log "PASS update $EXPECT_TAG offered" || log "FAIL update not offered"
python3 $U tap-text "Download" || log "FAIL no Download button"
wait_for "Downloading" 6 && log "PASS download started" || log "FAIL download did not start"
snap download-started
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 2   # hide dialog; download must continue
python3 $U tap-text "Check for updates" || log "FAIL row not found (re-open)"
T=$(texts)
case "$T" in
  *Downloading*) log "PASS re-opened dialog shows the running download (single-flight)";;
  *) log "FAIL re-opened dialog does not show the running download: $(echo "$T" | cut -c1-160)";;
esac
absent_for "Update available:" 2 && log "PASS no second check/screen while downloading" || log "FAIL a parallel check started during download"
wait_for "Ready to install" 70 && log "PASS download finished" || log "FAIL download did not finish"
snap singleflight-ready
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 1

log "== B kill mid-download, retry: one flow, one screen, clean files"
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings after kill"
python3 $U tap-text "Check for updates" || log "FAIL row not found (2nd)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available after kill"
python3 $U tap-text "Download" || log "FAIL no Download (2nd)"
wait_for "Downloading" 6
sleep 6   # let it get partway, then kill the app mid-download
adb shell am force-stop $PKG; sleep 2
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings after kill (2nd)"
python3 $U tap-text "Check for updates" || log "FAIL row not found (3rd)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available after kill (2nd)"
python3 $U tap-text "Download" || log "FAIL no Download (3rd)"
wait_for "Ready to install" 70 && log "PASS retry after kill reached Ready" || log "FAIL retry after kill did not finish"
CNT=$(texts | grep -o "Ready to install" | wc -l)
[ "$CNT" = "1" ] && log "PASS exactly one Ready screen after retry" || log "FAIL $CNT Ready strings on screen"
snap retry-ready
python3 $U tap-text "Close" >/dev/null 2>&1; sleep 1

log "== C reuse: finished APK reused after restart, no new download"
adb shell am force-stop $PKG; sleep 2
launch "-e walletify_fake_version 0.1.51"
to_settings || log "FAIL settings (reuse)"
python3 $U tap-text "Check for updates" || log "FAIL row not found (reuse)"
wait_for "Update available: $EXPECT_TAG" 8 || log "note: no Available (reuse)"
python3 $U tap-text "Download" || log "FAIL no Download (reuse)"
wait_for "Ready to install" 10 && log "PASS Ready without downloading (reused file)" || log "FAIL reuse did not skip the download"
absent_for "Downloading" 3 && log "PASS no download progress shown on reuse" || log "FAIL downloaded again instead of reusing"
snap reuse-ready

log "== D permission: grant, return, installer starts by itself exactly once"
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

log "== E manual install completes"
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

log "== F version after self-update"
launch ""
to_settings >/dev/null 2>&1 || true
T=$(texts)
case "$T" in *"$EXPECT_V"*) log "PASS settings shows $EXPECT_V after self-update";; *) log "FAIL version not $EXPECT_V after self-update";; esac
snap update-version-after

log "== G UpdateManager evidence in the in-app error log"
python3 $U tap-text "Error log" && sleep 3 && snap update-error-log && {
  T=$(texts)
  echo "$T" >> "$OUT/errorlog.txt"
  case "$T" in *"reusing complete APK"*) log "PASS error log shows APK reuse";; *) log "note: reuse line not visible in error log view";; esac
  case "$T" in *"permission granted, launching installer once"*) log "PASS error log shows single auto-install";; *) log "note: auto-install line not visible in error log view";; esac
} || log "note: error log row not reachable"

adb logcat -d | grep -E "FATAL EXCEPTION" -A10 | head -30 > "$OUT/crash.txt"
grep -q "FATAL EXCEPTION" "$OUT/crash.txt" && log "FAIL crash detected" || log "PASS no fatal exception"
log "DONE"
