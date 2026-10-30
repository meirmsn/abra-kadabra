# Native Apple apps with the host protected: a proposal

> **Status:** proposal for the owner, 2026-10-30. Nothing here is built; the decisions are § 10.
> It revisits TARGET's Environments 7 (D-02, D-17: "Claude runs as a non-admin user on a dedicated
> Mac; a macOS VM only if that proves insufficient") against a stricter goal the owner set on
> 2026-10-30: **the agents must not be able to harm or read the computer they run on.** The spikes
> it rests on are in [spikes/m4-apple-vm/](spikes/m4-apple-vm/README.md). Facts marked
> _unconfirmed_ were not read from a current first-party source; § 9 lists them.

## 0. In one screen

**The agent never runs on a Mac the owner owns.** It stays in its cloud session, with every wall it
has today. The Mac it builds on is a **throwaway macOS VM**, started fresh for one job and deleted
after, reached only through GitHub: the session pushes a commit, a workflow builds, tests, runs and
screenshots it in a VM, and the results come back as files the agent reads (images included).

- **Now (phases 1–2):** the VMs are **GitHub's hosted macOS runners**, which are Virtualization
  framework VMs on Apple silicon. No Mac of the owner's is involved at all, so there is no host to
  protect. The spike ran a SwiftUI app's UI tests (macOS and the iOS Simulator) with a screenshot, MLX on
  the VM's GPU and portable Swift on Linux this way.
- **Later, only if speed, cost or the network allowlist demand it (phase 3):** the same workflow on
  **throwaway Tart VMs on a dedicated Mac mini**, behind a host that runs nothing but the VM tool,
  a runner launcher and an egress proxy.
- **Performance and Neural Engine work** never runs in a VM (the VMs tried expose no Neural Engine,
  and their GPU is paravirtual): it runs from a **reviewed, notarized build** on real hardware, the owner's
  MacBook Air M4 being the target machine itself.
- **Signing** stays out of every agent's reach: development builds are ad-hoc signed (proven in the
  spike); real signing and notarization run only in a `release` job on `main`, pressed by the owner.
- **Cheap tier:** portable Swift (no Apple frameworks) builds and tests on Linux, in CI's `fast` job.

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
Pro (D-05). Costs are list prices found on 2026-10-30, partly through search snippets (§ 9).

