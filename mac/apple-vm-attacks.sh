#!/bin/bash
# The VM lane's attack run, on the local Mac (spec specs/apple-vm-host-script.md). It starts its own
# task VMs through apple-vm.sh, sends apple-vm-probe.sh into them with `tart exec`, and writes a
# report: PASS when a wall held, FAIL when it didn't or a probe couldn't run. `known-bad` runs the
# same probes on a VM started the unsafe way, where every line must be FAIL: the proof the probes
# can see a broken wall. Written for macOS's /bin/bash 3.2 and BSD tools.
#
# Usage:
#   apple-vm-attacks.sh run --tart-dir <dir> --report <file> [--disk-fill]
#   apple-vm-attacks.sh known-bad --tart-dir <dir> --report <file>
# Exit 0 = every line as expected (all PASS for run, all FAIL for known-bad); 1 = not; 2 = usage.
set -eu -o pipefail

here=$(cd "$(dirname "$0")" && pwd)
vm="$here/apple-vm.sh"
probe_script="$here/apple-vm-probe.sh"
GB_KB=1048576
DELETE_FREE_GB=15
READY_TRIES=150   # 2 s apart: 300 s
DISK_TRIES=900    # 2 s apart: 30 min for the disk attack
LOAD_SECONDS=30
NC=/usr/bin/nc    # macOS's own; a test's fake when the Tart folder's bin/ holds one
A=task-90 B=task-91 KB=task-99

usage() {
  echo "usage: apple-vm-attacks.sh run --tart-dir <dir> --report <file> [--disk-fill] | known-bad --tart-dir <dir> --report <file>" >&2
  [ $# -eq 0 ] || echo "apple-vm-attacks: $*" >&2
  exit 2
}
refuse() { echo "apple-vm-attacks: $*" >&2; exit 1; }

mode=${1:-}
[ $# -gt 0 ] && shift
case $mode in run | known-bad) ;; *) usage "unknown command '${mode}'" ;; esac
dir="" report="" disk_fill=0
while [ $# -gt 0 ]; do
  case $1 in
    --tart-dir) [ $# -ge 2 ] || usage "--tart-dir needs a value"; dir=$2; shift 2 ;;
    --report) [ $# -ge 2 ] || usage "--report needs a value"; report=$2; shift 2 ;;
    --disk-fill) [ "$mode" = run ] || usage "--disk-fill is for run"; disk_fill=1; shift ;;
    *) usage "unexpected argument '$1'" ;;
  esac
done
[ -n "$dir" ] || usage "--tart-dir is required"
[ -n "$report" ] || usage "--report is required"
[ -x "$dir/bin/tart" ] || usage "no executable $dir/bin/tart"
dir=$(cd "$dir" && pwd)
PATH="$dir/bin:$PATH"
TART_HOME="$dir/tart-home"
export PATH TART_HOME
[ ! -x "$dir/bin/nc" ] || NC="$dir/bin/nc"

repo=$(git -C "$here" rev-parse --show-toplevel) || refuse "not in a git checkout"
[ -z "$(git -C "$repo" status --porcelain)" ] || refuse "the checkout has uncommitted changes; the report must name what ran"

