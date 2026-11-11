#!/bin/bash
# The VM lane's host script, run by the owner on the local Mac (spec specs/apple-vm-host-script.md).
# Starts, lists and stops throwaway macOS VMs cloned from `base`, each named task-<n>, each under a
# supervisor that lives as long as its VM and stops or deletes it at its time limit or on low disk.
# Written for macOS's own /bin/bash 3.2 and BSD tools: no arrays, no bash-4 features.
#
# Usage:
#   apple-vm.sh start <n> --tart-dir <dir> [--hours <h>]   n: 1-98, h: 1-24 (default 12)
#   apple-vm.sh list --tart-dir <dir>
#   apple-vm.sh stop <n> --tart-dir <dir>                  n: 1-99 (stops and deletes)
#   apple-vm.sh kill-all --tart-dir <dir>
# <dir> holds bin/ (the tart wrapper and softnet) and tart-home/ (TART_HOME).
# Internal: `start` runs `apple-vm.sh _supervise <n> --tart-dir <dir> --nonce <nonce>` with nohup as
# the VM's supervisor; it isn't for the owner to run.
# Exit 0 = done; 1 = refused or failed; 2 = usage.
set -eu -o pipefail

TART_PIN=2.34.0
CPU=4
MEMORY_MB=8192
DNS_SERVERS="1.1.1.1 1.0.0.1"
GB_KB=1048576           # 1 GB in df's 1024-byte blocks
START_FREE_GB=60        # start refuses with less free on the Mac
MAX_GROWTH_GB=60        # the supervisor stops a VM once the Mac's free space fell this much since its start
STOP_FREE_GB=30         # ... or once the Mac has less than this free
DELETE_FREE_GB=15       # ... and deletes it below this
TICK_SECONDS=10
READY_TRIES=150         # 150 tries 2 s apart: 300 s for the VM to answer `tart exec`
STOP_TRIES=60           # 60 tries 1 s apart for a VM to stop

self=$0
usage() {
  echo "usage: apple-vm.sh start <n> --tart-dir <dir> [--hours <h>] | list --tart-dir <dir> | stop <n> --tart-dir <dir> | kill-all --tart-dir <dir>" >&2
  [ $# -eq 0 ] || echo "apple-vm: $*" >&2
  exit 2
}
refuse() { echo "apple-vm: $*" >&2; exit 1; }
say() { echo "apple-vm: $*"; }

# valid_n <n> <max>: a whole number 1..max, no sign, no leading zero.
valid_n() {
  case $1 in '' | 0* | *[!0-9]*) return 1 ;; esac
  [ ${#1} -le 2 ] && [ "$1" -ge 1 ] && [ "$1" -le "$2" ]
}

# is_task_name <name>: task-<n> with a valid n (1-99).
is_task_name() {
  case $1 in task-*) valid_n "${1#task-}" 99 ;; *) return 1 ;; esac
}

# ---- arguments ----
cmd=${1:-}
[ $# -gt 0 ] && shift
n="" dir="" hours=12 nonce=""
case $cmd in
  start | stop)
    [ $# -gt 0 ] || usage "$cmd needs <n>"
    n=$1; shift ;;
  list | kill-all) ;;
  _supervise)
    [ $# -gt 0 ] || usage "$cmd needs <n>"
    n=$1; shift ;;
  *) usage "unknown command '${cmd}'" ;;
esac
while [ $# -gt 0 ]; do
  case $1 in
    --tart-dir) [ $# -ge 2 ] || usage "--tart-dir needs a value"; dir=$2; shift 2 ;;
    --hours) [ "$cmd" = start ] && [ $# -ge 2 ] || usage "--hours is for start, with a value"; hours=$2; shift 2 ;;
    --nonce) [ "$cmd" = _supervise ] && [ $# -ge 2 ] || usage "unexpected --nonce"; nonce=$2; shift 2 ;;
    *) usage "unexpected argument '$1'" ;;
  esac
