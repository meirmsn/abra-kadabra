# The VM lane's host script and its first attacks

**Go:** pending

## Intent

R-24, the first slice of the VM lane (the Apple proposal's phase 2, split on 2026-11-11 into R-24,
R-27, R-28 and R-29; [ROADMAP.md](../ROADMAP.md#the-split-of-the-vm-lane)). The owner asked to start
building native Apple apps ("setting up to startbuilding [the first Apple app] and in parallel do
[the pilot web app's] ios?") and approved this slice first ("A", 2026-11-11). D-20 item 1: the agent
only ever works inside a throwaway macOS VM on the local Mac.

This slice gives the owner one tested command on the local Mac to start, list, stop and delete
those VMs, and a second one that attacks a VM from inside and writes a report. It shows, on the
real Mac, that from inside a VM the agent can't read a host path, reach the Mac or the LAN, leave
anything for the next task, change `base`, fill the Mac's disk, or use more than its CPU and
memory. The proxy (R-27), the standard user and the login (R-28) and the session in the VM (R-29)
come later; until R-27 and R-28 ship, no token or login goes into a VM.

## Decisions

- **Where the scripts live: a new top-level `mac/`** (`mac/apple-vm.sh`, `mac/apple-vm-attacks.sh`,
  `mac/README.md`): they run only on the local Mac, by the owner, never in a cloud session or a
  project, which `install/` (the cloud install) and `runtime/` (what reaches project sessions) both
  are. They move to the Apple stack home if it ever needs them (D-20 item 10); rejected:
  `install/apple-vm/` (blurs the cloud install), `runtime/stacks/apple/` (D-20 item 10 holds that
  home back) (Claude's proposal, 2026-11-11; the owner confirms at the go).
- **No daemon on the Mac:** `start` runs each VM under a small supervisor process that lives only
  as long as that VM and stops and deletes it at its time limit; every `apple-vm.sh` command also
  deletes task VMs past their limit (for a Mac that slept or restarted). Rejected: a launchd
  watchdog, something of the devshop's running on the Mac all the time (proposal § 4: the Mac runs
  "Tart and the host script, nothing else") (Claude, 2026-11-11, from the split's review).
- **`stop` deletes:** a task VM is throwaway, so stopping it also deletes it; work survives only
  as what was pushed. Rejected: a separate `delete`, one more command and a VM left behind
  (Claude, 2026-11-11).
- **The time limit:** 12 hours by default, `--hours 1` to `24` (Claude's proposal; the owner
  confirms at the go).
- **The Tart folder is an argument:** `--tart-dir <dir>`, the folder the owner set up by hand
  (`bin/` with the `tart` wrapper and softnet, `tart-home/`); the scripts set `PATH` and
  `TART_HOME` from it, so they don't depend on a Terminal's exports. Rejected: a config file
  (one more hidden state) (Claude, 2026-11-11).
- **Pinned to Tart 2.34.0:** the scripts refuse any other `tart --version`, since their flags and
  `tart exec` were read from 2.34.0's source; a newer pin is its own change (Claude, 2026-11-11).
- **The attacks run from the Mac, not typed in the VM:** `apple-vm-attacks.sh` sends a probe
  script into the VM with `tart exec` (Tart 2.34.0 has it; it needs Tart's guest agent, which
  Cirrus' images include) and writes the report on the Mac, so the owner copies the report from
  the Mac's own Terminal into the session (Claude, 2026-11-11, from the split's review).
- **A known-bad run proves the attacks can fail:** `apple-vm-attacks.sh known-bad` starts a VM the
  unsafe way (Tart's default network, the clipboard on, an empty temporary folder shared in) and
  runs the same probes, which must then report the walls as broken; `apple-vm.sh` itself has no
  unsafe mode (Claude, 2026-11-11).
- **The Mac and LAN probes have a positive control:** a probe to a port nothing listens on fails
  with or without a wall, so the attack run listens on one random port on the Mac for the few
  seconds of the probes (serving nothing) and the VM tries to reach that port on the Mac's LAN
  address and on softnet's gateway, and the router on its DNS port. The known-bad run shows the
  same probes succeeding (Claude, 2026-11-11).
- **The disk-fill attack is opt-in** (`--disk-fill`): it writes until the guest disk is full,
  about 53 GB on the owner's `base`, and takes minutes; it runs once for this slice's evidence
  (Claude's proposal; the owner confirms at the go).
- **Free disk at `start`:** a task VM can grow on the Mac up to its disk's size minus what `base`
  already holds there, so `start` refuses unless the Mac's free space covers that growth for every
  running task VM plus the new one, plus a 20 GB floor (Claude, 2026-11-11).
- **The CPU and memory attack records numbers:** the VM is set to 4 CPU and 8 GB, and the attack
  shows the guest sees no more, then loads it (busy loops on every core, memory past 8 GB) while
  the Mac samples the VM's process; the report records the peaks and the Mac's memory pressure.
  The pass line is a peak CPU of at most 4 cores plus 10 % and a peak memory of at most 8 GB plus
  2 GB of overhead; the first real run may show the overhead needs another value, which the owner
  decides (Claude, 2026-11-11).
- **`base` pinned by digest moves to R-28,** the slice that builds `base` from a recipe; this slice
  only refuses to touch `base` and checks it is unchanged (Claude, 2026-11-11, a change to the
  split's notes).
- **macOS's own bash:** both scripts and the probe run under macOS's `/bin/bash` 3.2 (Claude,
  2026-11-11).

## Acceptance items

- **AC-1** `mac/apple-vm.sh start <n> --tart-dir <dir> [--hours <h>]` clones `base` to `task-<n>`,
  sets it to 4 CPU and 8192 MB, and runs it with `--net-softnet --no-clipboard` and no `--dir`,
  under a supervisor that stops and deletes it when its time limit passes; it returns once Tart
  lists the VM as running, and exits non-zero if that doesn't happen within 120 seconds.
- **AC-2** `mac/apple-vm.sh list --tart-dir <dir>` prints one line per `task-<n>` VM: its name,
  whether it runs, its age, the time left before its limit, and its size on the Mac; VMs not named
  `task-<n>` are not listed.
- **AC-3** `mac/apple-vm.sh stop <n> --tart-dir <dir>` stops `task-<n>`, waits until Tart no longer
  lists it as running, then deletes it; `mac/apple-vm.sh kill-all --tart-dir <dir>` does the same
  for every `task-<n>` VM, and for no other VM.
- **AC-4** Every `apple-vm.sh` command first deletes each `task-<n>` VM past its time limit,
  printing its name before it does.
- **AC-5** No command ever passes `base`, or any VM name not of the form `task-<n>`, to `tart stop`,
  `tart delete`, `tart set` or `tart run`; `<n>` is a whole number from 1 to 99, and anything else
  (`0`, `100`, `-1`, `1;x`, `../base`, `base`, empty) exits 2 with a usage line and calls no `tart`
  command.
- **AC-6** `start` refuses (exit 1, calling neither `tart clone` nor `tart run`) when: `task-<n>`
  already exists; `base` doesn't exist; two macOS VMs already run (whatever their names); the Mac's
  free space is below the rule in Decisions; or `tart --version` isn't `2.34.0`.
- **AC-7** Each command exits 2 with a usage line on an unknown command, a missing or extra
  argument, a missing `--tart-dir`, a `--tart-dir` without an executable `bin/tart`, or `--hours`
  outside 1 to 24; a missing `tart` or a `tart` output the script can't parse exits non-zero, never 0.
- **AC-8** `mac/apple-vm-attacks.sh run --tart-dir <dir> --report <file> [--disk-fill]` starts its
  own task VMs through `apple-vm.sh`, runs each attack below, deletes the VMs it started, and
  writes the report: a header (date, the Mac's macOS version, `tart --version`, the repo's commit)
  and one line per attack, `PASS <id> <detail>` when the wall held and `FAIL <id> <detail>`
  otherwise; it exits 0 only when every line is `PASS`. A probe that can't run, or whose output it
  can't parse, is a `FAIL`.
- **AC-9** The attacks, each a report line: `host-path` (no shared folder is mounted, nothing of
  the Mac's is under `/Volumes`); `mac` (the VM can't connect to the run's listening port on the
  Mac's LAN address or softnet's gateway); `lan` (the VM can't reach the router's DNS port);
  `persist` (marker files in the home folder and `/Users/Shared`, and a LaunchAgent, written in one
  task VM are absent in the next); `base` (`base`'s `config.json` and `nvram.bin` hash the same,
  and its disk image has the same size and modification time, before and after); `cpu-mem` (the
  guest sees 4 CPUs and 8 GB, and the Mac's peaks under load are within Decisions' pass line); and,
  with `--disk-fill`, `disk` (the guest fills its disk and the Mac's free space stays above the
  20 GB floor).
- **AC-10** `mac/apple-vm-attacks.sh known-bad --tart-dir <dir> --report <file>` starts one VM with
  Tart's default network, the clipboard on and an empty temporary folder shared in, runs the
  `host-path`, `mac`, `lan` and `persist` probes (the last on that same VM, without deleting it),
  deletes the VM, and exits 0 only when every one of those lines is `FAIL`.
- **AC-11** `tests/apple-vm.test.sh` runs both scripts on Linux against a fake `tart` (and fake
  `df`, `du`, `date`, `ipconfig` and `route`) placed in a temporary `--tart-dir`, and covers each
  item AC-1 to AC-10 with a known-bad input, among them: every bad `<n>` of AC-5, each refusal of
  AC-6, a VM past its limit, a `base` the fake changes, a probe output with a missing line, a
  probe that reports a wall broken, and a fake `tart` that prints nothing.
- **AC-12** A mutant run, `tests/apple-vm-mutants.test.sh`, removes or inverts each guard of AC-5
  and AC-6 and each pass condition of AC-8 and AC-9 in a temporary copy, and the test of AC-11 fails
  on every mutant.
- **AC-13** Neither script nor the probe uses a feature macOS's bash 3.2 lacks (`declare -A`,
  `mapfile`, `readarray`, `${x,,}`, `${x^^}`, `declare -n`, `local -n`, `[[ -v`, `|&`, `&>>`,
  `coproc`), checked by a test; both pass `shellcheck`.
- **AC-14** `mac/README.md` gives the owner's steps on the local Mac as commands to copy from the
  Mac's own Terminal: get this repo at the PR's commit, the start, list and stop commands, the attack
  run, the known-bad run, and what to paste back; `docs/README.md` links it.
- **AC-15** On the local Mac, `apple-vm-attacks.sh run --disk-fill` reports `PASS` on every line and
  `apple-vm-attacks.sh known-bad` reports `FAIL` on every line; both reports are in the PR's
  Evidence — verified by review: the owner's two reports, pasted from the Mac, at the PR's head
  commit.

## Out of scope

- The egress allowlist proxy and softnet's block-all rule, and the attack on a host off the list
  (R-27). In this slice the VM reaches the internet through softnet's defaults.
- The base image recipe, `base` pinned by digest, the standard `agent` user, the login, the
  managed settings and their attacks (R-28).
- Remote Control, a session in the VM, `ship.sh` and the reviewer from a VM (R-29).
- Apple's Xcode plugin (D-20 item 11), the Apple stack home (D-20 item 10), and any change to the
  local Mac outside Tart and these two scripts.