# ---- clean-up, on any exit ----
started="" listeners="" saved_clip="" clip_saved=0 shared=""
cleanup() {
  local v
  # shellcheck disable=SC2086 # word splitting of the pid list is intended
  [ -z "$listeners" ] || kill $listeners 2>/dev/null || true
  for v in $started; do "$vm" stop "${v#task-}" --tart-dir "$dir" >/dev/null 2>&1 || true; done
  if [ "$mode" = known-bad ]; then
    tart stop "$KB" >/dev/null 2>&1 || true
    tart delete "$KB" >/dev/null 2>&1 || true
    [ -z "$shared" ] || rm -rf "$shared"
  fi
  [ $clip_saved -eq 0 ] || printf '%s' "$saved_clip" | pbcopy 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# ---- the report ----
results=""
line() { results="$results$1 $2 $3
"; }

# verdict <id> <probe output>: one report line from the probe's own line.
verdict() {
  local id=$1 out=$2 status detail
  status=$(printf '%s\n' "$out" | awk '$1 == "PROBE" { print $3; exit }')
  detail=$(printf '%s\n' "$out" | awk '$1 == "PROBE" { $1 = $2 = $3 = ""; sub(/^ +/, ""); print; exit }')
  case $mode:$status in
    run:blocked) line PASS "$id" "$detail" ;;
    run:reached) line FAIL "$id" "wall broken: $detail" ;;
    known-bad:reached) line FAIL "$id" "wall broken, as expected: $detail" ;;
    known-bad:blocked) line PASS "$id" "the unsafe VM still blocked it: $detail" ;;
    *) line ERROR "$id" "probe couldn't run: ${detail:-no PROBE line}" ;;
  esac
}

probe() { tart exec -i "$1" /bin/bash -s -- "${@:2}" <"$probe_script" 2>&1 || true; }

wait_ready() {
  local tries=0
  until tart exec "$1" /usr/bin/true >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ $tries -le $READY_TRIES ] || return 1
    sleep 2
  done
}

free_kb() { df -Pk "$TART_HOME" | awk 'NR == 2 { print $4 }'; }
sha() { shasum -a 256 "$1" 2>/dev/null | awk '{ print $1 }'; }

# base_fingerprint: the hashes and disk image size and time that must not change.
base_fingerprint() {
  local b="$TART_HOME/vms/base"
  echo "$(sha "$b/config.json") $(sha "$b/nvram.bin") $(stat -f '%z %m' "$b/disk.img" 2>/dev/null)"
}

random_word() { od -An -N6 -tx1 /dev/urandom | tr -d ' \n'; }

# ---- the Mac's side of the network probes ----
mac_lan_ip="" router=""
host_network() {
  local ifname
  ifname=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')
  router=$(route -n get default 2>/dev/null | awk '/gateway:/ { print $2; exit }')
  [ -n "$ifname" ] && mac_lan_ip=$(ipconfig getifaddr "$ifname" 2>/dev/null) || true
}

# listen <ip> <port>: macOS's own nc, bound to one address, for at most 60 s.
listen() {
  "$NC" -k -l "$1" "$2" >/dev/null 2>&1 </dev/null &
  listeners="$listeners $!"
  ( /bin/sleep 60; kill "$!" 2>/dev/null ) >/dev/null 2>&1 &
}

# attack_mac_lan <vm>: the mac and lan lines, each with its positive control from the Mac.
attack_mac_lan() {
  local v=$1 gw port out p router_port=""
  out=$(probe "$v" gateway)
  gw=$(printf '%s\n' "$out" | awk '$1 == "PROBE" && $3 == "value" { print $4; exit }')
  port=$((40000 + RANDOM % 20000))
  if [ -z "$mac_lan_ip" ] || [ -z "$gw" ]; then
    line ERROR mac "no address for the Mac (LAN '${mac_lan_ip}', gateway '${gw}')"
  else
    listen "$mac_lan_ip" "$port"
    listen "$gw" "$port"
    sleep 1
    if "$NC" -z -G 2 "$mac_lan_ip" "$port" >/dev/null 2>&1 && "$NC" -z -G 2 "$gw" "$port" >/dev/null 2>&1; then
      verdict mac "$(probe "$v" connect mac "$mac_lan_ip:$port" "$gw:$port")"
    else
      line ERROR mac "the Mac's own listener didn't answer on $mac_lan_ip and $gw"
    fi
  fi
  for p in 53 80 443; do
    if [ -n "$router" ] && "$NC" -z -G 2 "$router" "$p" >/dev/null 2>&1; then router_port=$p; break; fi
  done
  if [ -z "$router_port" ]; then
    line ERROR lan "the router '${router}' answers the Mac on none of 53, 80, 443"
  else
    verdict lan "$(probe "$v" connect lan "$router:$router_port")"
  fi
}

