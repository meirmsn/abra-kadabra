# The VM lane on the local Mac

Scripts the owner runs on the local Mac, never in a cloud session or a project (R-24,
[spec](../specs/apple-vm-host-script.md); the design: [the Apple proposal](../kit/notes/revamp/apple-native-proposal.md)
§ 4, D-20). The agent only ever works inside a throwaway macOS VM; these scripts start, list and
stop those VMs, and attack them from inside to show the walls hold.

| Script                                       | What                                                                                                        |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [`apple-vm.sh`](apple-vm.sh)                 | `start <n>`, `list`, `stop <n>` (stops and deletes), `kill-all`; VMs are `task-1` to `task-98`              |
| [`apple-vm-attacks.sh`](apple-vm-attacks.sh) | `run`: the attacks from inside a VM, a report of `PASS`/`FAIL` lines; `known-bad`: the same on an unsafe VM |
| [`apple-vm-probe.sh`](apple-vm-probe.sh)     | What the attack run sends into the VM with `tart exec`; one `PROBE` line per probe                          |

Tests: [`tests/apple-vm.test.sh`](../tests/apple-vm.test.sh) (a fake Tart; runs on Linux in CI and
on the Mac, for macOS's bash 3.2) and [`tests/apple-vm-mutants.test.sh`](../tests/apple-vm-mutants.test.sh).

## The walls a task VM gets

- **Network:** softnet (`--net-softnet-block=@host`). Softnet alone blocks the LAN and the Mac's
  LAN address but lets a VM reach the Mac itself through softnet's gateway, on every port (softnet
  0.21.1's `lib/proxy/vm.rs`); `@host` closes that. The VM still reaches the internet until the
  egress proxy (R-27). Since `@host` also blocks the Mac's DNS, `start` sets the guest's DNS to
  Cloudflare (`1.1.1.1`, `1.0.0.1`): a default, not a wall.
- **No clipboard, no shared folder.** 4 CPU, 8 GB. At most two VMs on the Mac, counted from every
  VM that runs, whatever started it.
- **Time and disk:** each VM has a supervisor (a small process that lives only as long as its VM;
  nothing runs on the Mac without a VM). It deletes the VM after its time limit (12 h by default,
  `--hours 1` to `24`). Every 10 seconds it reads the Mac's free space: once that has fallen 60 GB
  since the VM started, or is under 30 GB, it stops the VM and keeps it until its time limit; under
  15 GB it deletes it. `start` needs 60 GB free. GB here is 1024³ bytes, as `df -k` counts.
- **What `start` checks first:** Tart is 2.34.0, softnet is owned by root with its setuid bit (it
  prints the one command if not), `base` exists, the name is free. It never touches `base`.

## The owner's steps (R-24's evidence)

Type these in the Mac's own Terminal, where copy and paste work. `<dir>` is the folder with
`bin/tart`, `bin/softnet` and `tart-home/` from the test on the Air.

1. Get this repo at the PR's commit, in a folder outside any synced or backed-up folder:
   `git clone <this repository's https URL> devshop-r24`, then
   `cd devshop-r24 && git checkout <the PR's head commit>`
2. Run the tests here, under macOS's own bash: `bash tests/apple-vm.test.sh`. The last line starts
   `ok - apple-vm-host-script AC-14`.
3. Name the Tart folder once in this Terminal: `D=<dir>`
4. Try one VM: `mac/apple-vm.sh start 1 --tart-dir "$D"` (a VM window opens; the command returns
   once the VM answers), then `mac/apple-vm.sh list --tart-dir "$D"`, then
   `mac/apple-vm.sh stop 1 --tart-dir "$D"`.
5. The attack run, with the disk attack (about half an hour; VM windows open and close):
   `mac/apple-vm-attacks.sh run --tart-dir "$D" --report ~/Desktop/r24-run.txt --disk-fill`
   - It listens on one random port on the Mac's LAN address and on softnet's gateway for at most
     60 seconds, with macOS's own `nc`, serving nothing, so it can tell a held wall from a closed
     port. It also asks the router one port from the Mac.
   - It puts a random word on the Mac's clipboard and puts your clipboard's text back after.
   - The disk attack writes until the VM is stopped for disk; the Mac's free space falls by about
     60 GB for a moment and comes back when the VM is deleted.
6. The known-bad run (a VM with the clipboard on, a temporary folder shared in and Tart's default
   network, deleted at the end): `mac/apple-vm-attacks.sh known-bad --tart-dir "$D" --report ~/Desktop/r24-known-bad.txt`.
   Every line must be `FAIL`: that proves the attacks can see a broken wall.
7. Time Machine's local snapshots can keep a deleted VM's space for about a day:
   `tmutil listlocalsnapshots /`
8. Paste back into the session: the last lines of step 2, both reports
   (`cat ~/Desktop/r24-run.txt ~/Desktop/r24-known-bad.txt`), and step 7's output.

If anything is left behind: `mac/apple-vm.sh kill-all --tart-dir "$D"`, and
`mac/apple-vm.sh stop 99 --tart-dir "$D"` for the known-bad VM.
