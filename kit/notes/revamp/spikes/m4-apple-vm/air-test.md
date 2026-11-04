# The one-hour test on the owner's MacBook Air

A manual test for the owner, kept with the spike: does the design in
[the Apple proposal](../../apple-native-proposal.md) § 4 work on the Air itself? It checks three
things: a throwaway macOS VM there can build and UI-test the spike's app; agent-desktop can drive
the app inside the VM; the VM can't reach the Mac or the home network, and the Mac stays usable.
Nothing here touches the Mac outside Tart and the VM.

Commands were taken on 2026-11-01 from Tart's repository README (now under OpenAI) and
agent-desktop's README; they were not run from here. Where a value is marked _check_, look it up
as described and note what you used.

## 0. Before you start (5 min)

- **The Mac:** Apple menu → About This Mac: write down the chip, the memory (16, 24 or 32 GB)
  and the macOS version.
- **Free disk:** the Xcode image is tens of GB (_check_ its size on the package page below), and the
  test needs about as much again for builds. Have at least 100 GB free (an estimate).
- **Homebrew** on the Mac: `brew --version`. If it isn't found, install it from brew.sh first.
- **Close heavy apps** so the memory readings mean something.

## 1. Install Tart and get an Xcode image (20–40 min, mostly download)

1. Install Tart: `brew install openai/tools/tart`
2. Pick an Xcode image: open the Cirrus Labs package list (GitHub → the `cirruslabs` organisation →
   Packages, search `macos-`). Take a `macos-<name>-xcode:<N>` image whose macOS is **not newer**
   than the Air's macOS (a VM can't run a newer macOS than its host).
3. Download it once, as the clean copy: `tart clone ghcr.io/cirruslabs/macos-<name>-xcode:<N> base`
4. Make the test's throwaway copy, and give it 4 CPU cores and 8 GB of memory:
   `tart clone base air-test`, then `tart set air-test --cpu 4 --memory 8192`

## 2. Start it isolated (2 min)

`tart run air-test --net-softnet --no-clipboard`

A window opens with a Mac inside. `--net-softnet` lets the VM reach the internet but not the Mac or
the home network; `--no-clipboard` stops copy and paste between them. Cirrus' images log in on their
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
2. Tell the cloud session; it asks to attach to that folder, and you approve the request.
3. After step 7, sign that device out in your claude.ai settings (_check_ where: Settings → sessions
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
Remote Control: <done/skipped>
Anything odd:
```