attack_clipboard() {
  local word
  word=$(random_word)
  saved_clip=$(pbpaste 2>/dev/null || true) && clip_saved=1
  printf '%s' "$word" | pbcopy || { line ERROR clipboard "pbcopy failed on the Mac"; return; }
  verdict clipboard "$(probe "$1" clipboard "$word")"
}

# attack_cpu_mem <vm>: what the guest sees, then the Mac's peaks under load.
attack_cpu_mem() {
  local v=$1 info cpus mem samples=0 peak_cpu=0 peak_rss=0 procs pressure i load_pid
  info=$(probe "$v" cpu-mem-info)
  cpus=$(printf '%s\n' "$info" | awk '$1 == "PROBE" && $3 == "value" { print $4; exit }')
  mem=$(printf '%s\n' "$info" | awk '$1 == "PROBE" && $3 == "value" { print $5; exit }')
  case "$cpus:$mem" in *[!0-9:]* | :* | *:) line ERROR cpu-mem "can't read the guest's CPUs and memory: $info"; return ;; esac
  probe "$v" load "$LOAD_SECONDS" >/dev/null &
  load_pid=$!
  i=0
  while [ $i -lt $((LOAD_SECONDS / 2)) ]; do
    sleep 2
    i=$((i + 1))
    # shellcheck disable=SC2009 # ps, not pgrep: the CPU and memory columns are needed
    procs=$(ps -axo pid=,%cpu=,rss=,comm= | grep 'com\.apple\.Virtualization\.VirtualMachine$' || true)
    [ "$(printf '%s\n' "$procs" | grep -c .)" -eq 1 ] || continue
    samples=$((samples + 1))
    peak_cpu=$(printf '%s\n' "$procs" | awk -v p="$peak_cpu" '{ print ($2 > p ? $2 : p) }')
    peak_rss=$(printf '%s\n' "$procs" | awk -v p="$peak_rss" '{ print ($3 > p ? $3 : p) }')
  done
  wait "$load_pid" 2>/dev/null || true
  pressure=$(memory_pressure 2>/dev/null | tail -n 1 || echo "memory_pressure unavailable")
  local detail
  detail="guest $cpus CPUs $mem bytes; Mac peak ${peak_cpu}% CPU, $((peak_rss / 1024)) MB, $samples samples; $pressure"
  if [ $samples -eq 0 ]; then
    line ERROR cpu-mem "no single VM process to sample; $detail"
  elif [ "$cpus" -eq 4 ] && [ "$mem" -eq 8589934592 ] &&
    awk -v c="$peak_cpu" -v r="$peak_rss" -v g="$GB_KB" \
      'BEGIN { exit !(c >= 300 && c <= 440 && r >= 6 * g && r <= 10 * g) }'; then
    line PASS cpu-mem "$detail"
  else
    line FAIL cpu-mem "outside 300-440% CPU, 6-10 GB, or not 4 CPUs and 8 GB; $detail"
  fi
}

# attack_disk <vm>: the guest fills its disk; the supervisor must stop it before the Mac runs low.
attack_disk() {
  local v=$1 min tries=0 f status fill_pid
  min=$(free_kb)
  probe "$v" disk-fill >"$dir/apple-vm/$v.disk-fill.out" 2>&1 &
  fill_pid=$!
  status=""
  while [ $tries -lt $DISK_TRIES ]; do
    sleep 2
    tries=$((tries + 1))
    f=$(free_kb)
    case $f in '' | *[!0-9]*) ;; *) [ "$f" -ge "$min" ] || min=$f ;; esac
    status=$(sed -n 's/^status=//p' "$dir/apple-vm/$v" 2>/dev/null || true)
    [ "$status" = running ] || break
  done
  kill "$fill_pid" 2>/dev/null || true
  local detail
  detail="lowest free on the Mac $((min / GB_KB)) GB; VM ${status:-deleted}; guest: $(tail -n 1 "$dir/apple-vm/$v.disk-fill.out" 2>/dev/null)"
  if [ "$status" != running ] && [ "$min" -ge $((DELETE_FREE_GB * GB_KB)) ]; then
    line PASS disk "$detail"
  else
    line FAIL disk "$detail"
  fi
}