done
case $cmd in
  start) valid_n "$n" 98 || usage "start takes <n> from 1 to 98 (99 is the known-bad run's)" ;;
  stop | _supervise) valid_n "$n" 99 || usage "<n> must be a whole number from 1 to 99" ;;
esac
case $hours in '' | 0* | *[!0-9]*) usage "--hours must be 1 to 24" ;; esac
[ "$hours" -ge 1 ] && [ "$hours" -le 24 ] || usage "--hours must be 1 to 24"
[ -n "$dir" ] || usage "--tart-dir is required"
[ -x "$dir/bin/tart" ] || usage "no executable $dir/bin/tart"
[ "$cmd" != _supervise ] || [ -n "$nonce" ] || usage "_supervise needs --nonce"

dir=$(cd "$dir" && pwd)
PATH="$dir/bin:$PATH"
TART_HOME="$dir/tart-home"
export PATH TART_HOME
state_dir="$dir/apple-vm"
mkdir -p "$state_dir"

# ---- helpers over tart and the Mac ----
now() {
  local t
  t=$(date +%s) || refuse "date failed"
  case $t in '' | *[!0-9]*) refuse "can't read the time: '$t'" ;; esac
  echo "$t"
}

# json_field <key>: the value of "<key>" in tart's pretty-printed JSON on stdin (one key per line).
json_field() {
  awk -v k="\"$1\"" '{
    i = index($0, k)
    if (i == 0) next
    v = substr($0, i + length(k))
    sub(/^[ \t]*:[ \t]*/, "", v); sub(/[ \t]*,?[ \t]*$/, "", v); gsub(/"/, "", v)
    print v; found = 1; exit
  } END { if (!found) exit 1 }'
}

vm_names() { tart list --source local --quiet; }
vm_exists() { vm_names | grep -qx -- "$1"; }

# vm_running <name>: 0 when tart says it runs, 1 when not; refuses on output it can't read.
vm_running() {
  local out r
  out=$(tart get "$1" --format json) || return 1
  r=$(printf '%s\n' "$out" | json_field Running) || refuse "can't read Running for $1"
  case $r in true) return 0 ;; false) return 1 ;; *) refuse "can't read Running for $1: '$r'" ;; esac
}

free_kb() {
  local f
  f=$(df -Pk "$TART_HOME" | awk 'NR == 2 { print $4 }') || refuse "df failed"
  case $f in '' | *[!0-9]*) refuse "can't read free space: '$f'" ;; esac
  echo "$f"
}

# running_vm_count: every VM running on the Mac, whatever made it (Virtualization's processes).
running_vm_count() {
  local out
  out=$(ps -axo comm=) || refuse "ps failed"
  printf '%s\n' "$out" | grep -c 'com\.apple\.Virtualization\.VirtualMachine$' || true
}

check_tart_version() {
  local v
  v=$(tart --version 2>/dev/null) || refuse "tart --version failed"
  [ "$v" = "$TART_PIN" ] || refuse "tart is '$v'; these scripts are pinned to $TART_PIN"
}

check_softnet() {
  local s="$dir/bin/softnet" out uid mode
  [ -f "$s" ] || refuse "no $s"
  out=$(stat -f '%u %p' "$s") || refuse "can't stat $s"
  uid=${out%% *} mode=${out#* }
  case "$uid$mode" in '' | *[!0-9]*) refuse "can't read $s's owner and mode: '$out'" ;; esac
  if [ "$uid" -ne 0 ] || [ $((8#$mode & 2048)) -eq 0 ]; then
    refuse "softnet must be owned by root with its setuid bit; run once: sudo chown root '$s' && sudo chmod u+s '$s'"
  fi
}

# ---- state files: <tart-dir>/apple-vm/task-<n>, key=value lines ----
state_file() { echo "$state_dir/$1"; }
state_get() {
  local f
  f=$(state_file "$1")
  [ -f "$f" ] || return 1
  sed -n "s/^$2=//p" "$f" | head -n 1
}
state_set() {
  local f tmp
  f=$(state_file "$1")
  tmp="$f.tmp.$$"
  { grep -v "^$2=" "$f" 2>/dev/null || true; echo "$2=$3"; } >"$tmp"
  mv "$tmp" "$f"
}

# supervisor_alive <name>: its recorded supervisor runs and carries its nonce.
supervisor_alive() {
  local pid nonce cmdline
  pid=$(state_get "$1" pid) || return 1
  nonce=$(state_get "$1" nonce) || return 1
  case $pid in '' | *[!0-9]*) return 1 ;; esac
  cmdline=$(ps -p "$pid" -o command= 2>/dev/null) || return 1
  case $cmdline in *"_supervise ${1#task-} "*"$nonce"*) return 0 ;; *) return 1 ;; esac
}

