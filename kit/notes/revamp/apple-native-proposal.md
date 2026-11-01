# Native Apple apps with the host protected: a proposal

> **Status:** proposal for the owner, 2026-10-30, **revised 2026-11-01** after the owner's answers in
> chat: private repositories must work, and the agent should drive Xcode on the owner's own Mac with
> strictly limited access to it. Nothing here is built; the decisions are § 10. It revisits TARGET's
> Environments 7 (D-02, D-17: "Claude runs as a non-admin user on a dedicated Mac; a macOS VM only if
> that proves insufficient") against a stricter goal the owner set on 2026-10-30: **the agents must
> not be able to harm or read the computer they run on.** The spikes it rests on are in
> [spikes/m4-apple-vm/](spikes/m4-apple-vm/README.md). Facts marked _unconfirmed_ were not read from
> a current first-party source; § 9 lists them.

## 0. In one screen

**The agent never touches the owner's Mac: it works inside a throwaway macOS VM running on it.**

- **The box.** The Mac runs [Tart](https://github.com/openai/tart), a command-line tool over Apple's
  Virtualization framework. Each task gets a fresh VM copied in seconds from a clean Xcode image, and
  the copy is deleted afterwards. Nothing of Claude's runs on the Mac itself.
- **Inside the box:** a git clone of the project, Xcode, the Simulator, a GitHub token that opens only
  that repository, Claude Code's Remote Control, and [agent-desktop](https://github.com/vercel-labs/agent-desktop)
  (it reads and clicks apps through the accessibility tree). This cloud session attaches to the VM's
  project folder, with the owner approving the attach, and runs its commands there: builds, UI tests,
  screenshots it reads back, clicking through the running app, the debugger.
- **The walls around the box:** no folder of the Mac's shared in (one read-only model folder at
  most), no shared clipboard, Tart's isolated network (no way to the Mac or the home network) and an
  allowlist proxy for the internet, CPU and memory limits, at most two VMs.
- **Private repositories work** with no Actions minutes for the agent's loop: it runs on the owner's
  Mac. Required CI stays on GitHub: `fast` on Linux, and `slow` on a hosted macOS runner once per push
  (a few minutes, so cents per push on a private repo).
- **Changes reach `main` the usual way:** a reviewed PR, the owner's approval.
- **Signing** stays out of every agent's reach: development builds are ad-hoc signed (proven in the
  spike); real signing and notarization run only in a `release` job on `main`, pressed by the owner.
- **Performance and Neural Engine work** never runs in a VM (the VMs tried expose no Neural Engine,
  and their GPU is paravirtual): it runs from a signed build on the owner's MacBook Air M4, the target
  machine itself.
- **Next:** a one-hour test on the Air ([checklist](spikes/m4-apple-vm/air-test.md)): the VM's walls,
  the spike's app built and UI-tested inside it, agent-desktop clicking it, and the Air's memory.

## 1. The devshop today

**How work flows.** The owner asks in a Claude Code cloud session. The `intent` skill names the kind
of request and, for a change, writes a one-screen spec in the project's `specs/` with numbered
acceptance items; the owner says "go". `build` writes code, tests and docs together, loading only the
stack homes the project uses (`runtime/stacks/<name>/`, picked by `stack-homes.sh` from the project's
files). `pr` writes the PR body from `runtime/templates/pr-body.md` and calls `ship.sh`, the one road
to a PR: a fresh, locked-down `claude -p` reviewer in a throwaway clone checks the commit against the
spec (and, for UI, browses a local run against `DESIGN.md`); only a pass pushes and opens the PR, with
the verdict as a comment. The owner reads the PR (summary, release note, preview, screenshots,
evidence) and approves; the approval merges; `main` deploys; a deploy comment and a metrics comment
follow. Next tasks come from the owner's `ROADMAP.md`; what the agent noticed but nobody decided goes
to `FINDINGS.md`.

**Where code runs.** In Anthropic's cloud sessions (Linux containers), **one cloud environment per
project** with that project's network allowlist and tokens; a two-line setup script clones the
devshop read-only and `bootstrap.sh` installs the pinned version and tools (`install/tools.pin`). The
GitHub proxy holds the agent identity's credentials; they never enter the container. Local services
(Supabase, `wrangler dev`) run inside the session. CI is GitHub Actions on `ubuntu-24.04`.

**Walls vs feedback.** The walls are outside the agent's reach: branch protection on `main` (PR only,
owner approval, CODEOWNERS), required plain CI (`fast`, `slow`), credential scopes (deploy secrets only
in a `production` environment limited to `main`, no repo-level secrets), and the agent's own GitHub
identity (Write, not admin). Hooks, the Bash guard (dcg), the reviewer and session-start checks are
feedback, never described as a boundary.