start_task() {
  "$vm" start "${1#task-}" --tart-dir "$dir" --hours 2 || return 1
  started="$started $1"
  wait_ready "$1"
}

# ---- the runs ----
host_network
word=$(random_word)
if [ "$mode" = run ]; then
  before=$(base_fingerprint)
  if start_task $A; then
    case $(probe $A persist-write "$word") in
      *"PROBE persist-write value"*) wrote=1 ;;
      *) wrote=0 ;;
    esac
    verdict host-path "$(probe $A host-path)"
    attack_mac_lan $A
    attack_clipboard $A
    attack_cpu_mem $A
    "$vm" stop "${A#task-}" --tart-dir "$dir" >/dev/null && started=${started% "$A"}
  else
    line ERROR start "$A didn't start or answer"
  fi
  if start_task $B; then
    if [ "${wrote:-0}" -eq 1 ]; then
      verdict persist "$(probe $B persist-check "$word")"
    else
      line ERROR persist "the markers couldn't be written in $A"
    fi
    [ $disk_fill -eq 0 ] || attack_disk $B
  else
    line ERROR start "$B didn't start or answer"
  fi
  for v in $started; do "$vm" stop "${v#task-}" --tart-dir "$dir" >/dev/null 2>&1 || true; done
  started=""
  after=$(base_fingerprint)
  if [ -n "$before" ] && [ "$before" = "$after" ] && [ "$(printf '%s' "$before" | wc -w)" -eq 4 ]; then
    line PASS base "config.json, nvram.bin and disk.img unchanged"
  else
    line FAIL base "before '$before' after '$after'"
  fi
else
  ! tart list --source local --quiet | grep -qx "$KB" || refuse "$KB exists; run: apple-vm.sh stop 99 --tart-dir $dir"
  shared=$(mktemp -d)
  echo "$word" >"$shared/apple-vm-known-bad"
  tart clone base "$KB" || refuse "tart clone failed"
  tart set "$KB" --cpu 4 --memory 8192 || refuse "tart set failed"
  nohup tart run "$KB" --dir="probe:$shared" >/dev/null 2>&1 </dev/null &
  if wait_ready "$KB"; then
    verdict host-path "$(probe $KB host-path)"
    attack_mac_lan $KB
    attack_clipboard $KB
    probe $KB persist-write "$word" >/dev/null
    verdict persist "$(probe $KB persist-check "$word")"
  else
    line ERROR start "$KB didn't answer"
  fi
fi

# ---- write it ----
{
  echo "apple-vm-attacks $mode · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "macOS $(sw_vers -productVersion 2>/dev/null || echo ?) · tart $(tart --version 2>/dev/null || echo ?) · commit $(git -C "$repo" rev-parse HEAD)"
  echo "sha256 apple-vm.sh $(sha "$vm") apple-vm-attacks.sh $(sha "$0") apple-vm-probe.sh $(sha "$probe_script")"
  echo "tart list: $(tart list --format json 2>/dev/null | tr -d '\n' | tr -s ' ')"
  printf '%s' "$results"
} >"$report"
cat "$report"

expected=PASS
[ "$mode" = run ] || expected=FAIL
lines=$(printf '%s' "$results" | grep -c . || true)
good=$(printf '%s' "$results" | grep -c "^$expected " || true)
[ "$lines" -gt 0 ] && [ "$lines" -eq "$good" ] || exit 1
