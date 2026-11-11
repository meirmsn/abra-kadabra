#!/usr/bin/env bash
# tier: slow
# The mutant run for the VM lane's host scripts (spec specs/apple-vm-host-script.md AC-13): each
# mutation below removes or inverts one guard or pass condition in a temporary copy of mac/, and
# tests/apple-vm.test.sh, run against that copy (APPLE_VM_MAC_DIR), must fail: the mutant is killed.
# A mutation whose text is no longer in the scripts fails too, so the list follows the code.
# apple-vm-host-script AC-13
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$repo_root" "$work" <<'PY'
import concurrent.futures, os, shutil, subprocess, sys

root, work = sys.argv[1], sys.argv[2]
V, A, P = "apple-vm.sh", "apple-vm-attacks.sh", "apple-vm-probe.sh"
MUTANTS = [
    # AC-6: names and numbers
    ("AC-6 valid_n accepts anything", V, "  case $1 in '' | 0* | *[!0-9]*) return 1 ;; esac\n", ""),
    ("AC-6 any name is a task name", V, "case $1 in task-*) valid_n \"${1#task-}\" 99 ;; *) return 1 ;; esac", "return 0"),
    ("AC-6 start takes 99", V, 'valid_n "$n" 98 ||', 'valid_n "$n" 99 ||'),
    # AC-7: start's refusals
    ("AC-7 no base check", V, 'vm_exists base || refuse', 'true || refuse'),
    ("AC-7 no exists check", V, '! vm_exists "$name" || refuse', 'true || refuse'),
    ("AC-7 three VMs allowed", V, '[ "$count" -lt 2 ]', '[ "$count" -lt 3 ]'),
    ("AC-7 50 GB to start", V, "START_FREE_GB=60", "START_FREE_GB=50"),
    ("AC-7 any tart version", V, '[ "$v" = "$TART_PIN" ] ||', 'true ||'),
    ("AC-7 softnet setuid unchecked", V, 'if [ "$uid" -ne 0 ] || [ $((8#$mode & 2048)) -eq 0 ]; then', 'if [ "$uid" -ne 0 ]; then'),
    ("AC-7 softnet owner unchecked", V, 'if [ "$uid" -ne 0 ] || [ $((8#$mode & 2048)) -eq 0 ]; then', 'if [ $((8#$mode & 2048)) -eq 0 ]; then'),
    # AC-4 and AC-5: the supervisor
    ("AC-4 no nonce check", V, '  [ "$(state_get "$name" nonce || true)" = "$nonce" ] || return 1\n', ""),
    ("AC-4 sweep keeps orphans", V, 'elif ! vm_running "$v" && ! supervisor_alive "$v"; then', 'elif false; then'),
    ("AC-5 growth cap 70 GB", V, "MAX_GROWTH_GB=60", "MAX_GROWTH_GB=70"),
    ("AC-5 stop floor 20 GB", V, "STOP_FREE_GB=30", "STOP_FREE_GB=20"),
    ("AC-5 delete floor 10 GB", V, "DELETE_FREE_GB=15       #", "DELETE_FREE_GB=10       #"),
    # AC-9 to AC-11: the attack run
    ("AC-9 reached counts as PASS", A, "run:blocked) line PASS", "run:blocked | run:reached) line PASS"),
    ("AC-9 a probe that can't run passes", A, '*) line ERROR "$id"', '*) line PASS "$id"'),
    ("AC-9 dirty checkout allowed", A, '[ -z "$(git -C "$repo" status --porcelain)" ] ||', 'true ||'),
    ("AC-9 no clean-up on exit", A, "trap cleanup EXIT", "trap '' EXIT"),
    ("AC-9 every line counts", A, '[ "$lines" -gt 0 ] && [ "$lines" -eq "$good" ] || exit 1', 'true || exit 1'),
    ("AC-10 no listener control", A, 'if "$NC" -z -G 2 "$mac_lan_ip" "$port" >/dev/null 2>&1 && "$NC" -z -G 2 "$gw" "$port" >/dev/null 2>&1; then', "if true; then"),
    ("AC-10 no lower load bound", A, "c >= 300 && c <= 440 && r >= 6 * g && r <= 10 * g", "c <= 440 && r <= 10 * g"),
    ("AC-10 no upper load bound", A, "c >= 300 && c <= 440 && r >= 6 * g && r <= 10 * g", "c >= 300 && r >= 6 * g"),
    ("AC-10 guest size unchecked", A, '[ "$cpus" -eq 4 ] && [ "$mem" -eq 8589934592 ] &&', ""),
    ("AC-10 base unchecked", A, '[ -n "$before" ] && [ "$before" = "$after" ]', '[ -n "$before" ]'),
    ("AC-10 disk stop unchecked", A, 'if [ "$status" != running ] && [ "$min" -ge', 'if [ "$min" -ge'),
    ("AC-10 probe ignores /Volumes", P, '[ -z "$shared$vols" ] || out reached', '[ -z "$shared" ] || out reached'),
    ("AC-10 probe ignores mounts", P, '[ -z "$shared$vols" ] || out reached', '[ -z "$vols" ] || out reached'),
    ("AC-10 probe never connects", P, 'if nc -z -G 3 -w 3 "$ip" "$port"', "if false"),
    ("AC-10 probe misses markers", P, '[ -f "$f" ] && grep -q -- "$word" "$f" && found=', 'false && found='),
    ("AC-11 known-bad expects PASS", A, '[ "$mode" = run ] || expected=FAIL\n', "\n"),
    ("AC-11 blocked counts as broken", A, "known-bad:reached) line FAIL", "known-bad:reached | known-bad:blocked) line FAIL"),
]


def run(m):
    name, script, old, new = m
    d = os.path.join(work, str(MUTANTS.index(m)))
    shutil.copytree(os.path.join(root, "mac"), d)
    p = os.path.join(d, script)
    src = open(p).read()
    if src.count(old) != 1:
        return name, f"its text is in {script} {src.count(old)} times, not once"
    open(p, "w").write(src.replace(old, new))
    env = dict(os.environ, APPLE_VM_MAC_DIR=d)
    try:
        r = subprocess.run(["bash", os.path.join(root, "tests/apple-vm.test.sh")], env=env,
                           capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        return name, None  # a hang is a failed test: killed
    return name, ("survived: the test passed" if r.returncode == 0 else None)


bad = []
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for name, problem in pool.map(run, MUTANTS):
        if problem:
            bad.append(f"{name}: {problem}")
        else:
            print(f"ok - killed: {name}")
if bad:
    print("FAIL:\n  " + "\n  ".join(bad), file=sys.stderr)
    sys.exit(1)
print(f"ok - apple-vm-host-script AC-13: all {len(MUTANTS)} mutants killed")
PY