# stop_vm <name>: stops and deletes one task VM, ending its supervisor first.
stop_vm() {
  local name=$1 pid tries
  is_task_name "$name" || refuse "refusing to stop '$name'"
  if supervisor_alive "$name"; then
    pid=$(state_get "$name" pid)
    kill "$pid" 2>/dev/null || true
  fi
  if vm_exists "$name"; then
    if vm_running "$name"; then
      tart stop "$name" >/dev/null 2>&1 || true
      tries=0
      while vm_running "$name"; do
        tries=$((tries + 1))
        [ $tries -le $STOP_TRIES ] || refuse "$name didn't stop"
        sleep 1
      done
    fi
    tart delete "$name" || refuse "tart delete $name failed"
  fi
  rm -f "$(state_file "$name")"
}

task_vms() { vm_names | while IFS= read -r v; do ! is_task_name "$v" || echo "$v"; done; }

# sweep: delete task VMs past their deadline, or stopped with no live supervisor.
sweep() {
  local t v deadline
  t=$(now)
  for v in $(task_vms); do
    deadline=$(state_get "$v" deadline || true)
    if [ -n "$deadline" ] && [ "$t" -ge "$deadline" ]; then
      say "deleting $v: past its time limit"
      stop_vm "$v"
    elif ! vm_running "$v" && ! supervisor_alive "$v"; then
      say "deleting $v: not running and no supervisor"
      stop_vm "$v"
    fi
  done
  # A state file without its VM is left from an interrupted start or stop.
  for f in "$state_dir"/task-*; do
    [ -f "$f" ] || continue
    v=${f##*/}
    case $v in *.tmp.*) rm -f "$f"; continue ;; esac
    vm_exists "$v" || rm -f "$f"
  done
}

# ---- the supervisor ----
# tick <name>: one check. Returns 0 to keep going, 1 when the supervisor should exit.
tick() {
  local name=$1 t deadline status start_free free run_pid
  [ "$(state_get "$name" nonce || true)" = "$nonce" ] || return 1
  t=$(now)
  deadline=$(state_get "$name" deadline)
  if [ "$t" -ge "$deadline" ]; then
    say "$name: time limit reached; stopping and deleting it"
    stop_vm_from_supervisor "$name"
    return 1
  fi
  status=$(state_get "$name" status || true)
  [ "$status" = running ] || return 0
  free=$(free_kb)
  start_free=$(state_get "$name" start_free_kb)
  if [ "$free" -lt $((DELETE_FREE_GB * GB_KB)) ]; then
    say "$name: the Mac has $((free / GB_KB)) GB free, under $DELETE_FREE_GB GB; deleting it"
    stop_vm_from_supervisor "$name"
    return 1
  fi
  if [ "$free" -lt $((STOP_FREE_GB * GB_KB)) ] || [ $((start_free - free)) -gt $((MAX_GROWTH_GB * GB_KB)) ]; then
    say "$name: the Mac has $((free / GB_KB)) GB free, $(((start_free - free) / GB_KB)) GB less than at its start; stopping it for disk"
    state_set "$name" status disk-stopped
    tart stop "$name" >/dev/null 2>&1 || true
    return 0
  fi
  run_pid=$(state_get "$name" run_pid || true)
  if [ -n "$run_pid" ] && ! kill -0 "$run_pid" 2>/dev/null; then
    say "$name: stopped on its own; deleting it"
    stop_vm_from_supervisor "$name"
    return 1
  fi
  return 0
}

