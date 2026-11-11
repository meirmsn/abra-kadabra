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
real Mac, that from inside a VM the agent can't read a host path, reach the Mac or the LAN, use the
clipboard, leave anything for the next task, change `base`, fill the Mac's disk, or use more than
its CPU and memory. The proxy (R-27), the standard user and the login (R-28) and the session in the
VM (R-29) come later; until R-27 and R-28 ship, no token or login goes into a VM.

**A gap this slice closes.** Softnet 0.21.1 lets a VM reach the softnet gateway, which is the local
Mac itself, on every port, unless a rule says otherwise (`lib/proxy/vm.rs`, `allowed_from_vm_ipv4`:
"allow communication with the host, otherwise things like SSH to a VM won't work"). The owner's
test probed the Mac's LAN address, which softnet does block, so its "Mac blocked" held only there;
any service on the Mac listening on all its addresses was reachable from the VM. The proposal's
§ 4 and § 5 and the test's record are corrected in this change.

## Decisions

- **Where the scripts live: a new top-level `mac/`** (`mac/apple-vm.sh`, `mac/apple-vm-attacks.sh`,
  `mac/README.md`): they run only on the local Mac, by the owner, never in a cloud session or a
  project, which `install/` (the cloud install) and `runtime/` (what reaches project sessions) both
  are. Rejected: `install/apple-vm/` (blurs the cloud install), `runtime/stacks/apple/` (D-20 item
  10 holds that home back) (Claude's proposal, 2026-11-11; the owner confirms at the go).
- **The Mac is blocked too:** every task VM runs with `--net-softnet-block=@host`, so it can't reach
  the softnet gateway at all. Softnet checks such a rule before its DNS exception, so the VM then
  can't use the Mac's DNS either: `start` sets the guest's DNS servers to a public resolver
  through `tart exec` once the VM answers. Rejected: leaving the gateway open until R-27 (every VM
  until then could reach the Mac's services) (Claude, 2026-11-11, from the spec's review).
- **The resolver: Cloudflare, `1.1.1.1` and `1.0.0.1`, unfiltered, IPv4 only** (softnet passes no
  IPv6). The owner: "I would say Cloudflare. We're using them for the backend anyway, but maybe the
  adversarial review raises good points of how to pick A or B." and, after a review of the
  options, "A" (2026-11-11). It is a default, not a wall: until R-27 the VM reaches any public
  address, so code in it can use any resolver. In R-27 the VM should get no resolver at all, the
  proxy resolving names, since a resolver the VM can reach is a path for data past the proxy.
  Rejected: Quad9 (equal; its policy page couldn't be read from here), a filtering resolver (a
  false block on a package host looks like an outage), the router (all its ports opened), Google
  (keeps the most).
- **No daemon on the Mac:** `start` runs each VM under a supervisor process, detached with `nohup`,
  that lives only as long as that VM, and stops and deletes it at its time limit. Each VM has a state
  file (`<tart-dir>/apple-vm/task-<n>`: its deadline, a random nonce, the supervisor's process id);
  the supervisor deletes only a VM whose state file still holds its nonce, and `stop` ends the
  supervisor first. Every `apple-vm.sh` command also deletes any task VM past its deadline, or not
  running with no live supervisor (a closed Terminal, a crash, a restart), printing one line per VM
  before it deletes it; it doesn't pause. Rejected: a launchd watchdog, something of the devshop's
  running on the Mac all the time (proposal § 4) (Claude, 2026-11-11, from the split's review).
- **`stop` deletes:** a task VM is throwaway, so stopping it also deletes it; work survives only
  as what was pushed. Rejected: a separate `delete` (Claude, 2026-11-11).
- **The time limit:** 12 hours by default, `--hours 1` to `24` (Claude's proposal; the owner
  confirms at the go).
- **The Tart folder is an argument:** `--tart-dir <dir>` (`bin/` with the `tart` wrapper and
  softnet, `tart-home/`); the scripts set `PATH` and `TART_HOME` from it. Rejected: a config file
  (Claude, 2026-11-11).
- **Pinned to Tart 2.34.0,** whose flags and `tart exec` were read from its source; a newer pin is
  its own change. `start` also refuses a `bin/softnet` that isn't owned by root with its setuid bit
  set, printing the one command the owner ran once on 2026-11-09, because Tart asks for that
  password only in an interactive Terminal and the supervisor has none. That setuid-root softnet is
  a change to the Mac, already made, and the only one (Claude, 2026-11-11).
- **The attacks run from the Mac, not typed in the VM:** `apple-vm-attacks.sh` waits until the VM's
  guest agent answers `tart exec` (Cirrus' images include it), sends a probe script in, and writes
  the report on the Mac, so the owner copies it from the Mac's own Terminal (Claude, 2026-11-11).
- **A known-bad run proves the attacks can fail:** `apple-vm-attacks.sh known-bad` runs `task-99`
  the unsafe way (Tart's default network, the clipboard on, an empty temporary folder shared in) and
  the same probes, which must then report each wall broken. `task-99` is reserved for it:
  `apple-vm.sh start` refuses 99, while `stop`, `kill-all` and the clean-up cover it like any task
  VM. `apple-vm.sh` itself has no unsafe mode (Claude, 2026-11-11).
- **Positive controls:** a probe to a port nothing listens on fails with or without a wall. So the
  attack run listens with macOS's own `/usr/bin/nc` on one random port, bound only to the Mac's LAN
  address and to the softnet gateway, for at most 60 seconds, and first checks from the Mac itself
  that the listener answers on both (else the line is `FAIL`). The VM then tries to reach that port
  on both addresses, and the router on its DNS port; the known-bad run shows the same probes
  succeeding. The clipboard probe puts a random word on the Mac's clipboard and reads the guest's
  (Claude, 2026-11-11).
- **The disk-fill attack is opt-in** (`--disk-fill`): it deletes at least 20 GB of files the image
  holds, then writes until the guest disk is full, so the copy-on-write clone grows past what
  `base` already holds; it takes minutes and runs once for this slice's evidence (Claude's
  proposal; the owner confirms at the go).
- **Disk: a start margin and a checked floor** (the owner, after a review of the options: "A",
  2026-11-11; on the Mac's disk: "He has 1 terabyte, but we shouldn't bank on that."). A
  copy-on-write clone can grow up to its whole 140 GB, and a guest that hits a full host disk gets
  I/O errors, so:
  - `start` refuses with less than 60 GB free (`df -k`, which leaves out purgeable space).
  - Every 10 seconds the supervisor reads the Mac's free space and the VM's disk image's allocated
    size. When the VM has grown past 60 GB or the Mac has under 30 GB free, it stops the VM and
    keeps it (shown in `list` as stopped for disk) until its deadline or a `stop`; under 15 GB free
    it deletes it. Each trip is a printed and logged line.
  - This is feedback, not a wall: it works while the supervisor runs, and `list` flags a VM without
    one. Rejected for now: a separate APFS volume with a quota for `tart-home` (a real wall, but a
    move of 163 GB and untested here), a fixed 300 GB start bar (blocks work as the owner's own
    files grow, and bounds nothing once running), an event instead of the check (macOS has no
    public early low-space event). Later, R-28's recipe can give task VMs a smaller disk, which
    shrinks the worst case itself.
- **The CPU and memory attack, with one VM up:** the guest must see 4 CPUs and 8 GB; then it loads
  every core and allocates memory past 8 GB while the Mac samples the VM's process (Virtualization's
  `com.apple.Virtualization.VirtualMachine` process, not `tart`). The report records the peaks and
  the Mac's memory pressure. The pass line: the peaks show the load was seen (at least 3 cores, at
  least 6 GB) and stayed bounded (at most 4 cores plus 10 %, at most 8 GB plus 2 GB of overhead).
  The first real run may show the overhead needs another value, which the owner decides (Claude,
  2026-11-11).
- **The two-VM cap counts every VM on the Mac,** from the Virtualization processes running, not only
  Tart's list in this folder (Claude, 2026-11-11).
- **The report proves what ran:** the attack run refuses a checkout with uncommitted changes and
  records the commit, each script's and the probe's SHA-256, and the raw output of `tart --version`,
  `sw_vers` and `tart list --format json`; the Linux fakes are checked against that raw output
  after the first real run (Claude, 2026-11-11).
- **`base` pinned by digest moves to R-28,** the slice that builds `base` from a recipe; this slice
  only refuses to touch `base` and checks it is unchanged. This changes the split's notes, which put
  it in R-24 (Claude's proposal; the owner confirms at the go).
- **macOS's own bash:** both scripts and the probe run under macOS's `/bin/bash` 3.2; the proof is
  the owner's run of the Linux test on the Mac (AC-16), since macOS's bash and BSD tools are not on
  the Linux CI runner (Claude, 2026-11-11).

## Acceptance items

- **AC-1** `mac/apple-vm.sh start <n> --tart-dir <dir> [--hours <h>]` clones `base` to `task-<n>`,
  sets it to 4 CPU and 8192 MB, and runs it with `--net-softnet-block=@host --no-clipboard` and no
  `--dir`, under the supervisor of Decisions; once `tart exec` answers in the VM, it sets the
  guest's DNS servers to `1.1.1.1` and `1.0.0.1`; it exits 0 only when both are done within 300
  seconds, and otherwise stops and deletes the VM and exits non-zero.
- **AC-2** `mac/apple-vm.sh list --tart-dir <dir>` prints one line per `task-<n>` VM: its name,
  whether it runs, its age, the time left before its deadline, and its size on the Mac; VMs not
  named `task-<n>` are not listed.
- **AC-3** `mac/apple-vm.sh stop <n> --tart-dir <dir>` ends `task-<n>`'s supervisor, stops the VM,
  waits until Tart no longer lists it as running, then deletes it and its state file;
  `mac/apple-vm.sh kill-all --tart-dir <dir>` does the same for every `task-<n>` VM, and for no
  other VM.
- **AC-4** Every `apple-vm.sh` command first deletes each `task-<n>` VM past its deadline, or not
  running with no live supervisor, printing its name before it does; a supervisor deletes its VM at
  the deadline only while the VM's state file holds its nonce, so a `stop` then a new `start` of
  the same `<n>` is never deleted by the old supervisor. A VM the supervisor stopped for disk is
  kept until its deadline and listed as such.
- **AC-5** The supervisor applies the disk rule of Decisions every 10 seconds: it stops the VM
  past 60 GB of growth or under 30 GB free on the Mac, deletes it under 15 GB free, and prints and
  logs each trip.
- **AC-6** No command ever passes `base`, or any VM name not of the form `task-<n>`, to `tart stop`,
  `tart delete`, `tart set`, `tart run` or `tart exec`; `<n>` is a whole number from 1 to 99 (`start`
  takes 1 to 98), and anything else (`0`, `100`, `-1`, `1;x`, `../base`, `base`, empty) exits 2
  with a usage line and calls no `tart` command.
- **AC-7** `start` refuses (exit 1, calling neither `tart clone` nor `tart run`) when: `task-<n>`
  already exists; `base` doesn't exist; two VMs already run on the Mac (counted from the
  Virtualization processes, whatever made them); the Mac's free space is below the rule in
  Decisions; `tart --version` isn't `2.34.0`; or `bin/softnet` isn't owned by root with its setuid
  bit, in which case it prints the command that fixes it.
- **AC-8** Each command exits 2 with a usage line on an unknown command, a missing or extra
  argument, a missing `--tart-dir`, a `--tart-dir` without an executable `bin/tart`, or `--hours`
  outside 1 to 24; a missing tool, or an output the script can't parse, exits non-zero, never 0.
- **AC-9** `mac/apple-vm-attacks.sh run --tart-dir <dir> --report <file> [--disk-fill]` refuses a
  checkout with uncommitted changes; starts its own task VMs through `apple-vm.sh`, one at a time;
  waits up to 300 seconds for `tart exec` to answer; runs each attack below; and writes the report:
  the header of Decisions, then one line per attack, `PASS <id> <detail>` when the wall held and
  `FAIL <id> <detail>` otherwise. It exits 0 only when every line is `PASS`. A probe that can't
  run, or whose output it can't parse, is a `FAIL`. On any exit, an interrupt included, it deletes
  the VMs it started and ends its listener.
- **AC-10** The attacks, each a report line:
  - `host-path`: no `virtiofs`, `smbfs`, `nfs` or `afpfs` volume is mounted, and nothing but the
    guest's own disk is under `/Volumes`.
  - `mac`: the Mac first reaches its own listener on both addresses, then the VM can reach it on
    neither.
  - `lan`: the VM can't reach the router's DNS port.
  - `clipboard`: the word put on the Mac's clipboard is not on the guest's.
  - `persist`: markers written in one task VM (in `/Users/admin`, in `/Users/Shared`, and a
    LaunchDaemon in `/Library/LaunchDaemons`) are absent in the next.
  - `base`: `base`'s `config.json` and `nvram.bin` hash the same, and its disk image has the same
    size and modification time, before and after the run.
  - `cpu-mem`: the guest sees 4 CPUs and 8 GB, and the peaks the Mac samples are within the pass
    line of Decisions.
  - `disk`, with `--disk-fill`: the guest frees at least 20 GB and writes until it is stopped; the
    supervisor stops it for disk, and the Mac's free space never falls below 15 GB.
- **AC-11** `mac/apple-vm-attacks.sh known-bad --tart-dir <dir> --report <file>` starts `task-99`
  with Tart's default network, the clipboard on and an empty temporary folder shared in, runs the
  `host-path`, `mac`, `lan`, `clipboard` and `persist` probes (`persist` on that same VM, without
  deleting it in between), deletes the VM, and exits 0 only when every one of those lines is
  `FAIL`.
- **AC-12** `tests/apple-vm.test.sh` runs both scripts against a fake `tart` (and fake `ps`, `df`,
  `stat`, `date`, `ipconfig`, `route`, `nc`, `pbcopy` and `git` as needed) in a temporary
  `--tart-dir`, and covers each item AC-1 to AC-11 with a known-bad input, among them: every bad
  `<n>` of AC-6, each refusal of AC-7, a VM past its deadline, a stopped VM with no supervisor, a
  stale supervisor after a restart of the same `<n>`, a `tart exec` that never answers, a `base`
  the fake changes, a listener that never answers, a probe output with a missing line, a probe
  that reports a wall broken, a cpu-mem sample below the lower bound, each disk trip (growth, low free space, very low free
  space), a dirty checkout, an
  interrupted run (nothing left behind), and a fake `tart` that prints nothing.
- **AC-13** A mutant run, `tests/apple-vm-mutants.test.sh`, removes or inverts each guard of AC-6
  and AC-7, each pass condition of AC-9 to AC-11, the nonce check of AC-4 and each disk threshold
  of AC-5 in a temporary copy, and the test of AC-12 fails on every mutant.
- **AC-14** Neither script nor the probe uses a feature macOS's bash 3.2 lacks (`declare -A`,
  `mapfile`, `readarray`, `${x,,}`, `${x^^}`, `declare -n`, `local -n`, `[[ -v`, `|&`, `&>>`,
  `coproc`, `wait -n`, `${x@`, `;&`, `$EPOCHSECONDS`, a negative array index, `setsid`), checked by a
  test; the scripts, the probe and the test pass `shellcheck`.
- **AC-15** `mac/README.md` gives the owner's steps on the local Mac as commands to copy from the
  Mac's own Terminal: get this repo at the PR's commit, run `tests/apple-vm.test.sh`, the start,
  list and stop commands, the attack run, the known-bad run, the Time Machine check (`tmutil listlocalsnapshots /`: local
  snapshots can keep a deleted VM's space for about a day), and what to paste back; it says what
  softnet allows and what this slice adds; `docs/README.md` links it.
- **AC-16** On the local Mac, at the PR's head commit: `tests/apple-vm.test.sh` passes;
  `apple-vm-attacks.sh run --disk-fill` reports `PASS` on every line; and
  `apple-vm-attacks.sh known-bad` reports `FAIL` on every line. The three outputs are in the PR's
  Evidence — verified by review: the owner's outputs, pasted from the Mac.
- **AC-17** The proposal's § 4 and § 5 and the test's record (`spikes/m4-apple-vm/README.md`,
  `air-test.md`) say that softnet alone leaves the Mac reachable through its gateway and that task
  VMs block it with `@host`.

## Out of scope

- The egress allowlist proxy, softnet's block-all rule and the attack on a host off the list
  (R-27). Until then the VM reaches the internet through softnet's defaults.
- The base image recipe, `base` pinned by digest, a smaller disk for task VMs, the standard `agent`
  user, the login, the managed settings and their attacks (R-28).
- Remote Control, a session in the VM, `ship.sh` and the reviewer from a VM (R-29).
- Apple's Xcode plugin (D-20 item 11), the Apple stack home (D-20 item 10), and any change to the
  local Mac outside Tart, softnet's setuid bit (already set) and these two scripts.
