# The one-hour test on the local MacBook Air

A manual test for the owner, kept with the spike: does the design in
[the Apple proposal](../../apple-native-proposal.md) § 4 work on the Air itself? It checks three
things: a throwaway macOS VM there can build and UI-test the spike's app; agent-desktop can drive
the app inside the VM; the VM can't reach the Mac or the home network, and the Mac stays usable.
Nothing here touches the Mac outside Tart and the VM.

Commands were taken on 2026-11-01 (and step 1 updated from the owner's run on 2026-11-09) from Tart's repository README (now under OpenAI) and
agent-desktop's README; they were not run from here. Where a value is marked _check_, look it up
as described and note what you used.

## 0. Before you start (5 min)

- **The Mac:** Apple menu → About This Mac: write down the chip, the memory (16, 24 or 32 GB)
  and the macOS version.
- **Free disk:** at least **200 GB**. On the owner's Air the image folder reached 163 GB: 87 GB for
  `base` on disk (a 140 GB disk, stored sparse) plus Tart's cached download (`tart prune` frees it
  later). The `air-test` copy shares `base`'s disk (copy-on-write), so it starts small and grows
  only with what the test writes.
- **Homebrew** on the Mac: `brew --version`. If it isn't found, install it from brew.sh first.
- **Close heavy apps** so the memory readings mean something.

## 1. Install Tart and get an Xcode image (20–40 min, mostly download)

**On macOS 26 Tahoe:** `brew install openai/tools/tart` (Homebrew may first ask to trust the tap's
`softnet` formula: `brew trust --formula openai/tools/softnet`).

**On macOS 15 Sequoia** (the owner's Air, run 1 on 2026-11-09), that fails: softnet 0.24.0 and later
require macOS 26, and Tart 2.35.0 and later crash at launch on macOS 15 (built with Xcode 27; a Swift
library is missing there). Install the last pair that runs, by hand, into one folder outside any
synced or backed-up folder. `<dir>` below is that folder; the owner used one under `~/dev`.

1. Download both releases from OpenAI's GitHub releases (`openai/softnet` 0.21.1 and `openai/tart`
   2.34.0, each `*.tar.gz`) into `<dir>`, saved as `softnet-0.21.1.tar.gz` and `tart-2.34.0.tar.gz`.
   `shasum -a 256` must print exactly the values from OpenAI's Homebrew formulas for those versions:
   softnet `be1c73d47c5b9ffdba21efbe65b8b640b9d46250ade588ac4950dbce2411aba6`, tart
   `c9f1609f4945258ef0ee277dd44dc9700d6f069789a11e43be7f35b0a64b3135`.
2. Unpack Tart into its own folder (`<dir>/t234`) and softnet into `<dir>/bin`. Start Tart through a
   two-line wrapper script in `<dir>/bin/tart` that `exec`s `<dir>/t234/tart.app/Contents/MacOS/tart`;
   a symlink to the binary doesn't start. Never unpack over an existing `tart.app`: macOS refuses to
   change a signed app from Terminal ("Operation not permitted").
3. Keep the images and VMs in `<dir>` too, and out of Time Machine: set
   `TART_HOME=<dir>/tart-home`, put `<dir>/bin` first on `PATH`, and run `tmutil addexclusion <dir>`.
   `tart --version` prints `2.34.0`.
4. Pick an Xcode image whose macOS is **not newer** than the Air's (a VM can't run a newer macOS than
   its host): on macOS 15, `ghcr.io/cirruslabs/macos-sequoia-xcode:26.6` (66.4 GB compressed, a
   140 GB disk; brief network drops are retried by Tart). Download it once, as the clean copy:
   `tart clone ghcr.io/cirruslabs/macos-sequoia-xcode:26.6 base`. `tart list` then shows `base`.
5. Make the test's throwaway copy, and give it 4 CPU cores and 8 GB of memory:
   `tart clone base air-test`, then `tart set air-test --cpu 4 --memory 8192`

## 2. Start it isolated (2 min)

`tart run air-test --net-softnet --no-clipboard`

A window opens with a Mac inside. `--net-softnet` lets the VM reach the internet but not the home
network, nor the Mac's LAN address; it does let the VM reach the Mac through softnet's gateway, on
every port (found 2026-11-11 in softnet 0.21.1's source; task VMs add `--net-softnet-block=@host`,
`mac/apple-vm.sh`); `--no-clipboard` stops copy and paste between them. Cirrus' images log in on their
own as user `admin` (password `admin`, _check_ if asked). Open Terminal **inside the VM window** for
every command below until step 6.