# The supervisor must not end itself through stop_vm's kill: clear its pid first.
stop_vm_from_supervisor() {
  state_set "$1" pid ""
  stop_vm "$1"
}

supervise() {
  local name=$1
  trap 'exit 0' TERM INT HUP
  tart run "$name" --net-softnet-block=@host --no-clipboard >>"$state_dir/$name.log" 2>&1 </dev/null &
  state_set "$name" run_pid "$!"
  while tick "$name"; do sleep $TICK_SECONDS; done
}

# ---- commands ----
start() {
  local name="task-$n" t tries base_free count
  check_tart_version
  check_softnet
  sweep
  vm_exists base || refuse "no VM named base in $TART_HOME"
  ! vm_exists "$name" || refuse "$name already exists"
  count=$(running_vm_count)
  [ "$count" -lt 2 ] || refuse "two VMs already run on this Mac (Apple's licence allows two)"
  base_free=$(free_kb)
  [ "$base_free" -ge $((START_FREE_GB * GB_KB)) ] ||
    refuse "the Mac has $((base_free / GB_KB)) GB free; start needs $START_FREE_GB GB"

  tart clone base "$name" || refuse "tart clone failed"
  tart set "$name" --cpu "$CPU" --memory "$MEMORY_MB" || { stop_vm "$name"; refuse "tart set failed"; }
  t=$(now)
  nonce=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
  rm -f "$(state_file "$name")"
  state_set "$name" nonce "$nonce"
  state_set "$name" started "$t"
  state_set "$name" deadline $((t + hours * 3600))
  state_set "$name" start_free_kb "$(free_kb)"
  state_set "$name" status running
  nohup "$self" _supervise "$n" --tart-dir "$dir" --nonce "$nonce" >>"$state_dir/$name.log" 2>&1 </dev/null &
  state_set "$name" pid "$!"

  tries=0
  until tart exec "$name" /usr/bin/true >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ $tries -le $READY_TRIES ] || { stop_vm "$name"; refuse "$name didn't answer tart exec within 300 s"; }
    sleep 2
  done
  # Softnet's @host block also blocks the Mac's DNS, so the guest gets a public resolver.
  # shellcheck disable=SC2016 # expanded in the guest
  tart exec "$name" /bin/bash -c 'networksetup -listallnetworkservices | tail -n +2 | sed "s/^\*//" |
      while IFS= read -r s; do sudo -n networksetup -setdnsservers "$s" '"$DNS_SERVERS"' || exit 1; done &&
      scutil --dns | grep -q "nameserver.*1\.1\.1\.1"' >/dev/null 2>&1 ||
    { stop_vm "$name"; refuse "couldn't set $name's DNS servers"; }
  say "$name runs: 4 CPU, 8 GB, the Mac and LAN blocked, clipboard off; deleted in $hours h"
}

list() {
  local t v run age left status sup
  sweep
  t=$(now)
  for v in $(task_vms); do
    if vm_running "$v"; then run=running; else run=stopped; fi
    status=$(state_get "$v" status || echo unknown)
    if supervisor_alive "$v"; then sup=supervised; else sup="NO SUPERVISOR"; fi
    age=$(( (t - $(state_get "$v" started || echo "$t")) / 60 ))
    left=$(( ($(state_get "$v" deadline || echo "$t") - t) / 60 ))
    echo "$v $run $status $sup age ${age}m left ${left}m size $(tart get "$v" --format json | json_field Size || echo ?) GB"
  done
}

kill_all() {
  local v
  for v in $(task_vms); do say "stopping and deleting $v"; stop_vm "$v"; done
}

case $cmd in
  start) start ;;
  list) list ;;
  stop)
    vm_exists "task-$n" || [ -f "$(state_file "task-$n")" ] || refuse "no task-$n"
    stop_vm "task-$n"; say "task-$n stopped and deleted"
    sweep ;;
  kill-all) sweep; kill_all ;;
  _supervise) supervise "task-$n" ;;
esac