**Builds, tests, previews, deploys (web).** CI's `fast` job runs `scripts/check-fast.sh` (secret scan,
spec→test check, contract check, lint, unit tests); `slow` runs end-to-end tests (Playwright). A
project declares `scripts/local-run.sh`; the `build` skill's design review and the reviewer's browser
(`devshop-browse`, Chromium on `127.0.0.1` only) judge that local run. PRs on Cloudflare get a preview
Worker in a separate account. Screenshots go on the PR through `pr-assets.sh` (a parentless commit,
so the PR's diff is unchanged). `deploy` runs `scripts/deploy.sh` on `main`, in the `production`
environment, with a recorded rollback.

**Conventions to keep.** A stack is a home in `runtime/stacks/<name>/` (`README.md`, `detect`,
optional `supplies`); a project provides what `runtime/project-contract.txt` lists; CI has two tiers by
concept, the same template for every stack, the stack-specific part in the project's scripts;
mechanical steps are tested scripts with explicit arguments; every wall or project-facing check ships
with a known-bad test and killed mutants; a missing tool or unreadable output fails, never passes;
proposals and evidence live in `kit/notes/revamp/`, decisions in `DECISIONS.md`.

**What TARGET already says about Apple.** Native apps are in reach (Reach 8; iOS for lalista's voice
input; the Apple stack is M4). Native PRs show simulator screenshots instead of a preview link (Ship
8). Changes accumulate on `main` until the owner cuts a version (Ship 8). The Mac was to be dedicated
with Claude as a non-admin user (Environments 7). GitHub's hosted macOS runners were already named as
the CI path.

## 2. The constraint, and what the spikes showed

Xcode, `xcodebuild`, the Simulator, signing, Core ML, Metal and MLX need macOS on Apple hardware.
The design question is where macOS runs and what separates it from anything the owner cares about.
The spikes ran on 2026-10-30 ([record](spikes/m4-apple-vm/README.md)); GitHub's arm64 macOS runners
reported `kern.hv_vmm_present=1`, "Apple M1 (Virtual)", 3 cores, 7 GB, model `VirtualMac2,1`, so they
stand in for any Virtualization-framework VM.

| What                                                           | Result                                                                                                                                                                                                                                                    |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Portable Swift package (the transcript-joining logic), Linux   | `swift test` passed, 4 tests, Swift 6.4.1 on `ubuntu-24.04`, 24 s cold                                                                                                                                                                                    |
| Same, in this cloud session                                    | **Could not run:** `download.swift.org` is denied by the network policy (403) and Docker Hub refused the `swift` image (429, anonymous pull limit)                                                                                                        |
| Same package, macOS VM                                         | Passed on macOS 15 and macOS 26.6.2 (Xcode 26.6), 33–42 s cold                                                                                                                                                                                            |
| SwiftUI macOS app, ad-hoc signed, one XCUITest with screenshot | **Passed** in 55–70 s (build + test, cold): the app launched, the test clicked the button, read the label, attached a screenshot; `xcresulttool` exported it and the agent read it                                                                        |
| Plain `screencapture` and System Events, outside XCUITest      | Worked (1024×768 capture; System Events listed the app's window): the image ships TCC grants                                                                                                                                                              |
| Metal                                                          | One "Apple Paravirtual device", unified memory, about 4.8 GB working set; GPU family `mac2` only, none of `apple7`–`apple9`, not `metal3`                                                                                                                 |
| MLX 0.32.4 (Python)                                            | **Runs on the VM's GPU:** 2048² fp32 matmuls at 1.37–1.42 TFLOP/s on GPU vs 0.14–0.54 on the 3 CPU cores                                                                                                                                                  |
| Core ML: devices seen, plan, speed per compute unit            | Core ML lists **only the CPU and the paravirtual GPU: no Neural Engine** (`MLModel.availableComputeDevices`, macOS 15 and 26). Asking for `.cpuAndNeuralEngine` still runs, slower: a silent fallback                                                     |
| iOS Simulator: UI test and screenshot                          | **Passed** (macOS 15 image, Xcode 16.4, iPhone 16 Pro): first boot 53 s, build 2 min 23 s, test 51 s (4–6 min cold in all); the test's screenshot exported like the macOS one. `simctl io screenshot` after the test failed (simulator already shut down) |

What this settles: **a throwaway macOS VM is enough to build, run, UI-test and screenshot a SwiftUI
app, on macOS and on the iOS Simulator, and to run MLX on a GPU**, with no signing identity. What it doesn't: Neural Engine work and
performance numbers, which need bare metal (§ 7).

## 3. The options

Ratings are for this devshop: one owner, agents in cloud sessions, a Pro/Max Claude plan and GitHub
Pro (D-05), **private repositories**. Costs are list prices found on 2026-10-30, partly through
search snippets (§ 9).

| Option                                                                                                                                                    | Host protection                                                                                                                                                       | Cost                                                                                        | Loop speed                                                           | Simulator + UI tests                   | Performance fidelity                                        | Set-up                                             |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------- |
| **A. GitHub-hosted macOS runners** (VMs)                                                                                                                  | **Total:** no owner machine involved; fresh VM per job. Egress not filterable                                                                                         | Free on public repos; **$0.062/min on private** (3-core M1)                                 | A job per step: ~10 s to start, then the build; no live app to click | Yes (spike)                            | Low: 3 vCPU, paravirtual GPU, no Neural Engine              | Hours: a workflow                                  |
| **B. Xcode Cloud**                                                                                                                                        | Total (Apple's machines)                                                                                                                                              | 25 h/month with the Developer Program; 100 h $49.99/month                                   | No shell or ad-hoc commands; results in App Store Connect            | Yes (curated simulators)               | Low/unknown                                                 | Hours                                              |
| **C. Rented bare-metal Mac** (EC2 Mac, Scaleway, MacStadium)                                                                                              | Total for the owner's machine; the rented host holds whatever we put there                                                                                            | 24 h minimum per lease: Scaleway M4 €0.22/h (~€5/day); EC2 `mac-m4` ~$1.23/h (~$30/day)     | Fast once leased; SSH                                                | Yes                                    | **High:** real M4 and Neural Engine (but not a fanless Air) | Days                                               |
| **D. Throwaway VMs on the owner's Mac, CI jobs only** (a one-job runner per VM)                                                                           | Strong: VM boundary; only a single-use runner registration enters the VM                                                                                              | Free minutes; the Mac's memory                                                              | A job per step, VM boot each time (unmeasured); no live app to click | Yes (same image family as A)           | Low in the VM                                               | Days                                               |
| **E. The owner's own account, scoped** (Remote Control on one folder, computer use for Xcode only, App Sandbox, git)                                      | **Weak:** the shell runs as the owner (home folder, Keychain, browser data readable); git pushes with the owner's own GitHub credentials, which can approve and merge | Free                                                                                        | Fastest                                                              | Yes                                    | High (bare metal)                                           | Minutes                                            |
| **F. A second macOS user on the owner's Mac** (no admin, Claude Code's sandbox, repo-scoped token)                                                        | Medium: file permissions and the OS hold it; shares the network and the machine; UI work needs that user's desktop session on screen                                  | Free                                                                                        | Fast for headless work; awkward for UI                               | Only with its own desktop session      | High                                                        | An hour                                            |
| **G. (recommended) A throwaway VM on the owner's Mac, driven live** (Remote Control and agent-desktop inside); A for required CI; the Air for performance | **Strong:** VM boundary, nothing shared, isolated network; the VM holds only its own Claude login and a one-repo token                                                | Free loop; required CI cents per push on private; Tart free (FSL-1.1, no competing product) | Like working locally: build, run, click, screenshot, debug           | Yes; agent-desktop on SwiftUI untested | High where it matters, from signed builds only              | Days: base image, host script, proxy, attack tests |

Why not E, the owner's suggestion of 2026-11-01: approving one folder sets where the session works,
not what its shell can read; computer use limited to Xcode limits clicks, not commands; the App
Sandbox protects the Mac from the app, not from the agent or its build scripts; git makes the
project folder recoverable, nothing else. And a push from the owner's account is the owner's: the
approval wall disappears. **The same three controls inside the VM are G.** F is a stopgap for
headless work only.

## 4. Recommended architecture

```text
 owner ──▶ cloud session (unchanged: spec → build → ship → reviewer)
              │  attaches, with the owner's approval each time, to a folder on a computer (Remote Control)
              ▼
 the owner's Mac: runs Tart and the host script, nothing else of the devshop's or Claude's
 └─ VM "task-<n>" (cloned from a clean, pinned Xcode image; deleted after the task)
      network: Tart softnet (no host, no LAN) → allowlist proxy → GitHub, Swift packages, models, Anthropic
      shares: none, or one read-only model folder · clipboard off · 4 CPU / 8 GB (the Air) · ≤ 2 VMs
      ├─ ~/dev/<project>      git clone; a GitHub token for this repository only
      ├─ claude remote-control  ← every command of the session runs here
      ├─ Xcode, xcodebuild, Simulator, XCUITest, lldb
      └─ agent-desktop          accessibility tree: snapshot, click, type, screenshot
              │
              ▼  the session builds, runs, clicks and reads screenshots inside the VM; pushes the branch
 GitHub: PR → required CI (fast on Linux; slow on a hosted macOS VM) → reviewer verdict → owner approves → merge
              │
              ▼  owner presses "release": signing and notarization in a `release` job on GitHub
 the owner installs the signed build; performance runs on the Air from that build
```

**The pieces, in the existing layout:**

- **On the Mac, one tested host script** (`apple-vm.sh start|list|stop|kill-all`, in the Apple stack
  home): `start` clones the base image to `task-<n>`, sets its CPU and memory, and runs it with
  `--net-softnet --no-clipboard` and no shares but the model folder; `kill-all` stops and deletes every
  task VM. A watchdog deletes a VM older than its time limit. The owner runs it; nothing in the VM can.
- **The base image**, built on purpose by a script the owner runs (Packer, Tart's plugin): a Cirrus
  Xcode image pinned by digest, plus Claude Code, agent-desktop, XcodeGen, the devshop's pinned tools
  and Accessibility granted to agent-desktop inside the guest. Agents never change it.
- **The egress proxy** in a Linux container on the Mac (Apple's `container`, which runs each container
  in its own light VM), with the domain allowlist; softnet lets the VM reach only that proxy.
- **In the repo:** a stack home `runtime/stacks/apple/` (`detect`: `Package.swift`, `*.xcodeproj`,
  `project.yml`), its tested scripts, a CI template whose `slow` job runs on a macOS label, a
  `release.yml` template, and a native section in `runtime/guidelines/ui.md` (an accessibility
  identifier on every control, which XCUITest and agent-desktop both use).

**Tiers, on the existing two-tier contract:**

- **`fast` (Linux, every push):** the portable Swift packages (`swift test`): chunking, joining speaker
  turns with words, transcript formats. Plus the usual secret scan, spec check, contract check, lint.
- **`slow` (hosted macOS VM, every push):** `xcodebuild` build and tests, XCUITest screens with
  screenshots, the CLI on short fixtures. A few minutes, so cents per push on a private repo, with an
  Actions spending limit as the cap. It needs the CI template to let a stack choose `runs-on` (§ 9).
- **The agent's loop (the VM on the Mac, live):** everything above, plus running and clicking the app,
  as often as it likes, at no Actions cost.

## 5. Threat model

**What "the host is protected" means here.** An agent, or code it writes, or a dependency or model
it pulls, or an instruction injected into anything it reads, can't (1) read or change anything of the
owner's on any machine, (2) use any credential beyond the ones issued to the VM, (3) leave anything
behind that affects a later task, (4) reach the owner's local network, or (5) run on the owner's Mac
outside the VM until the owner installs a build they reviewed. Out of scope: Apple, GitHub or
Anthropic turning hostile, and a hypervisor escape, which is why the owner's own data is better off on
a different Mac than the VMs (§ 10, item 3).

| Item                 | The VM on the owner's Mac (the agent's loop)                                                                                                                                                                                                                                                                                                                                             | Hosted CI and release jobs                                                                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Files**            | No folder of the Mac shared in, except one read-only model folder outside any home folder. The guest's own SIP is off and its permissions pre-granted (as in GitHub's and Cirrus' images): that weakens only the throwaway guest.                                                                                                                                                        | No owner machine involved.                                                                                                                                                                          |
| **Credentials**      | Inside the VM: a claude.ai login (Remote Control refuses API keys) and a fine-grained GitHub token for this one repository (contents and pull requests). Branch protection and the owner's approval bound the token. **The login is the residual risk**: code in the VM could read it; the proxy limits where it could send it, and the owner signs the device out after a run of tasks. | `slow` holds only a read-only, per-job `GITHUB_TOKEN`. Release: Developer ID certificate and App Store Connect key as secrets of a `release` environment limited to `main`, a job the owner starts. |
| **Network**          | Tart softnet: no traffic to the Mac or private address ranges, no inbound. The VM reaches only the proxy, which allows GitHub, the Swift package hosts, the model hosts and Anthropic's.                                                                                                                                                                                                 | GitHub's VMs reach the internet (not filterable); nothing secret is in `slow`.                                                                                                                      |
| **Persistence**      | A fresh clone per task, deleted after; the watchdog deletes any VM past its limit; the base image changes only when the owner rebuilds it.                                                                                                                                                                                                                                               | The VM is discarded after the job; caches are per branch and model files hash-checked after restore.                                                                                                |
| **Resources**        | CPU and memory set per VM, disk fixed, at most 2 VMs (licence), the task's time limit, and `apple-vm.sh kill-all`.                                                                                                                                                                                                                                                                       | `timeout-minutes`; cancelling the run; the Actions spending limit.                                                                                                                                  |
| **The code itself**  | Runs only in the VM. The app keeps the App Sandbox on, so a build the owner later installs is confined too.                                                                                                                                                                                                                                                                              | Runs only in the job's VM; reaches the owner as a notarized build from `release`.                                                                                                                   |
| **Supply chain**     | `Package.resolved` committed with exact versions; `models.lock` (repository, revision, file, sha256) checked by a tested fetch script; the base image pinned by digest; the proxy's allowlist.                                                                                                                                                                                           | Same lock files; the runner image and Xcode pinned.                                                                                                                                                 |
| **Physical iPhones** | **Postponed.** TestFlight from `release` to the owner's phone: no USB, no host. macOS 27 adds USB passthrough to VMs, a later option for a dedicated test phone.                                                                                                                                                                                                                         | Same.                                                                                                                                                                                               |

The walls are the VM boundary, the network isolation, GitHub's branch and environment protection and
the owner's approval. Feedback, not walls: Claude Code's own sandbox and permission prompts inside the
VM, the reviewer, any check in the session.

## 6. How agents interact

**Starting a task:** the owner runs `apple-vm.sh start` on the Mac (later, a scheduled or on-demand
start), and approves the session's request to attach to the VM's project folder. From then on the
session's commands run in the VM.

**Building and testing:** `xcodebuild build` and `test` as anywhere; `xcresulttool export
attachments` for the UI tests' screenshots (proven in the spike), which the agent opens as images
directly from the VM's disk; `swift run` for the CLI on fixtures.

**Seeing and using the UI:** XCUITest for repeatable flows, with a screenshot per step and state
(light and dark; window sizes on macOS, Dynamic Type sizes on iOS) and the accessibility audit.
agent-desktop for exploring the running app: `agent-desktop snapshot --app <App> -i` returns every
control with a reference, `agent-desktop click <ref>` and `type` act on it without moving the pointer,
and `screenshot` captures it. `screencapture` and `xcrun simctl io <device> screenshot` for a quick
look. Both XCUITest and agent-desktop rely on accessibility identifiers, which the UI guideline makes a
rule.

**Debugging:** `lldb` attached to the running app, crash reports from
`~/Library/Logs/DiagnosticReports`, `log show` on the app's subsystem, sanitizer test plans.

**In the PR:** the `slow` tier's screenshots of the head commit go on the PR through `pr-assets.sh`
(the native preview substitute TARGET Ship 8 asks for); the reviewer reads the same files. Teaching
the reviewer a screens lens changes how it reviews, so that change carries the reviewer eval.

**Open:** how the devshop's own tooling (`ship.sh`, the reviewer, the hooks) runs when the session's
commands run in the VM: from the base image's install, or by pushing from the VM and shipping from
the session's container. Phase 2 settles it (§ 9).

## 7. The first project, checked against the design

The meeting transcriber: Swift/SwiftUI on macOS; diarization with pyannote Community-1 through
FluidAudio on Core ML (Neural Engine); transcription with Qwen3-ASR-1.7B on MLX (GPU); word timestamps
with Qwen3-ForcedAligner; 30–150 minute recordings; target a MacBook Air M4; CLI first, then a GUI.

- **Can an agent build and run the CLI on a test recording in the VM and read the transcript?** Yes
  by construction: the spike built and ran Swift in a VM and ran MLX on its GPU; in the VM on the Mac
  the agent reads the output file directly.
  The full pipeline is phase 3's acceptance item, on a 2–5 minute fixture.
- **Do Core ML and MLX run in a VM?** MLX: yes, on the paravirtual GPU (spike). The VM's Metal reports
  only the `mac2` family, so an MLX kernel that needs a newer feature could fail there; phase 3 finds
  out on the real model. Core ML: runs, but the VM has **no Neural Engine** (the spike asked Core ML
  for its devices: CPU and the paravirtual GPU only), so FluidAudio's models fall back to GPU or CPU
  without an error: right for **correctness** (diarization error and word error rate against references, with a tolerance, since
  fp16 on the Neural Engine and on the GPU can differ slightly), wrong for **speed**.
- **Fallback for accuracy and performance.** Accuracy runs in the VM and in `slow` on short fixtures.
  Performance and long recordings (30–150 min) run on real hardware from a reviewed build: a
  `benchmark` command in the CLI (real-time factor per stage, peak memory, compute units used via
  `MLComputePlan`, thermal state over the run) that the owner runs on the Air M4 (§ 10, item 6), or that a
  rented bare-metal M4 runs if automated tracking is ever wanted. The Air is fanless: a Mac mini's numbers
  over 150 minutes would flatter it.
- **Memory in the VM.** GitHub's runner has 7 GB and about 4.8 GB of GPU working set; the VM on the
  Air would get about 8 GB (§ 9, item 4). Qwen3-ASR-
  1.7B at 8 bit (about 2–2.7 GB resident, reported) fits; bf16 (about 4–5 GB) is marginal: CI uses
  quantized weights, and the product's choice is measured on the Air.
- **Testing the GUI.** XCUITest screens with screenshots and accessibility trees (proven on a hello
  app), driven against a short fixture so the flow (open a recording, progress, the labelled
  transcript, export) runs in seconds.
- **Where 3–5 GB of models live.** On the Mac: one models folder outside any home folder, filled by
  `fetch-models.sh` from `models.lock` with hashes checked, shared into each VM **read-only**, so no
  task downloads them. In CI: `actions/cache` keyed on `models.lock`'s hash, hash-checked after every
  restore. Tests read models from a `MODELS_DIR` and never download. The app itself downloads models
  on first launch for users, which is product scope, not CI.
- **Licences to respect:** FluidAudio Apache-2.0; pyannote Community-1 weights CC-BY-4.0 (attribution;
  gated on Hugging Face, though FluidAudio publishes its own Core ML conversion, ungated status
  _unconfirmed_); Qwen3-ASR and the aligner Apache-2.0; MLX MIT. The aligner takes at most 5 minutes
  of audio per call, so long recordings are chunked along the diarization's segments; that chunking is
  portable logic for the `fast` tier.

## 8. Rollout

Effort in agent-days, as PLAN.md counts it; owner steps named.

| Phase                                  | What                                                                                                                                                                                                                                                                         | Done when                                                                                                                                                                                                               | Effort                                    |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **0. Proposal and spikes**             | This document and its spikes                                                                                                                                                                                                                                                 | The owner's decisions in § 10, recorded as a D-row                                                                                                                                                                      | done                                      |
| **1. The test on the Air**             | [The checklist](spikes/m4-apple-vm/air-test.md): Tart, an Xcode image, the walls, the spike's app built and UI-tested in the VM, agent-desktop clicking it, the Air's memory; optionally Remote Control                                                                      | The owner's filled-in results; the record updated from them                                                                                                                                                             | owner, ~1 hour                            |
| **2. The VM lane on the Mac**          | `apple-vm.sh` with known-bad tests; the base image recipe; the egress proxy; the Remote Control attach; how `ship.sh` and the reviewer run from a VM session; attack scenarios                                                                                               | From inside a VM each attack fails: read a host path, reach the Mac or the LAN, reach a host off the allowlist, survive into the next task, change the base image, exceed CPU or memory. A session ships a PR from a VM | 5–7 + owner: half a day on the Mac        |
| **3. The engine** (smallest useful)    | The Apple stack home; the CI template's macOS `slow`; `models.lock` and `fetch-models.sh`; in the transcriber's private repo: a portable core package (`fast` on Linux) and the CLI running FluidAudio diarization and Qwen3-ASR (MLX) on a 2–5 minute fixture inside the VM | A PR shows `fast` and `slow` green with the fixture's transcript and error rates in its evidence                                                                                                                        | 4–6 + owner: the repo, the spending limit |
| **4. The GUI**                         | SwiftUI app around the engine; the screens test; screenshots on the PR; agent-desktop exploration in build; the native part of `ui.md`; the reviewer's screens lens (with its eval)                                                                                          | A UI change's PR carries screenshots per step and state, and the reviewer judges them                                                                                                                                   | 3–4                                       |
| **5. Performance**                     | A `benchmark` command; long fixtures; the owner's run on the Air from a signed build                                                                                                                                                                                         | One recorded benchmark of a 60+ minute recording: real-time factor, peak memory and compute units per stage                                                                                                             | 2                                         |
| **6. Signing and release**             | Apple Developer Program; Developer ID certificate and App Store Connect key in a `release` environment; `release.yml` (archive, sign, notarize, staple); TestFlight for iOS                                                                                                  | The owner presses release and installs a notarized build Gatekeeper accepts; a branch's copy of the workflow can't read the secrets (attack scenario)                                                                   | 2–3 + owner: enrolment, certificates      |
| **7. iOS** (lalista's voice input, M4) | The same VM with simulator destinations; TestFlight to the owner's phone; devices deferred                                                                                                                                                                                   | As phase 4, on iOS                                                                                                                                                                                                      | 2–3 on top                                |

## 9. Open questions and risks

1. **The Claude login inside the VM.** Remote Control needs a claude.ai login and refuses API keys,
   so the VM holds one. Code in the VM could read it. The proxy narrows where it could go, and the
   owner signs the device out after a run of tasks; how long such a login lives, and how quickly
   signing out cuts it, is _unconfirmed_. Phase 2 measures it.
2. **The devshop's tooling in a VM session:** whether `ship.sh`, the reviewer and the hooks run inside
   the VM (installed in the base image) or the session pushes from the VM and ships from its own
   container is unsettled; so is how a session attached to a folder splits work between the two.
3. **Remote Control's own limits** (its docs and this session's tools): the folder must be a git
   repository's root, not in a hidden directory; the folder must be trusted once interactively; the
   server exits after about 10 minutes without network; a session stays tied to the first computer it
   attaches to; the owner approves every attach.
4. **Memory on the Air.** A VM of 8 GB on a 16 GB Air leaves about 8 GB for macOS and the owner's
   apps. A hello-world UI test fit in GitHub's 7 GB VM; the transcriber adds 2–2.7 GB for the speech
   model at 8 bit, plus the aligner and Xcode. Phase 1 measures it; a 24 or 32 GB Air, or a Mac mini,
   is comfortable.
5. **agent-desktop on Xcode and SwiftUI apps is untested;** its macOS "shell surfaces" are listed as
   planned. Its optional helper that sends screen descriptions to a model provider stays off.
6. **No Neural Engine in a VM:** seen in GitHub's VMs (Core ML lists CPU and GPU only); no Apple
   document says so either way. Performance work needs real hardware regardless, and the CLI logs the
   compute units it got, so a silent fallback shows.
7. **The VM's GPU is a paravirtual device at a low feature level** (`mac2` only in the spike). MLX ran;
   a model whose kernels need newer families may not. Phase 3 finds out on the real models.
8. **Licence:** the "two additional instances per Mac" clause is quoted from secondary sources; the
   current licence text was not readable from here. It caps the Mac at two VMs at once.
9. **Tart's owner changed:** OpenAI has maintained Tart since 2026-06-05 under FSL-1.1-ALv2 (free for
   anything but a competing product; each version Apache-2.0 after two years). Lume (MIT) is the
   fallback, on the same framework, without Tart's network isolation.
10. **A VM can't run a newer macOS than its host,** so the base image follows the Air's macOS.
11. **The CI template assumes Linux:** every job in `runtime/templates/ci.yml` says
    `runs-on: ubuntu-24.04`; a macOS `slow` needs a runner label the stack chooses
    (`ci-tiers-check.py` doesn't read `runs-on`).
12. **From this cloud session:** a Swift toolchain can't be fetched (`download.swift.org` denied,
    Docker Hub rate-limited), and GitHub's artifact storage host is denied (403), so CI artifacts are
    read from job logs unless the project's environment allows that host. The VM lane doesn't need it.
13. **Model hosts:** Hugging Face was not reachable from this session's research; the proxy's
    allowlist and the project's environment need its download hosts, and whether FluidAudio's Core ML
    diarization weights are gated is _unconfirmed_.
14. **Prices** for Xcode Cloud, EC2 Mac, Scaleway, MacStadium and the Mac mini were read from search
    results of the vendors' pages, not the pages themselves.

## 10. Decisions for the owner

| #   | Decision                                                                                                   | Recommendation                                                                                                                                                                                                                               |
| --- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Replace TARGET Environments 7 ("Claude as a non-admin user on a dedicated Mac; a VM only if insufficient") | **Yes:** "the agent never runs on a Mac host; it works inside a throwaway macOS VM on the owner's Mac; real hardware only for signed builds" (a D-20 row)                                                                                    |
| 2   | Run the one-hour test on the Air                                                                           | **Yes, first:** it answers memory, agent-desktop and the walls before any build                                                                                                                                                              |
| 3   | Which Mac hosts the VMs                                                                                    | **The Air to start,** if the test's memory pressure stays green or yellow. A Mac mini when the VMs should run unattended, or if memory pressure goes red; it also keeps the owner's data off the machine the VMs run on                      |
| 4   | Required macOS CI for private repos                                                                        | **A hosted macOS runner for `slow`, once per push, with an Actions spending limit.** The alternative, a one-job runner in a VM on the Mac, is free but makes CI depend on the Mac being on                                                   |
| 5   | A claude.ai login inside the VM (Remote Control needs one)                                                 | **Accept it,** with the proxy's allowlist and a sign-out after each run of tasks; revisit if a scoped login appears                                                                                                                          |
| 6   | Where performance and Neural Engine benchmarks run                                                         | **The Air,** from a signed build, one command                                                                                                                                                                                                |
| 7   | Signing pipeline                                                                                           | **A `release` environment on GitHub,** limited to `main`, started by the owner (the devshop's release-button pattern); Xcode Cloud for iOS TestFlight is the alternative that keeps keys at Apple                                            |
| 8   | Physical iPhone testing                                                                                    | **Postpone;** TestFlight to the owner's phone covers manual checks                                                                                                                                                                           |
| 9   | Models for CI and the product                                                                              | Quantized Qwen3-ASR (8 bit) in the VM and CI; the product's precision chosen from the Air's benchmark. Keep Parakeet (FluidAudio, Core ML) as a measured alternative                                                                         |
| 10  | Order on the roadmap                                                                                       | **Phase 1 now** (the owner's hour); phases 2–3 next to M3, since they live on the Mac and in the transcriber's own repo; only the devshop pieces (the Apple home, the CI template's runner label) queue behind lalista's adoption (W10.11.6) |

## Sources

Read on 2026-10-30. First-party pages where reachable; otherwise the vendor page as quoted by search.

- Apple: [Virtualization: using iCloud with macOS VMs](https://developer.apple.com/documentation/virtualization/using-icloud-with-macos-virtual-machines),
  [`VZMacGraphicsDeviceConfiguration`](https://developer.apple.com/documentation/virtualization/vzmacgraphicsdeviceconfiguration),
  [nested virtualization (Linux guests, M3+)](https://developer.apple.com/documentation/virtualization/vzgenericplatformconfiguration/isnestedvirtualizationsupported),
  [`VZUSBPassthroughDeviceConfiguration`](https://developer.apple.com/documentation/virtualization/vzusbpassthroughdeviceconfiguration),
  [`MLComputeUnits`](https://developer.apple.com/documentation/coreml/mlcomputeunits),
  [Xcode Cloud pricing](https://developer.apple.com/xcode-cloud/get-started), MacBook Air M4 specs
  (support.apple.com 122209); the licence's VM clause via
  [The Eclectic Light Company](https://eclecticlight.co/2022/08/04/virtualisation-on-apple-silicon-macs-8-how-apple-limits-vms/).
- GitHub: [hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
  [larger runners](https://docs.github.com/en/actions/reference/runners/larger-runners),
  [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing),
  [macOS 26 GA](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/),
  [runner images](https://github.com/actions/runner-images) (TCC, automation mode).
- Tart: [repository](https://github.com/openai/tart), [licence](https://github.com/cirruslabs/tart/blob/main/LICENSE),
  [FAQ](https://github.com/cirruslabs/tart/blob/main/docs/faq.md),
  [image templates](https://github.com/cirruslabs/macos-image-templates); Lume:
  [cua](https://github.com/trycua/cua) (MIT; its [GPU measurements](https://github.com/trycua/cua/blob/main/blog/gpu-passthrough-macos-vms.md));
  UTM: [repository](https://github.com/utmapp/UTM); Apple [`container`](https://github.com/apple/container).
- agent-desktop: [repository](https://github.com/vercel-labs/agent-desktop) (Apache-2.0).
- Hosted Macs: [EC2 Mac](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html),
  [Scaleway Apple silicon](https://www.scaleway.com/en/pricing/apple-silicon/),
  [MacStadium](https://www.macstadium.com/pricing).
- Claude Code: [Remote Control](https://code.claude.com/docs/en/remote-control),
  [self-hosted environments](https://code.claude.com/docs/en/self-hosted-environments),
  [sandboxing](https://code.claude.com/docs/en/sandboxing),
  [desktop iOS Simulator](https://code.claude.com/docs/en/desktop-ios-simulator).
- Models: [FluidAudio](https://github.com/FluidInference/FluidAudio),
  [pyannote Community-1](https://huggingface.co/pyannote/speaker-diarization-community-1),
  [Qwen3-ASR](https://github.com/QwenLM/Qwen3-ASR), [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift),
  [MLX](https://github.com/ml-explore/mlx).
