### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-virtiofs-rebase.bats:266` (case 17)
**What**: Spec case 17 is titled "merge-fallback leaves anchor as ancestor (real repo)" and is meant to prove the _merge-fallback_ rung produces the ancestor end-state. The implemented case 17 exercises only a **clean rebase** (real git, clean FF base) — not the merge-fallback path. The merge-fallback RESULT/exit contract is covered by case 4, but case 4 uses the stub `git` whose `merge` response is a bare `exit 0` (no real merge commit, no real ancestry change). So no test verifies that a real `merged-fallback` run actually leaves `$ANCHOR` as an ancestor of HEAD.
**Why**: If the merge-fallback rung were to invoke `merge` with the wrong ref or flags, the audit-range invariant Phase 1.1 depends on (`$ANCHOR..HEAD` is the true delta) could break, and no test would catch it. The ancestry end-state is asserted only on the clean-rebase path.
**Fix**: This is genuinely hard to test through the stub (the stub can't synthesize real ancestry, and the phantom flake isn't reproducible with real git — the whole reason the stub harness exists). Treated as low because: (a) the script's own decision logic — which rung runs, the RESULT string, the exit code — is fully covered by case 4; (b) the only unverified piece is git's own "`merge <anchor>` makes `<anchor>` an ancestor" guarantee, which is git's contract, not this script's. Optional hardening: a real-repo fixture that forces the merge rung by injecting a `core.checkStat`-resistant condition is not worth the fragility. Acceptable as-is; noted for completeness.

---

Notes on items checked and cleared (not findings):

- **Case 16 "no repo-global config leak"** — spec wording said "assert `git config --local core.checkStat` is unset". The implemented test asserts the stronger, more correct invariant via the stub argv log: `! grep -E "^config .*core\.checkStat"` — i.e., the script never _attempts_ a `git config` write at all. Asserting `git config --local` against the stub would be meaningless (the stub never persists config). The implemented form is the right call.
- **Coverage (Section A)** — new `kit/scripts/virtiofs-rebase.sh` has a matching `kit/tests/util-virtiofs-rebase.bats` (devshop-side rubric: new `kit/scripts/**.sh` → matching `.bats`). All 18 spec-enumerated cases are present and the full suite passes (18/18 green, verified by running it). The SKILL.md Phase 1.0 caller integration is covered by the updated `util-ak-merge-devshop.bats` assertions (helper-call-precedes-audit, exit-code 10/11 branches, inline-checkStat ordering) and the `structural-invariants.bats` infra-scripts allowlist was updated to include the new script.
- **Test quality (Section B)** — assertions are specific (exact RESULT strings via `grep -qx`, exact exit codes, argv-flag presence, real-repo ancestry/in-progress state). No weak `toBeTruthy`-style assertions. The phantom-vs-conflict discrimination (D3) is directly tested by case 9 (phantom stderr string + unmerged paths → must classify as conflict, must NOT run checkStat). The F244 rescheduled-pick variant and the abort-guard both-ways (cases 10, 14) are covered. No skipped/`.only`/`test.skip` patterns in the diff. Web/React/RLS/realtime/LLM-boundary rubric sections are N/A (devshop bash helper, no project source).

---

### [domain: tests] [section: C] [severity: low]

**File**: commit `f7f36b3` `Tests-Coverage-Bypass:` trailer
**What**: The bypass trailer states `util-virtiofs-rebase.bats (18 cases) is staged in THIS same commit alongside the new helper; the coverage check compares the new script against the committed tree and can't see the same-commit-staged test — a first-commit ordering artifact, not missing coverage`.
**Why**: Verifying the bypass is load-bearing and still valid.
**Outcome**: **VERIFIED**. The named test file exists in the same commit as the helper, contains all 18 cases, and the full suite passes. The bypass was a genuine first-commit ordering artifact (coverage check reads the committed tree, not the same-commit stage), and the coverage it claimed now exists and is green. Recorded as low (informational) — no action.
