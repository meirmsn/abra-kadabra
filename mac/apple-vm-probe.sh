#!/bin/bash
# The probe apple-vm-attacks.sh sends into a VM with `tart exec` (spec specs/apple-vm-host-script.md).
# It runs inside the guest, under macOS's /bin/bash 3.2, and prints exactly one line:
#   PROBE <id> reached|blocked|value|error <detail>
# "reached" means the attack got through, "blocked" that the wall held. The Mac decides PASS or FAIL.
# Usage: apple-vm-probe.sh <probe> [args...]
#   gateway | host-path | connect <id> <ip>:<port>... | clipboard <word> |
#   persist-write <word> | persist-check <word> | cpu-mem-info | load <seconds> | disk-free | disk-fill
# PROBE_ROOT prefixes the guest paths it reads and writes (tests only; empty in a VM).
set -u -o pipefail

root=${PROBE_ROOT:-}
probe=${1:-}
[ $# -gt 0 ] && shift
out() { echo "PROBE $probe $1 ${2:-}"; exit 0; }

case $probe in
  gateway)
    gw=$(route -n get default 2>/dev/null | awk '/gateway:/ { print $2; exit }')
    [ -n "$gw" ] || out error "no default route"
    out value "$gw" ;;

  host-path)
    mounts=$(mount 2>/dev/null) || out error "mount failed"
    shared=$(printf '%s\n' "$mounts" | grep -E '\((virtiofs|smbfs|nfs|afpfs)[,)]' | tr '\n' ';')
    vols=""
    for v in "$root"/Volumes/*; do
      [ -e "$v" ] || continue
      # The guest's own disk shows as a link to /.
      [ -L "$v" ] && [ "$(readlink "$v")" = / ] && continue
      vols="$vols${v##*/};"
    done
    [ -z "$shared$vols" ] || out reached "mounts: ${shared:-none} volumes: ${vols:-none}"
    out blocked "no shared mount, nothing under /Volumes but the guest's disk" ;;

  connect)
    [ $# -ge 1 ] || out error "connect needs <ip>:<port>"
    reached="" tried=""
    for target in "$@"; do
      ip=${target%:*} port=${target##*:}
      tried="$tried $target"
      if nc -z -G 3 -w 3 "$ip" "$port" >/dev/null 2>&1; then reached="$reached $target"; fi
    done
    [ -z "$reached" ] || out reached "connected to$reached"
    out blocked "no connection to$tried" ;;

  clipboard)
    word=${1:-}
    [ -n "$word" ] || out error "clipboard needs <word>"
    for _ in 1 2 3 4 5; do
      got=$(pbpaste 2>/dev/null) || out error "pbpaste failed"
      [ "$got" != "$word" ] || out reached "the Mac's word is on the guest's clipboard"
      sleep 1
    done
    out blocked "the Mac's word never reached the guest's clipboard" ;;

  persist-write)
    word=${1:-}
    [ -n "$word" ] || out error "persist-write needs <word>"
    printf '%s\n' "$word" >"$root/Users/admin/.apple-vm-marker" || out error "can't write in /Users/admin"
    printf '%s\n' "$word" >"$root/Users/Shared/.apple-vm-marker" || out error "can't write in /Users/Shared"
    plist="<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>Label</key><string>com.example.apple-vm-marker</string><key>Program</key><string>/usr/bin/true</string><key>Comment</key><string>$word</string></dict></plist>"
    if [ -n "$root" ]; then
      printf '%s\n' "$plist" >"$root/Library/LaunchDaemons/com.example.apple-vm-marker.plist" || out error "can't write the LaunchDaemon"
    else
      printf '%s\n' "$plist" | sudo -n tee /Library/LaunchDaemons/com.example.apple-vm-marker.plist >/dev/null ||
        out error "can't write the LaunchDaemon"
    fi
    out value "markers written" ;;

  persist-check)
    word=${1:-}
    [ -n "$word" ] || out error "persist-check needs <word>"
    found=""
    for f in "$root/Users/admin/.apple-vm-marker" "$root/Users/Shared/.apple-vm-marker" \
      "$root/Library/LaunchDaemons/com.example.apple-vm-marker.plist"; do
      [ -f "$f" ] && grep -q -- "$word" "$f" && found="$found ${f#"$root"}"
    done
    [ -z "$found" ] || out reached "markers found:$found"
    out blocked "no marker from the earlier VM" ;;

  cpu-mem-info)
    cpus=$(sysctl -n hw.ncpu 2>/dev/null) || out error "sysctl failed"
    mem=$(sysctl -n hw.memsize 2>/dev/null) || out error "sysctl failed"
    out value "$cpus $mem" ;;

  load)
    secs=${1:-30}
    pids=""
    for _ in 1 2 3 4 5 6 7 8; do
      yes >/dev/null &
      pids="$pids $!"
    done
    # 10 GB in a guest of 8 GB: the guest swaps, the Mac must not grow past the VM's memory.
    perl -e '$x = "x" x (10 * 1024 ** 3); sleep '"$secs" >/dev/null 2>&1 &
    pids="$pids $!"
    sleep "$secs"
    # shellcheck disable=SC2086 # word splitting of the pid list is intended
    kill $pids 2>/dev/null
    out value "loaded 8 busy loops and 10 GB for $secs s" ;;

  disk-free)
    before=$(df -Pk / | awk 'NR == 2 { print $4 }')
    case $before in '' | *[!0-9]*) out error "can't read the guest's free space" ;; esac
    # Delete files the image holds, so the clone rewrites shared blocks, not only empty ones.
    for d in /Applications/Xcode*.app /Library/Developer/CoreSimulator/Images /Library/Developer/CoreSimulator/Volumes; do
      [ -e "$d" ] && sudo -n rm -rf "$d"
      now=$(df -Pk / | awk 'NR == 2 { print $4 }')
      [ $((now - before)) -lt $((20 * 1048576)) ] || break
    done
    freed=$(( ($(df -Pk / | awk 'NR == 2 { print $4 }') - before) / 1048576 ))
    [ "$freed" -ge 20 ] || out error "freed only $freed GB"
    out value "freed $freed GB" ;;

  disk-fill)
    # Writes until the disk is full or the VM is stopped under it; no line when stopped.
    dd if=/dev/urandom of=/Users/admin/fill bs=1m >/dev/null 2>&1
    out value "wrote until the disk was full" ;;

  *) echo "PROBE ${probe:-none} error unknown probe"; exit 0 ;;
esac