## 3. Check the walls (5 min)

Each line says what should happen. Write down what did.

| Check                                                                                         | Expect                                       |
| --------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `ls /Volumes` and Finder's sidebar                                                            | No folder from your Mac                      |
| On the Mac, System Settings → Wi-Fi → Details: note the router's IP. In the VM: `ping -c 2 <router IP>` | Fails (no reply)                     |
| On the Mac, note its own IP (same page). In the VM: `curl -m 5 http://<Mac IP>`                 | Fails (no connection)                        |
| In the VM: `curl -sI https://github.com \| head -1`                                           | Succeeds (`HTTP/2 200` or a redirect)        |
| Copy a word on the Mac, paste in the VM's Terminal                                            | Nothing pastes                               |

## 4. Build and UI-test the spike's app inside the VM (15–25 min)

1. `git clone <this devshop repository's https URL> devshop` (the repository is public), then
   `cd devshop/kit/notes/revamp/spikes/m4-apple-vm/app`
2. `brew install xcodegen` and `xcodegen generate`
3. macOS UI test, timed:
   `time xcodebuild test -project Hello.xcodeproj -scheme HelloMac -destination 'platform=macOS' CODE_SIGN_IDENTITY=-`
   Expect `** TEST SUCCEEDED **`. Write down the `real` time.
4. **While it runs, on the Mac:** open Activity Monitor → Memory. Write down the Memory Pressure
   colour (green, yellow, red), the Swap Used, and whether the Mac still feels usable.
5. iOS Simulator UI test (optional, slower): `xcrun simctl list devices available | grep iPhone`,
   take one device's id, then
   `time xcodebuild test -project Hello.xcodeproj -scheme HelloiOS -destination 'id=<device id>' CODE_SIGNING_ALLOWED=NO`

## 5. Drive the app with agent-desktop inside the VM (10 min)

1. `brew install node`, then `npm install -g agent-desktop` and `agent-desktop version`
2. `agent-desktop permissions --guide` and grant Accessibility as it says (inside the VM only).
3. Start the app built in step 4:
   `open "$(find ~/Library/Developer/Xcode/DerivedData -name HelloMac.app -type d | head -1)"`
4. `agent-desktop snapshot --app HelloMac -i`: in the JSON, find the button "Count items" and its
   ref (looks like `@s…:e…`).
5. `agent-desktop click <that ref>`, then the snapshot again: the label should read
   "Items found: 2".

## 6. Optional: let the cloud session in (10 min)

Skip this unless steps 1–5 passed and you want Claude to drive the VM now. It puts a claude.ai login
inside the VM. The VM is deleted in step 7, but the login stays valid until you sign it out.

1. In the VM, install Claude Code (the official installer from the Claude Code docs), sign in, then
   in the project folder: `claude remote-control`. Trust the folder when asked.
2. Tell the cloud session. Signing in emails a long link the VM can't receive by paste; in the
   owner's run, the VM was restarted without `--no-clipboard` for the login only, then with it again.
   Run `claude remote-control --spawn=same-dir`; it registers the VM as a bridge environment. The
   cloud session starts a session there (attaching a cloud session to the folder directly wasn't
   offered on the owner's account), after the owner allows it on a trusted device, and the owner
   approves that session's commands. It starts with the account's connectors attached: keep it to
   read-only checks.
3. In the VM's Terminal: `xcrun agent plugin path --plugin-format claude`. A path means this Xcode
   ships Apple's Xcode plugin for Claude Code; an error means it needs a newer Xcode (§ 9 of the
   proposal). Write down which.
4. After step 7, sign that device out in your claude.ai settings (_check_ where: Settings → sessions
   or devices).

## 7. Clean up (1 min)

On the Mac: `tart stop air-test` (if it's still running) and `tart delete air-test`. Keep `base` for
the real setup, or `tart delete base` to free the space.

## Results to send back

Paste this, filled in, into the session:

```text
Mac: <chip> / <memory> GB / macOS <version>   Image: <image:tag>   VM: 4 CPU, 8 GB
Walls: shares none? <y/n>  router blocked? <y/n>  Mac blocked? <y/n>  github ok? <y/n>  clipboard off? <y/n>
macOS UI test: <passed/failed>, <real time>   iOS UI test: <passed/failed/skipped>, <real time>
Mac during build: pressure <green/yellow/red>, swap <GB>, usable? <y/n>
agent-desktop: snapshot ok? <y/n>  click changed the label? <y/n>
Remote Control: <done/skipped>   Xcode plugin (xcrun agent): <path/error/skipped>
Anything odd:
```