| Option                                                                                                     | Host protection                                                                                                                        | Cost                                                                                                                           | Loop speed                                                                                                | Simulator + UI tests                             | Performance fidelity                                                             | Set-up                                              | Upkeep                                                |
| ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------- | --------------------------------------------------- | ----------------------------------------------------- |
| **A. GitHub-hosted macOS runners** (VMs)                                                                   | **Total:** no owner machine involved; fresh VM per job; no secrets in dev jobs. Egress not filterable                                  | Free on public repos; $0.062/min private (3-core M1); xlarge (M2, GPU) $0.102/min, Team/Enterprise only                        | Job starts in ~10 s; hello-world build+UI test 55–70 s cold; real app minutes; caches via `actions/cache` | Yes (spike)                                      | Low: 3 vCPU, paravirtual GPU, no Neural Engine                                   | Hours: a workflow                                   | None (GitHub updates images; pin the image and Xcode) |
| **B. Xcode Cloud**                                                                                         | Total (Apple's machines)                                                                                                               | 25 h/month with the Developer Program; 100 h $49.99/month                                                                      | No shell or ad-hoc commands; results in App Store Connect (speed unmeasured)                              | Yes (curated simulators, screenshots in results) | Low/unknown                                                                      | Hours                                               | Low                                                   |
| **C. Rented bare-metal Mac** (EC2 Mac, Scaleway, MacStadium)                                               | Total for the owner's machine; the rented host holds whatever we put there                                                             | 24 h minimum per lease: Scaleway M4 €0.22/h (~€5/day); EC2 `mac-m4` ~$1.23/h (~$30/day); monthly from ~€149                    | Fast once leased; SSH                                                                                     | Yes                                              | **High:** real M4, Neural Engine, full GPU (an M4 Mac mini is not a fanless Air) | Days: account, image, network                       | Medium: patching, wiping between uses                 |
| **D. Throwaway VMs on a local Apple silicon Mac** (Tart, Lume, UTM)                                        | Strong if the host is dedicated: VM boundary, no shared folders but a read-only model share, softnet + egress proxy                    | Mac mini M4 (~$599 at launch, current price unconfirmed); Tart free (FSL-1.1, no competing product); ≤ 2 VMs per Mac (licence) | Likely fastest (unmeasured): APFS clone, warm caches, models on local disk                                | Yes (same image family as A)                     | Low in the VM (same paravirtual GPU, no Neural Engine)                           | Days: base image, orchestrator, proxy, attack tests | Medium: base image rebuilds per Xcode, host updates   |
| **E. Dedicated Mac, agent as a non-admin user** (TARGET today)                                             | **Weak against the new goal:** the agent shares the host's kernel, network, other users' world-readable files, and state between tasks | Mac mini                                                                                                                       | Fast                                                                                                      | Yes                                              | High (bare metal)                                                                | Low                                                 | High: cleaning up after agents; drift                 |
| **F. Claude Code inside the Mac or VM** (Remote Control, self-hosted env.)                                 | Depends on D or E underneath; puts a claude.ai login (Remote Control) or a runner secret inside the VM                                 | Remote Control on Pro/Max; self-hosted environments need Team/Enterprise                                                       | Interactive                                                                                               | Yes, plus computer use (interactive only)        | As underneath                                                                    | Medium                                              | Medium                                                |
| **G. Hybrid (recommended):** Linux for portable Swift, A now, D when needed, real hardware for performance | Total now; strong later                                                                                                                | Free/low now                                                                                                                   | Good now; fastest with D                                                                                  | Yes                                              | High where it matters, from reviewed builds only                                 | Low now, staged                                     | Staged                                                |

Why not E: a non-admin account still sees the local network, `/Applications`, `/tmp`, other users'
world-readable files and every process list, keeps state from one task to the next, and a local
privilege escalation turns it into the owner's machine. Why not F as the main road: the walls this
devshop relies on (credentials only behind GitHub's proxy, `ship.sh`, the reviewer, the guard) live
in the cloud session; inside a VM the agent would need a GitHub write token and a claude.ai login it
can read, and self-hosted environments need a plan the owner doesn't have. Remote Control into a
throwaway VM stays an option for interactive debugging (§ 10, item 9).

## 4. Recommended architecture

```text
 owner ──▶ cloud session (Linux, unchanged: spec → build → ship → reviewer)
              │ 1. push the branch (as today)
              │ 2. apple-run.sh --do build|test|uitest|run …  (dispatches the project's apple.yml
              │    on that commit; or CI's slow tier on the PR)
              ▼
        GitHub Actions ── picks a lane by label ──────────────────────────────┐
              │                                                              │
   lane A (now): GitHub-hosted macOS VM              lane D (phase 3): dedicated Mac mini
   fresh per job, deleted after                      host: Tart + runner launcher + egress proxy, nothing else
              │                                      per job: tart clone base → JIT runner → job → tart delete
              │                                      models: read-only share; network: softnet → proxy only
              ▼                                                              │
   3. checkout → xcodebuild build/test (ad-hoc signed) → XCUITest screens → run the CLI on fixtures
   4. results as one artifact: summary.md, failures (file:line), screenshots/*.png,
      accessibility trees, logs, crash reports, outputs (e.g. transcript.json)
              │◀─────────────────────────────────────────────────────────────┘
              ▼
 5. apple-run.sh downloads it into .devshop/apple/<commit>/ ; the agent reads text and images; fixes; repeats
 6. ship.sh: the reviewer reads the head commit's screenshots and outputs; the PR gets them (pr-assets.sh)
 7. owner reviews the PR, approves → merge to main (plain CI green: fast on Linux, slow on macOS)
 8. owner presses "release" → release job on main, environment `release`: Developer ID signing,
    notarization (or TestFlight for iOS) → a signed build the owner chooses to install
 9. performance / Neural Engine: that reviewed build runs the benchmark on real hardware (the Air M4)
```

Tiers, mapped onto the existing two-tier contract:

- **`fast` (Linux):** the project's portable Swift packages (`swift test`), plus the usual secret
  scan, spec check, contract check and lint (SwiftLint/swift-format pinned). Requires that engine
  logic not needing Apple frameworks lives in its own package (chunking, joining speaker turns with
  words, transcript formats, timestamp maths), a design rule the Apple home states.
- **`slow` (macOS VM):** `xcodebuild` build and unit tests of the Apple targets, XCUITest screens with
  screenshots, the CLI on short fixtures with accuracy thresholds. It needs `runs-on` to be a macOS
  label, which today's shared `ci.yml` template doesn't allow (§ 9, item 7).
- **On demand (`apple.yml`, `workflow_dispatch`):** the agent's own build-run-look loop on any pushed
  commit, before a PR exists; the same scripts as `slow`. Dispatch needs Write, so forks can't start
  it.

Where the pieces live, following the existing layout: a stack home `runtime/stacks/apple/`
(`README.md`; `detect`: `Package.swift`, `*.xcodeproj`, `project.yml`; `supplies`), its tested
scripts (`apple-run.sh`, `fetch-models.sh`, `xcresult-summary.sh`), templates for `apple.yml` and
`release.yml`, and a "native" section in `runtime/guidelines/ui.md` (accessibility identifiers on every
control, screens in light and dark, window sizes or Dynamic Type sizes).

## 5. Threat model

**What "the host is protected" means here.** An agent, or code it writes, or a dependency or model
it pulls, or an instruction injected into anything it reads, can't (1) read or change anything of the
owner's on any machine, (2) use any credential beyond the agent identity's, (3) leave anything behind
that affects a later task, (4) reach the owner's local network, or (5) run on the owner's machines
until the owner installs a build they reviewed. Out of scope: Apple or GitHub turning hostile; a
hypervisor escape on lane D, which is why lane D's host holds nothing of value either.

| Item                    | Lane A (hosted VM, now)                                                                                                                                                                                                                                                                                                                   | Lane D (local throwaway VM, later)                                                                                                                                                                                                                                                                       |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Files**               | No owner machine involved. The VM has the repo checkout only.                                                                                                                                                                                                                                                                             | Dedicated Mac with no personal account, no Apple Account on the host, no SSH keys, no browser data. No shared folders except one read-only model volume outside any home. The guest's own SIP is off and TCC pre-granted (as in GitHub's and Cirrus' images): that weakens only the throwaway guest.     |
| **Credentials**         | Dev jobs hold only `GITHUB_TOKEN` with `contents: read`, minted per job. No Apple certificate, App Store Connect key or API token in any job an agent can trigger. Ad-hoc signing (`CODE_SIGN_IDENTITY=-`) for builds and UI tests: proven in the spike.                                                                                  | Same in the guest. The host holds one token to mint single-use JIT runner configs; only the config for one job enters the VM. A Hugging Face token for gated models, if needed, stays on the host's fetch script.                                                                                        |
| **Release credentials** | Developer ID certificate (.p12) and App Store Connect API key (.p8) only as secrets of a `release` environment limited to `main`, used by a job the owner starts; a temporary keychain per job, deleted after. A PR that edits `release.yml` takes effect only after the owner merges it, and CODEOWNERS calls `.github/` out (Safety 3). | Not used: releases always run on lane A.                                                                                                                                                                                                                                                                 |
| **Network**             | **No egress allowlist:** GitHub's VMs reach the internet. Accepted only because nothing secret is in the job; for a private repo the source itself could leave (§ 9, item 4). No path to the owner's network; no inbound.                                                                                                                 | Tart `--net-softnet` (no host, no private ranges by default) narrowed to one allowed address: an egress proxy in a Linux container (Apple's `container`, its own lightweight VM) with a domain allowlist (GitHub, Swift package hosts, the model mirror). No inbound. Proven by attack tests in phase 3. |
| **Persistence**         | The VM is discarded after the job. Caches (`actions/cache`) are scoped per branch: a branch can read `main`'s entries but not change them; model files are hash-checked after every restore anyway.                                                                                                                                       | `tart clone` from a read-only base per job, `tart delete` after, a watchdog deletes any VM older than the timeout. The base image is built from a pinned upstream image by a script the owner runs on purpose, never by an agent.                                                                        |
| **Resources**           | `timeout-minutes` per job; cancelling the run is the kill switch; GitHub's per-job limits (6 h).                                                                                                                                                                                                                                          | `tart set --cpu --memory --disk-size` per VM, at most 2 VMs (licence), job timeout, the watchdog, and one host command that stops and deletes every VM.                                                                                                                                                  |
| **The code itself**     | Runs only in the VM. Nothing the agent builds reaches an owner machine until the owner installs a notarized build from `release`.                                                                                                                                                                                                         | Same; the host never executes project code.                                                                                                                                                                                                                                                              |
| **Supply chain**        | `Package.resolved` committed with exact versions; models listed in a `models.lock` (repository, revision, file, sha256), fetched by a tested script that fails on any mismatch; Xcode and the runner image pinned (`macos-26`, `xcode-select` a named version).                                                                           | Same lock files; the base image pinned by digest; the proxy's allowlist names the package and model hosts.                                                                                                                                                                                               |
| **Physical iPhones**    | **Postponed.** Testing on the owner's phone goes through TestFlight from the release job: no USB, no host. macOS 27 adds USB passthrough to VMs (`VZUSBPassthroughDeviceConfiguration`), a later option for a dedicated test phone; device pairing state in a throwaway VM is untested.                                                   | Same.                                                                                                                                                                                                                                                                                                    |

What stays feedback, not a wall: `apple-run.sh`, the reviewer's reading of screenshots, any check
inside the VM. The walls are the VM boundary, GitHub's environment protection on `release`, branch
protection and the owner's approval.

## 6. How agents interact

**Commands** (tested scripts with explicit arguments, in the Apple stack home):

- `apple-run.sh --commit <sha> --do build|test|uitest|run|screens [--scheme S] [--fixture F] [--lane hosted|local]`:
  dispatches `apple.yml` on that pushed commit, waits, downloads the artifact to
  `.devshop/apple/<sha>/`, prints a summary. A failed build is exit 1 with the compiler errors as
  `file:line: message`; a run that never produced its artifact is exit 2 (could-not-run), never a pass.
- `fetch-models.sh models.lock <dir>`: download and hash-check; a mismatch or a missing file fails.
- `xcresult-summary.sh <bundle>` (runs in the VM): failures, attachments, test durations, as text.

**Seeing the UI.** XCUITest is the main tool: a "screens" test walks the core flow and attaches a
screenshot for each step and state (light and dark; window sizes on macOS, Dynamic Type sizes on iOS),
exported with `xcresulttool export attachments` (proven), plus the accessibility tree of each screen
(`XCUIApplication().debugDescription`) so the agent can reason about the controls without guessing
from pixels, and Xcode's accessibility audit (`performAccessibilityAudit`). For a quick look without
a test, `screencapture` (proven in the VM) and `xcrun simctl io <device> screenshot` on a booted
simulator (it failed in the spike once the test had shut the simulator down). The agent opens the
PNGs with its image-capable file reader, as it reads screenshots of web pages today.

**Getting results back.** The artifact is downloaded from GitHub's artifact storage, whose host
(`productionresultssa0.blob.core.windows.net`) this cloud environment's network policy denies (403,
tried 2026-10-30); the job's log came back through the GitHub API. So the project's environment
allows that host (an owner step, phase 1), or `apple-run.sh` falls back to reading the summary from
the job log. `.devshop/` is git-ignored in the project.

**Running the engine.** `--do run --fixture fixtures/meeting-3min.m4a` runs the CLI in the VM and
returns `transcript.json`, a rendered transcript and timings; the agent diffs it against the expected
output.

**Debugging.** Crash reports from `~/Library/Logs/DiagnosticReports`, `log show` filtered on the
app's subsystem, `lldb --batch -o run -k bt` for a backtrace, sanitizer test plans (Address,
Thread), all collected into the artifact. Interactive debugging (attaching to a running app) is the
one thing this loop doesn't give; it would need option F.

**In the PR.** The `slow` tier's screenshots of the head commit go on the PR through `pr-assets.sh`
(the native preview substitute TARGET Ship 8 asks for); the reviewer reads the same files. Teaching
the reviewer a "screens" lens changes how it reviews, so that change carries the reviewer eval.

## 7. The first project, checked against the design

The meeting transcriber: Swift/SwiftUI on macOS; diarization with pyannote Community-1 through
FluidAudio on Core ML (Neural Engine); transcription with Qwen3-ASR-1.7B on MLX (GPU); word timestamps
with Qwen3-ForcedAligner; 30–150 minute recordings; target a MacBook Air M4; CLI first, then a GUI.

- **Can an agent build and run the CLI on a test recording in the VM and read the transcript?** Yes
  by construction: the spike built and ran Swift in the VM, ran MLX on its GPU, and returned files.
  The full pipeline is phase 1's first acceptance item, on a 2–5 minute fixture.
- **Do Core ML and MLX run in a VM?** MLX: yes, on the paravirtual GPU (spike). The VM's Metal reports
  only the `mac2` family, so an MLX kernel that needs a newer feature could fail there; phase 1 finds
  out on the real model. Core ML: runs, but the VM has **no Neural Engine** (the spike asked Core ML
  for its devices: CPU and the paravirtual GPU only), so FluidAudio's models fall back to GPU or CPU
  without an error: right for **correctness** (diarization error and word error rate against references, with a tolerance, since
  fp16 on the Neural Engine and on the GPU can differ slightly), wrong for **speed**.
- **Fallback for accuracy and performance.** Accuracy runs in the VM on short fixtures in `slow`.
  Performance and long recordings (30–150 min) run on real hardware from a reviewed build: a
  `benchmark` command in the CLI (real-time factor per stage, peak memory, compute units used via
  `MLComputePlan`, thermal state over the run) that the owner runs on the Air M4, or that a rented
  bare-metal M4 runs for automated tracking (§ 10, item 4). The Air is fanless: a Mac mini's numbers
  over 150 minutes would flatter it.
- **Memory in the VM.** The standard runner has 7 GB and about 4.8 GB of GPU working set. Qwen3-ASR-
  1.7B at 8 bit (about 2–2.7 GB resident, reported) fits; bf16 (about 4–5 GB) is marginal: CI uses
  quantized weights, and the product's choice is measured on the Air.
- **Testing the GUI.** XCUITest screens with screenshots and accessibility trees (proven on a hello
  app), driven against a short fixture so the flow (open a recording, progress, the labelled
  transcript, export) runs in seconds.
- **Where 3–5 GB of models live.** Lane A: `actions/cache` keyed on `models.lock`'s hash, filled by
  `fetch-models.sh` on a miss, hash-checked after every restore; tests read models from a
  `MODELS_DIR` and never download. Lane D: a read-only volume on the host, filled from the same lock.
  The app itself downloads models on first launch for users, which is product scope, not CI.
- **Licences to respect:** FluidAudio Apache-2.0; pyannote Community-1 weights CC-BY-4.0 (attribution;
  gated on Hugging Face, though FluidAudio publishes its own Core ML conversion, ungated status
  _unconfirmed_); Qwen3-ASR and the aligner Apache-2.0; MLX MIT. The aligner takes at most 5 minutes
  of audio per call, so long recordings are chunked along the diarization's segments; that chunking is
  portable logic for the `fast` tier.

## 8. Rollout

Effort in agent-days, as PLAN.md counts it; owner steps named.

| Phase                                             | What                                                                                                                                                                                                                                                                                                                                          | Done when                                                                                                                                                                                                           | Effort                                   |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **0. Proposal and spikes**                        | This document and its spikes                                                                                                                                                                                                                                                                                                                  | The owner's decisions in § 10, recorded as a D-row                                                                                                                                                                  | done                                     |
| **1. The engine in hosted VMs** (smallest useful) | The Apple stack home (skeleton); a macOS-capable `slow` in the CI template; `apple.yml` and `apple-run.sh` with known-bad tests; `models.lock` and `fetch-models.sh`; in the transcriber's repo: a portable core package (Linux `fast`), the CLI running FluidAudio diarization and Qwen3-ASR (MLX) on a 2–5 minute fixture, output read back | A PR on the transcriber shows `fast` green on Linux, `slow` green on macOS with the fixture's transcript and its error rates in the evidence; `apple-run.sh` fails on a planted broken build and a missing artifact | 4–6 + owner: the repo, public or private |
| **2. The GUI**                                    | SwiftUI app around the engine; the screens test; screenshots on the PR; the native part of `ui.md`; the reviewer's screens lens (with its eval)                                                                                                                                                                                               | A UI change's PR carries screenshots per step and state from `slow`, and the reviewer judges them                                                                                                                   | 3–4                                      |
| **3. Local throwaway VMs** (only if needed)       | Triggered by measured pain: loop over ~5 min, cost, or the need for an egress allowlist. Mac mini set-up script, base image (Packer, pinned), runner launcher (JIT, one job per VM), egress proxy, kill switch; attack scenarios                                                                                                              | Each attack fails from inside a VM: read a host path, reach the host or the LAN, reach a non-allowlisted host, survive into the next job, change the base image, exceed CPU, memory or disk                         | 5–7 + owner: the Mac, half a day         |
| **4. Performance lane**                           | `benchmark` command; long fixtures; the owner's run on the Air from a release build, or a rented bare-metal M4 run                                                                                                                                                                                                                            | One recorded benchmark of a 60+ minute recording on an M4 with real-time factor, peak memory and compute units per stage                                                                                            | 2                                        |
| **5. Signing and release**                        | Apple Developer Program; Developer ID certificate and App Store Connect key in a `release` environment; `release.yml` (archive, sign, notarize, staple); for iOS, TestFlight                                                                                                                                                                  | The owner presses release on `main` and installs a notarized build that Gatekeeper accepts; a branch's copy of the workflow can't read the secrets (attack scenario)                                                | 2–3 + owner: enrolment, certificates     |
| **6. iOS** (lalista's voice input, M4)            | The same lanes with simulator destinations; TestFlight to the owner's phone; devices deferred                                                                                                                                                                                                                                                 | As phase 2, on iOS                                                                                                                                                                                                  | 2–3 on top                               |

## 9. Open questions and risks

1. **No Neural Engine in a VM:** seen in GitHub's VMs (Core ML lists CPU and GPU only); no Apple
   document says so either way, and a later macOS could change it. Performance work needs real
   hardware regardless (phase 4), and the CLI should log which compute units it got, so a silent
   fallback shows.
2. **The VM's GPU is a paravirtual device at a low feature level** (`mac2` only in the spike; cua
   reports that a host setting plus a private shim raises it, which we won't use). MLX ran; a model
   whose kernels need newer families may not. Measured in phase 1 on the real models.
3. **Licence for local VMs:** the "two additional instances per Mac" clause is quoted from secondary
   sources; the current macOS 26/27 licence text was not readable from here. It caps lane D at two
   concurrent VMs per Mac. The 24-hour minimum for leased Macs (EC2, Scaleway) likewise.
4. **No egress filter on lane A.** A build script can send the checkout anywhere. Harmless for a
   public repo with no secrets in the job; for a private repo the source is what could leak. Options:
   accept, lane D's proxy, or an egress-control action for macOS runners (not researched).
5. **Tart's owner changed:** OpenAI has maintained Tart since 2026-06-05 under FSL-1.1-ALv2 (free for
   anything but a competing product; each version Apache-2.0 after two years). Lume (MIT) is the
   fallback; both use the same framework, so the choice is reversible.
6. **Hosted-runner cost on a private repo:** at $0.062/min, 40 loops a day of 6 minutes is about
   $15/day. A public transcriber repo costs nothing in minutes.
7. **The CI template assumes Linux:** `runtime/templates/ci.yml` is "the same for every stack", and
   every job says `runs-on: ubuntu-24.04`. `slow` on macOS needs a runner label the stack chooses: a
   change to the template and the contract's wording (`ci-tiers-check.py` doesn't read `runs-on`).
