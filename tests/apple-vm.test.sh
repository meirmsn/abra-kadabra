#!/usr/bin/env bash
# Tests for the VM lane's host scripts, mac/apple-vm.sh, mac/apple-vm-attacks.sh and
# mac/apple-vm-probe.sh (spec specs/apple-vm-host-script.md), against a fake Tart and fake macOS
# tools (tests/fixtures/apple-vm/bin) in a temporary --tart-dir. Each item gets a known-bad input.
# Runs on Linux in CI and, for macOS's bash 3.2 and BSD tools, on the local Mac (AC-16).
# APPLE_VM_MAC_DIR overrides the scripts' folder (the mutant run).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
mac_dir=${APPLE_VM_MAC_DIR:-$repo_root/mac}
fakes="$repo_root/tests/fixtures/apple-vm/bin"
GB=1048576

roots=""
cleanup_all() {
  local r
  for r in $roots; do
    pkill -f "$r/" 2>/dev/null || true
    rm -rf "$r"
  done
}
trap cleanup_all EXIT

ok() { echo "ok - $*"; }

# new_env: a fresh checkout of the scripts, a Tart folder with `base`, and the fakes' state.
new_env() {
  T=$(mktemp -d)
  roots="$roots $T"
  isolate_git "$T"
  mkdir -p "$T/repo/mac"
  cp "$mac_dir"/apple-vm.sh "$mac_dir"/apple-vm-attacks.sh "$mac_dir"/apple-vm-probe.sh "$T/repo/mac/"
  git -C "$T/repo" init -q
  git -C "$T/repo" add -A
  git -C "$T/repo" commit -qm scripts
  V="$T/repo/mac/apple-vm.sh"
  ATK="$T/repo/mac/apple-vm-attacks.sh"
  D="$T/tart"
  mkdir -p "$D/bin" "$D/tart-home/vms/base" "$D/apple-vm"
  cp "$fakes"/* "$D/bin/"
  : >"$D/bin/softnet"
  echo '{"os":"darwin"}' >"$D/tart-home/vms/base/config.json"
  echo nvram >"$D/tart-home/vms/base/nvram.bin"
  echo disk >"$D/tart-home/vms/base/disk.img"
  FAKE="$T/fake"
  export FAKE
  mkdir -p "$FAKE/probe"
  echo 1000000 >"$FAKE/clock"
  echo $((500 * GB)) >"$FAKE/free_kb"
  : >"$FAKE/vmprocs"
  : >"$FAKE/calls"
  printf '%s\n' '192.0.2.10:*' '192.168.64.1:*' '192.0.2.1:53' >"$FAKE/nc_open"
  echo "PROBE gateway value 192.168.64.1" >"$FAKE/probe/gateway"
  echo "PROBE host-path blocked nothing shared" >"$FAKE/probe/host-path"
  echo "PROBE connect blocked no connection" >"$FAKE/probe/connect"
  echo "PROBE clipboard blocked never arrived" >"$FAKE/probe/clipboard"
  echo "PROBE persist-write value markers written" >"$FAKE/probe/persist-write"
  echo "PROBE persist-check blocked no marker" >"$FAKE/probe/persist-check"
  echo "PROBE cpu-mem-info value 4 8589934592" >"$FAKE/probe/cpu-mem-info"
  echo "PROBE load value loaded" >"$FAKE/probe/load"
  echo "PROBE disk-fill value filled" >"$FAKE/probe/disk-fill"
  echo "123 380.5 $((7 * GB)) com.apple.Virtualization.VirtualMachine" >"$FAKE/vmsamples"
}

# run_cmd <cmd...>: runs it, keeping its output in $out and its exit code in $rc.
run_cmd() { set +e; out=$("$@" 2>&1); rc=$?; set -e; }
expect_rc() { [ "$rc" -eq "$1" ] || fail "$2: exit $rc, want $1; output: $out"; }
# wait_for <seconds> <test...>
wait_for() {
  local s=$1 i=0
  shift
  until "$@"; do
    i=$((i + 1))
    [ $i -le $((s * 20)) ] || return 1
    /bin/sleep 0.05
  done
}
ftart() { TART_HOME="$D/tart-home" "$D/bin/tart" "$@"; }
vm_dir() { echo "$D/tart-home/vms/$1"; }
has_vm() { [ -d "$(vm_dir "$1")" ]; }
no_vm() { ! has_vm "$1"; }
is_running() { [ -f "$(vm_dir "$1")/running" ] && kill -0 "$(cat "$(vm_dir "$1")/running")" 2>/dev/null; }
state() { sed -n "s/^$2=//p" "$D/apple-vm/$1" 2>/dev/null; }
# edit_file <file> <sed expression>: sed without -i, which BSD and GNU spell differently.
edit_file() { sed "$2" "$1" >"$1.new" && mv "$1.new" "$1"; }
set_state() { edit_file "$D/apple-vm/$1" "s/^$2=.*/$2=$3/"; }
calls_with() { grep -c -- "$1" "$FAKE/calls" || true; }
start_ok() { run_cmd "$V" start "$1" --tart-dir "$D"; expect_rc 0 "start $1"; }

# no_base_touched: no tart stop, delete, set, run or exec was ever given base or a non-task name.
no_base_touched() {
  local bad
  bad=$(grep -E '^tart (stop|delete|set|run|exec)( -i)? ' "$FAKE/calls" | awk '{ n = ($3 == "-i") ? $4 : $3; print n }' |
    grep -vE '^task-([1-9]|[1-9][0-9])$' || true)
  [ -z "$bad" ] || fail "tart was given a name that isn't task-<n>: $bad"
}

# ---- apple-vm.sh ----

new_env
start_ok 3
has_vm task-3 || fail "no task-3 after start"
grep -q "task-3 --cpu 4 --memory 8192" "$(vm_dir task-3)/set-args" || fail "not set to 4 CPU, 8192 MB"
wait_for 5 test -f "$(vm_dir task-3)/run-args" || fail "task-3 never ran"
args=$(cat "$(vm_dir task-3)/run-args")
[ "$args" = "task-3 --net-softnet-block=@host --no-clipboard" ] || fail "run args: '$args'"
[ "$(state task-3 deadline)" = $((1000000 + 12 * 3600)) ] || fail "deadline isn't 12 h"
ok "apple-vm-host-script AC-1: start clones, sets 4 CPU and 8 GB, runs with @host blocked and no clipboard or share"

run_cmd "$V" start 4 --tart-dir "$D" --hours 1
expect_rc 0 "start --hours 1"
[ "$(state task-4 deadline)" = $((1000000 + 3600)) ] || fail "--hours 1 isn't honoured"
ok "apple-vm-host-script AC-1: --hours sets the deadline"

new_env
touch "$FAKE/exec-dead"
run_cmd "$V" start 3 --tart-dir "$D"
[ "$rc" -ne 0 ] || fail "start passed with a VM that never answers"
wait_for 5 no_vm task-3 || fail "task-3 left behind after an unanswered start"
ok "apple-vm-host-script AC-1: a VM that never answers tart exec fails the start and is deleted"

new_env
echo 1 >"$FAKE/dns-exit"
run_cmd "$V" start 3 --tart-dir "$D"
[ "$rc" -ne 0 ] || fail "start passed though the DNS servers weren't set"
wait_for 5 no_vm task-3 || fail "task-3 left behind after a DNS failure"
ok "apple-vm-host-script AC-1: a failed DNS set fails the start and deletes the VM"

new_env
start_ok 3
ftart clone base other >/dev/null
run_cmd "$V" list --tart-dir "$D"
expect_rc 0 list
printf '%s\n' "$out" | grep -q "^task-3 running running supervised" || fail "list: $out"
! printf '%s\n' "$out" | grep -qE '^(other|base) ' || fail "list shows a VM that isn't task-<n>: $out"
ok "apple-vm-host-script AC-2: list shows task VMs only, with run state and supervisor"

run_cmd "$V" stop 3 --tart-dir "$D"
expect_rc 0 stop
no_vm task-3 || fail "task-3 still there after stop"
[ ! -f "$D/apple-vm/task-3" ] || fail "state file left after stop"
ok "apple-vm-host-script AC-3: stop stops and deletes the VM and its state"

start_ok 5
start_ok 6
run_cmd "$V" kill-all --tart-dir "$D"
expect_rc 0 kill-all
{ no_vm task-5 && no_vm task-6; } || fail "kill-all left a task VM"
{ has_vm base && has_vm other; } || fail "kill-all touched a VM that isn't task-<n>"
ok "apple-vm-host-script AC-3: kill-all deletes every task VM and no other"
no_base_touched

new_env
start_ok 3
echo $((1000000 + 12 * 3600 + 1)) >"$FAKE/clock"
wait_for 5 no_vm task-3 || fail "the supervisor didn't delete task-3 at its deadline"
ok "apple-vm-host-script AC-4: the supervisor deletes its VM at the deadline"

new_env
start_ok 3
pkill -f "_supervise 3 " || true
wait_for 5 sh -c "! pgrep -f '[_]supervise 3 ' >/dev/null" || fail "supervisor still alive"
echo $((1000000 + 12 * 3600 + 1)) >"$FAKE/clock"
run_cmd "$V" list --tart-dir "$D"
printf '%s\n' "$out" | grep -q "deleting task-3: past its time limit" || fail "sweep didn't report: $out"
no_vm task-3 || fail "sweep didn't delete a VM past its deadline"
ok "apple-vm-host-script AC-4: every command deletes a VM past its deadline, saying so"

new_env
ftart clone base task-8 >/dev/null
printf 'nonce=x\npid=999999\nstarted=1000000\ndeadline=9999999\nstatus=running\n' >"$D/apple-vm/task-8"
run_cmd "$V" list --tart-dir "$D"
printf '%s\n' "$out" | grep -q "deleting task-8: not running and no supervisor" || fail "orphan not reported: $out"
no_vm task-8 || fail "a stopped VM with no supervisor survived the sweep"
ok "apple-vm-host-script AC-4: a stopped VM with no supervisor is deleted"

new_env
start_ok 6
set_state task-6 nonce someone-else
echo $((1000000 + 12 * 3600 + 1)) >"$FAKE/clock"
/bin/sleep 1
has_vm task-6 || fail "a supervisor deleted a VM whose state names another nonce"
ok "apple-vm-host-script AC-4: a supervisor never deletes a VM restarted under another nonce"

new_env
start_ok 7
echo $((25 * GB)) >"$FAKE/free_kb"
wait_for 5 sh -c "grep -q '^status=disk-stopped' '$D/apple-vm/task-7'" || fail "not stopped for disk at 25 GB free"
wait_for 5 sh -c "! test -f '$(vm_dir task-7)/running'" || fail "task-7 still runs after the disk stop"
echo $((500 * GB)) >"$FAKE/free_kb"
run_cmd "$V" list --tart-dir "$D"
printf '%s\n' "$out" | grep -q "^task-7 stopped disk-stopped supervised" || fail "list: $out"
has_vm task-7 || fail "a disk-stopped VM with its supervisor was deleted"
ok "apple-vm-host-script AC-4: a VM stopped for disk is kept while its supervisor lives"
pkill -f "_supervise 7 " || true
wait_for 5 sh -c "! pgrep -f '[_]supervise 7 ' >/dev/null" || fail "supervisor still alive"
run_cmd "$V" list --tart-dir "$D"
no_vm task-7 || fail "a disk-stopped VM without its supervisor survived"
ok "apple-vm-host-script AC-4: a VM stopped for disk without its supervisor is deleted"
ok "apple-vm-host-script AC-5: under 30 GB free the supervisor stops the VM"

new_env
start_ok 3
echo $((500 * GB - 61 * GB)) >"$FAKE/free_kb"
wait_for 5 sh -c "grep -q '^status=disk-stopped' '$D/apple-vm/task-3'" || fail "not stopped after 61 GB of growth"
ok "apple-vm-host-script AC-5: past 60 GB of growth the supervisor stops the VM"

new_env
start_ok 3
echo $((500 * GB - 59 * GB)) >"$FAKE/free_kb"
/bin/sleep 0.5
[ "$(state task-3 status)" = running ] || fail "stopped at 59 GB of growth"
echo $((14 * GB)) >"$FAKE/free_kb"
wait_for 5 no_vm task-3 || fail "not deleted under 15 GB free"
grep -q "under 15 GB; deleting it" "$D/apple-vm/task-3.log" || fail "the delete trip isn't logged"
ok "apple-vm-host-script AC-5: under 15 GB free the supervisor deletes the VM, and logs it"

new_env
for bad in 0 100 -1 '1;x' ../base base '' 01 1.5; do
  : >"$FAKE/calls"
  run_cmd "$V" stop "$bad" --tart-dir "$D"
  expect_rc 2 "stop '$bad'"
  [ ! -s "$FAKE/calls" ] || fail "stop '$bad' called tart: $(cat "$FAKE/calls")"
  run_cmd "$V" start "$bad" --tart-dir "$D"
  expect_rc 2 "start '$bad'"
  [ ! -s "$FAKE/calls" ] || fail "start '$bad' called tart"
done
run_cmd "$V" start 99 --tart-dir "$D"
expect_rc 2 "start 99"
ok "apple-vm-host-script AC-6: a bad <n> exits 2 and calls no tart command; start refuses 99"

refused() {
  run_cmd "$V" start 3 --tart-dir "$D"
  expect_rc 1 "$1"
  [ "$(calls_with 'tart clone')" -eq 0 ] && [ "$(calls_with 'tart run')" -eq 0 ] || fail "$1: cloned or ran"
  printf '%s\n' "$out" | grep -qi -- "$2" || fail "$1: no '$2' in: $out"
}
new_env
start_ok 3
: >"$FAKE/calls"
refused "task-3 exists" "already exists"
new_env
rm -rf "$D/tart-home/vms/base"
refused "no base" "no VM named base"
new_env
printf '%s\n' /x/com.apple.Virtualization.VirtualMachine /y/com.apple.Virtualization.VirtualMachine >"$FAKE/vmprocs"
refused "two VMs" "two VMs"
new_env
echo $((59 * GB)) >"$FAKE/free_kb"
refused "59 GB free" "needs 60 GB"
new_env
echo 2.35.0 >"$FAKE/version"
refused "tart 2.35.0" "pinned to 2.34.0"
new_env
echo "501 104755" >"$FAKE/softnet_stat"
refused "softnet not root's" "sudo chown root"
new_env
echo "0 100755" >"$FAKE/softnet_stat"
refused "softnet without setuid" "setuid"
ok "apple-vm-host-script AC-7: start refuses an existing VM, no base, two VMs, low disk, another tart, an unset softnet"

new_env
for args in "" "frob --tart-dir $D" "start" "list" "list --tart-dir" "list --tart-dir $D extra" \
  "start 3 --tart-dir $D --hours 0" "start 3 --tart-dir $D --hours 25" "start 3 --tart-dir $D --hours x" \
  "list --tart-dir $T/nowhere" "list --hours 2 --tart-dir $D"; do
  # shellcheck disable=SC2086 # the cases are word lists
  run_cmd "$V" $args
  expect_rc 2 "usage case '$args'"
  printf '%s\n' "$out" | grep -q "^usage:" || fail "no usage line for '$args'"
done
ok "apple-vm-host-script AC-8: usage errors exit 2 with a usage line"
new_env
: >"$FAKE/version"
run_cmd "$V" start 3 --tart-dir "$D"
[ "$rc" -ne 0 ] || fail "a tart that prints nothing passed"
new_env
echo "lots" >"$FAKE/free_kb"
run_cmd "$V" start 3 --tart-dir "$D"
[ "$rc" -ne 0 ] || fail "a df it can't read passed"
new_env
start_ok 3
echo "noon" >"$FAKE/clock"
run_cmd "$V" list --tart-dir "$D"
[ "$rc" -ne 0 ] || fail "a date it can't read passed"
ok "apple-vm-host-script AC-8: a tool printing nothing or garbage fails, never passes"

# ---- apple-vm-attacks.sh ----

expect_line() { grep -q "^$1 $2 " "$T/report" || fail "no '$1 $2' line in: $(cat "$T/report")"; }

new_env
run_cmd "$ATK" run --tart-dir "$D" --report "$T/report"
expect_rc 0 "attack run, walls holding"
for id in host-path mac lan clipboard cpu-mem persist base; do expect_line PASS "$id"; done
head -n 3 "$T/report" | grep -q "^sha256 apple-vm.sh [0-9a-f]\{64\} apple-vm-attacks.sh [0-9a-f]\{64\} apple-vm-probe.sh [0-9a-f]\{64\}" ||
  fail "the header doesn't hash the scripts"
grep -q "commit $(git -C "$T/repo" rev-parse HEAD)" "$T/report" || fail "the header doesn't name the commit"
{ no_vm task-90 && no_vm task-91; } || fail "the run left its VMs"
ok "apple-vm-host-script AC-9: a run where every wall holds is all PASS, names what ran and cleans up"
ok "apple-vm-host-script AC-10: host-path, mac, lan, clipboard, persist, base and cpu-mem lines"
no_base_touched

new_env
echo junk >>"$T/repo/mac/apple-vm.sh"
run_cmd "$ATK" run --tart-dir "$D" --report "$T/report"
expect_rc 1 "a dirty checkout"
printf '%s\n' "$out" | grep -q "uncommitted" || fail "no reason given: $out"
ok "apple-vm-host-script AC-9: a checkout with uncommitted changes is refused"

attack_fails() {
  run_cmd "$ATK" run --tart-dir "$D" --report "$T/report"
  expect_rc 1 "$1"
  expect_line "$2" "$3"
}
new_env
echo "PROBE host-path reached volumes: My Shared Files;" >"$FAKE/probe/host-path"
attack_fails "a shared folder" FAIL host-path
new_env
echo "PROBE connect reached connected to 192.0.2.10:4" >"$FAKE/probe/connect"
attack_fails "the Mac reachable" FAIL mac
expect_line FAIL lan
new_env
echo "PROBE clipboard reached it arrived" >"$FAKE/probe/clipboard"
attack_fails "the clipboard" FAIL clipboard
new_env
echo "PROBE persist-check reached markers found: /Users/Shared/.apple-vm-marker" >"$FAKE/probe/persist-check"
attack_fails "a marker survives" FAIL persist
new_env
printf '#!/bin/bash\necho changed >>"%s"\n' "$D/tart-home/vms/base/config.json" >"$FAKE/hook-persist-check"
chmod +x "$FAKE/hook-persist-check"
attack_fails "base changed" FAIL base
new_env
echo "123 100.0 $((7 * GB)) com.apple.Virtualization.VirtualMachine" >"$FAKE/vmsamples"
attack_fails "CPU load never seen" FAIL cpu-mem
new_env
echo "123 380.0 $((11 * GB)) com.apple.Virtualization.VirtualMachine" >"$FAKE/vmsamples"
attack_fails "memory past 10 GB" FAIL cpu-mem
new_env
echo "PROBE cpu-mem-info value 8 8589934592" >"$FAKE/probe/cpu-mem-info"
attack_fails "the guest sees 8 CPUs" FAIL cpu-mem
ok "apple-vm-host-script AC-10: each broken wall is a FAIL line and fails the run"

new_env
: >"$FAKE/probe/host-path"
attack_fails "a probe with no output" ERROR host-path
new_env
printf '%s\n' '192.0.2.1:53' >"$FAKE/nc_open"
attack_fails "a listener that never answers" ERROR mac
new_env
printf '%s\n' '192.0.2.10:*' '192.168.64.1:*' >"$FAKE/nc_open"
attack_fails "a router that answers nothing" ERROR lan
new_env
: >"$FAKE/vmsamples"
attack_fails "no VM process to sample" ERROR cpu-mem
ok "apple-vm-host-script AC-9: a probe that can't run, or has no control, fails the run"

new_env
printf '#!/bin/bash\necho %s >"%s"\n' $((500 * GB - 70 * GB)) "$FAKE/free_kb" >"$FAKE/hook-disk-fill"
chmod +x "$FAKE/hook-disk-fill"
run_cmd "$ATK" run --tart-dir "$D" --report "$T/report" --disk-fill
expect_rc 0 "disk attack, supervisor stops the VM"
expect_line PASS disk
new_env
printf '#!/bin/bash\necho %s >"%s"\n' $((500 * GB - 10 * GB)) "$FAKE/free_kb" >"$FAKE/hook-disk-fill"
chmod +x "$FAKE/hook-disk-fill"
edit_file "$ATK" 's/^DISK_TRIES=900 /DISK_TRIES=20 /'
chmod +x "$ATK"
git -C "$T/repo" commit -qam "short disk wait for the test"
run_cmd "$ATK" run --tart-dir "$D" --report "$T/report" --disk-fill
expect_rc 1 "a VM never stopped for disk"
expect_line FAIL disk
ok "apple-vm-host-script AC-10: the disk attack passes only when the supervisor stops the VM"

new_env
echo "PROBE load value loaded" >"$FAKE/probe/load"
printf '#!/bin/bash\n/bin/sleep 20\n' >"$FAKE/hook-load"
chmod +x "$FAKE/hook-load"
"$ATK" run --tart-dir "$D" --report "$T/report" >/dev/null 2>&1 &
atk=$!
wait_for 10 sh -c "pgrep -f '[h]ook-load' >/dev/null" || fail "the run never reached the load"
pgrep -f "$D/bin/nc -k -l" >/dev/null || fail "no listener running before the interrupt"
kill -TERM "$atk"
wait "$atk" 2>/dev/null || true
wait_for 5 no_vm task-90 || fail "an interrupted run left task-90"
pgrep -f "$D/bin/nc -k -l" >/dev/null && fail "an interrupted run left a listener"
ok "apple-vm-host-script AC-9: an interrupted run deletes its VMs and ends its listeners"

reach_all() {
  echo "PROBE host-path reached volumes: My Shared Files;" >"$FAKE/probe/host-path"
  echo "PROBE connect reached connected" >"$FAKE/probe/connect"
  echo "PROBE clipboard reached it arrived" >"$FAKE/probe/clipboard"
  echo "PROBE persist-check reached markers found" >"$FAKE/probe/persist-check"
}
new_env
reach_all
run_cmd "$ATK" known-bad --tart-dir "$D" --report "$T/report"
expect_rc 0 "known-bad, every wall broken"
for id in host-path mac lan clipboard persist; do expect_line FAIL "$id"; done
grep -q "tart run task-99 --dir=probe:" "$FAKE/calls" || fail "task-99 didn't get a shared folder"
! grep -q "tart run task-99.*softnet" "$FAKE/calls" || fail "task-99 ran with softnet"
no_vm task-99 || fail "known-bad left task-99"
ok "apple-vm-host-script AC-11: known-bad runs task-99 unsafely and exits 0 when every line is FAIL"

new_env
reach_all
echo "PROBE clipboard blocked never arrived" >"$FAKE/probe/clipboard"
run_cmd "$ATK" known-bad --tart-dir "$D" --report "$T/report"
expect_rc 1 "known-bad with one wall holding"
expect_line PASS clipboard
ok "apple-vm-host-script AC-11: known-bad fails when a probe can't see the broken wall"

new_env
reach_all
printf '#!/bin/bash\n/bin/sleep 20\n' >"$FAKE/hook-clipboard"
chmod +x "$FAKE/hook-clipboard"
"$ATK" known-bad --tart-dir "$D" --report "$T/report" >/dev/null 2>&1 &
atk=$!
wait_for 10 sh -c "pgrep -f '[h]ook-clipboard' >/dev/null" || fail "known-bad never reached the clipboard probe"
shared=$(sed -n 's/^tart run task-99 --dir=probe://p' "$FAKE/calls")
pgrep -f "$D/bin/nc -k -l" >/dev/null || fail "no listener running before the interrupt"
[ -d "$shared" ] || fail "no shared folder before the interrupt"
kill -TERM "$atk"
wait "$atk" 2>/dev/null || true
wait_for 5 no_vm task-99 || fail "an interrupted known-bad left task-99"
[ ! -e "$shared" ] || fail "an interrupted known-bad left its shared folder"
pgrep -f "$D/bin/nc -k -l" >/dev/null && fail "an interrupted known-bad left a listener"
ok "apple-vm-host-script AC-11: an interrupted known-bad deletes task-99, its folder and listeners"

# ---- apple-vm-probe.sh, in a fake guest ----

new_env
G="$T/guest"
mkdir -p "$G/Volumes" "$G/Users/admin" "$G/Users/Shared" "$G/Library/LaunchDaemons"
ln -s / "$G/Volumes/Macintosh HD"
probe() { PROBE_ROOT="$G" PATH="$D/bin:$PATH" bash "$T/repo/mac/apple-vm-probe.sh" "$@"; }
[ "$(probe host-path | awk '{ print $3 }')" = blocked ] || fail "host-path: the guest's own disk counted as shared"
mkdir "$G/Volumes/My Shared Files"
[ "$(probe host-path | awk '{ print $3 }')" = reached ] || fail "host-path missed a shared volume"
rmdir "$G/Volumes/My Shared Files"
echo "probe on /Volumes/x (virtiofs, local)" >"$FAKE/mounts"
[ "$(probe host-path | awk '{ print $3 }')" = reached ] || fail "host-path missed a virtiofs mount"
rm "$FAKE/mounts"
[ "$(probe connect mac 192.0.2.99:5 | awk '{ print $3 }')" = blocked ] || fail "connect: a closed port counted as reached"
[ "$(probe connect mac 192.0.2.99:5 192.0.2.10:7 | awk '{ print $3 }')" = reached ] || fail "connect missed an open port"
echo other >"$FAKE/guest-clipboard"
[ "$(probe clipboard w0rd | awk '{ print $3 }')" = blocked ] || fail "clipboard: another word counted"
echo w0rd >"$FAKE/guest-clipboard"
[ "$(probe clipboard w0rd | awk '{ print $3 }')" = reached ] || fail "clipboard missed the word"
[ "$(probe persist-check w0rd | awk '{ print $3 }')" = blocked ] || fail "persist-check found markers in a fresh guest"
[ "$(probe persist-write w0rd | awk '{ print $3 }')" = value ] || fail "persist-write failed"
[ "$(probe persist-check w0rd | awk '{ print $3 }')" = reached ] || fail "persist-check missed its markers"
[ "$(probe cpu-mem-info)" = "PROBE cpu-mem-info value 4 8589934592" ] || fail "cpu-mem-info: $(probe cpu-mem-info)"
echo 192.168.64.1 >"$FAKE/gateway"
[ "$(probe gateway)" = "PROBE gateway value 192.168.64.1" ] || fail "gateway: $(probe gateway)"
[ "$(probe nonsense | awk '{ print $3 }')" = error ] || fail "an unknown probe didn't report an error"
ok "apple-vm-host-script AC-10: the probe tells a held wall from a broken one in a fake guest"

# ---- macOS's bash 3.2 ----

bash4=$(grep -nE 'declare -A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)|declare -n|local -n|\[\[ -v|\|&|&>>|coproc|wait -n|\$\{[^}]*@[QEPAKa]\}|;&|EPOCHSECONDS|\[-[0-9]+\]|setsid' \
  "$mac_dir"/apple-vm.sh "$mac_dir"/apple-vm-attacks.sh "$mac_dir"/apple-vm-probe.sh || true)
[ -z "$bash4" ] || fail "a feature macOS's bash 3.2 lacks: $bash4"
probe_bad=$(mktemp)
printf '#!/bin/bash\ndeclare -A x\n' >"$probe_bad"
grep -qE 'declare -A' "$probe_bad" || fail "the bash 3.2 check can't see declare -A"
rm -f "$probe_bad"
ok "apple-vm-host-script AC-14: no bash-4 feature in the scripts or the probe"
