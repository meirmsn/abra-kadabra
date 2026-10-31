# Spike: what a throwaway macOS VM can build, test and run (2026-10-30)

For [the Apple proposal](../../apple-native-proposal.md). A record of what was run, not live code.

**Question.** Can an agent build, run, UI-test and screenshot a SwiftUI app, and run Core ML and MLX,
inside a macOS VM on Apple silicon, with no signing identity? Does portable Swift build on Linux?

**Where.** GitHub's hosted arm64 macOS runners, which are Virtualization-framework VMs (each reported
`kern.hv_vmm_present=1`, "Apple M1 (Virtual)", 3 cores, 7 GB, model `VirtualMac2,1`), images
`macos-15` and `macos-26` (macOS 26.6.2, Xcode 26.6); Linux on `ubuntu-24.04`. Each job is a fresh VM,
deleted after: the "clone, run, delete" cycle of a local throwaway VM, on hardware that isn't the
owner's. A temporary workflow on the proposal's branch ran it twice (runs 1 and 2); it was removed
before the PR and is kept here as [`workflow.yml`](workflow.yml).

**What ran** (all in this directory):

- [`TranscriptCore/`](TranscriptCore): a portable Swift package (the logic that gives each aligned
  word the speaker whose turn overlaps it most), with 4 XCTest cases.
- [`app/`](app): a hello-world SwiftUI app for macOS and iOS (XcodeGen `project.yml`) and one XCUITest
  that clicks a button, checks the label and attaches a screenshot. Signed ad hoc
  (`CODE_SIGN_IDENTITY=-`) on macOS, unsigned for the simulator.
- [`probes/`](probes): `metal.swift` (the GPU Metal sees), `make_model.py` + `coreml_probe.swift` (an
  8-layer fp16 Core ML program; the devices Core ML lists, its compute plan, 500 predictions per
  compute-unit setting), `mlx_probe.py` (MLX's device and a 2048² matmul on CPU and GPU).

## Results

| Probe                                  | macOS 15 VM                                                     | macOS 26 VM                                   |
| -------------------------------------- | --------------------------------------------------------------- | --------------------------------------------- |
| Portable Swift, `swift test`           | 4 passed, 31–42 s cold                                          | 4 passed, 33–44 s cold                        |
| Metal device                           | "Apple Paravirtual device", unified memory, ~4.8 GB working set  | same                                          |
| Metal families                         | `mac2` only; not `apple7`–`apple9`, not `metal3`                | same                                          |
| Core ML devices                        | **CPU and GPU only, no Neural Engine**                          | **same**                                      |
| Core ML plan with `.all` (tiny model)  | every op on CPU                                                 | same                                          |
| Core ML, 500 predictions, ms           | cpuOnly 194, cpuAndGPU 193, cpuAndNeuralEngine 225, all 191     | 84, 53, 124, 78                               |
| MLX 0.32.4, 20 × 2048² matmul fp32     | GPU 1.42 TFLOP/s; CPU 0.14–0.21                                 | GPU 1.19–1.37 TFLOP/s; CPU 0.43–0.54           |
| macOS app: build + XCUITest            | **passed**, 55–70 s cold (one test 6.5 s)                       | not run                                       |
| Screenshot from the test               | exported with `xcresulttool export attachments`: [the image](outputs/macos-uitest-after-click.jpg) | not run |
| `screencapture`, System Events         | worked (1024×768; the app's window listed)                      | not run                                       |
| iOS Simulator: build + XCUITest        | **passed** (Xcode 16.4, iPhone 16 Pro): boot 53 s (first-boot data migration), build 2 min 23 s, test 51 s; screenshot attachment exported (not viewed here, see below)                                                        | not run                                       |

Linux (`ubuntu-24.04`): Swift 6.4.1, `swift test` 4 passed, 24 s cold.

In this cloud session (Linux, the devshop's network policy): **could not run** portable Swift.
`download.swift.org` is denied (403 from the proxy) and Docker Hub refused the `swift:6.2` image (429,
the anonymous pull limit, as REVIEW-3 saw for Supabase's images).

**Surprises.** The iOS screenshot was exported in the VM but could not be read back here: the
spike carried images out in the job log (base64), and this session reads logs only through the
GitHub API, which returns them inline only when short; the log file and artifacts live on GitHub's
storage host, which this environment's network policy refuses (403). `simctl io screenshot` after
the test failed ("Error creating the image") because the test had shut the simulator down. Run 4
failed on the spike's own device selection (`-showdestinations` listed only a placeholder). Run 1's Core ML probe failed before reaching Core ML: coremltools 9.0 has no native
build for the image's default Python 3.15 ("BlobWriter not loaded"); run 2 used Homebrew's Python
3.12. The macOS 15 and 26 images differ in CPU speed by 2–4× on the same test (noisy neighbours or
host generation; not investigated). Asking Core ML for the Neural Engine in a VM raises no error: it
quietly runs elsewhere, so an app must log the compute units it actually got.

**Not tested.** A real model (FluidAudio, Qwen3-ASR) in the VM; a local Tart VM; network isolation;
anything on macOS 27.