8. **Cloud-session Swift toolchain:** the `fast` tier's portable Swift can't run in today's cloud
   session (toolchain host denied, Docker Hub rate-limited). Either pin a Swift toolchain in
   `install/tools.pin` with `download.swift.org` on the project environment's allowlist, or let the
   agent rely on CI for it.
9. **Model hosts:** Hugging Face was not reachable from this session's research; the project
   environment and lane D's proxy need its download hosts allowlisted, and whether FluidAudio's Core ML
   diarization weights are gated is _unconfirmed_.
10. **Prices** for Xcode Cloud tiers, EC2 Mac, Scaleway, MacStadium and the Mac mini were read from
    search results of the vendors' pages, not the pages themselves.
11. **Artifacts from the session:** GitHub's artifact storage host is denied by today's cloud
    network policy (§ 6, Getting results back); allowing it is untested.
12. **macOS 27 is current.** The spike used macOS 15 and 26.6.2 images; macOS 27 changes TCC storage
    (Cirrus' scripts handle it) and adds guest provisioning and USB passthrough.

## 10. Decisions for the owner

| #   | Decision                                                                                                   | Recommendation                                                                                                                                                                                                                               |
| --- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Replace TARGET Environments 7 ("Claude as a non-admin user on a dedicated Mac; a VM only if insufficient") | **Yes:** "the agent never runs on a Mac host: throwaway macOS VMs (GitHub's first, local Tart VMs when needed); real hardware only for reviewed builds" (a D-20 row)                                                                         |
| 2   | Start on GitHub's hosted macOS runners, before any Mac is bought or configured                             | **Yes:** phase 1 and 2 need nothing local                                                                                                                                                                                                    |
| 3   | The transcriber's repo public or private                                                                   | **Public** if the code can be: free macOS minutes, and the missing egress filter (§ 9.4) stops mattering. Private: set an Actions spending limit and expect lane D sooner                                                                    |
| 4   | Where performance and Neural Engine benchmarks run                                                         | **The owner's Air M4,** from a notarized release build, one command; a rented bare-metal M4 (Scaleway, about €5 a day) only if automated tracking is wanted                                                                                  |
| 5   | Signing pipeline                                                                                           | **A `release` environment on GitHub,** limited to `main`, started by the owner (the devshop's release-button pattern). Xcode Cloud for iOS TestFlight is the alternative that keeps keys at Apple                                            |
| 6   | A dedicated Mac mini for lane D                                                                            | **Not yet:** decide at the end of phase 2 on measured loop time and cost                                                                                                                                                                     |
| 7   | Physical iPhone testing                                                                                    | **Postpone;** TestFlight to the owner's phone covers manual checks                                                                                                                                                                           |
| 8   | Models for CI and the product                                                                              | Quantized Qwen3-ASR (8 bit) in CI; the product's precision chosen from the Air's benchmark. Keep Parakeet (FluidAudio, Core ML) as a measured alternative, since one library would then cover both                                           |
| 9   | Claude Code inside a throwaway VM (Remote Control) for interactive debugging                               | **Not now;** revisit with lane D, and only with a VM that holds no credential beyond the session's own                                                                                                                                       |
| 10  | Order on the roadmap: before or after M3 (lalista web)                                                     | **Phase 1 next to M3, not after it:** it lives in the transcriber's own repo and touches no lalista file; only its devshop pieces (the Apple home, the CI template's runner label) queue on the roadmap behind lalista's adoption (W10.11.6) |

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
- Tart: [licence](https://github.com/cirruslabs/tart/blob/main/LICENSE),
  [FAQ](https://github.com/cirruslabs/tart/blob/main/docs/faq.md),
  [image templates](https://github.com/cirruslabs/macos-image-templates); Lume:
  [cua](https://github.com/trycua/cua) (MIT; its [GPU measurements](https://github.com/trycua/cua/blob/main/blog/gpu-passthrough-macos-vms.md));
  UTM: [repository](https://github.com/utmapp/UTM); Apple [`container`](https://github.com/apple/container).
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
