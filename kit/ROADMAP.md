# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

Priority tiers:

- **v0** — fixes the current template needs before a second project adopts it. Each exists because the first template-validation project (lalista) surfaced a gap every future project will hit. Factoring up now avoids each project re-inventing the wheel.
- **v1** — devshop capabilities that would be valuable but aren't blocking next-project onboarding.
- **v+** — future, when the need is felt.

---

## v0 — blocks next-project adoption

### Docs-coverage hook exempts audit-prose paths (`specs/<feature>/review.md` and similar)

**Problem.** `kit/scripts/commit-hooks/check-docs-freshness-project.sh` greps every staged file for `posthog.capture(`, `Sentry.captureException(`, and similar analytics-call regex. When `specs/<feature>/review.md` (the audit-trail file written by `/ak-pre-ship` Gate 8 and `/ak-check-docs-and-tests` § Audit N) contains an audit bullet attesting "this PR adds zero `posthog.capture()` calls", the literal string `posthog.capture()` is the **subject** of the audit prose, not a new call site. The hook fires `BLOCKING: New analytics event call sites added without METRICS.md update`, the operator pays a `Docs-Coverage-Bypass:` trailer to commit, and audit-time's bypass-trailer review then VERIFIES the trailer as "yes, false positive in audit prose" — the system pays Sonnet to confirm what the hook already knew but couldn't express.

**Concrete numbers from home-os PR #9** (2026-05-13, the foundation supabase-schema-and-rls PR):

- 3 commits in this PR carried `Docs-Coverage-Bypass:` trailers: `97bb365`, `8e88ca0`, `9580061`.
- Each trailer cited the same fact pattern: "literal `posthog.capture()` in `specs/supabase-schema-and-rls/review.md` § Gate 3 / § Audit N as audit prose, not a new call site."
- Audit 2's bypass-trailer-audit (Sonnet, ~30s × 3 trailers = ~90s) VERIFIED every one.
- Net cost: 3 hook fires, 3 bypass-reason drafts, 3 commit re-runs, ~$0.15–0.30 of Sonnet API spend, and one PR comment exchange explaining the recurring false-positive — for **zero signal**.

The pattern recurs every PR that does any non-trivial pre-ship audit work. Every audit-prose mention of `posthog.capture` or `Sentry.captureException` (in a Gate-N findings list, Audit-N tests-findings bullet, bypass-trailer-review note) triggers the same useless cycle.

**Codified from** home-os PR #9 (2026-05-13). 3 bypass trailers within a single PR cycle for identical fact patterns, plus 1 more in the `/devshop` commit (`feat/firewall-extras-overlay` § 1e779da) that just landed for the CI dual-trigger entry. Lalista exhibited the same pattern with smaller frequency (~1 per multi-gate PR); home-os surfaced it concentrated because the foundation PR ran Audit 1 + Audit 2 with detailed findings prose.

**Shape of the fix — two-stage:**

**Stage A (cheap):** Exempt the canonical audit-prose paths from the hook's analytics-event grep:

```bash
# kit/scripts/commit-hooks/check-docs-freshness-project.sh
# Inside the loop that greps staged files for new `posthog.capture(` / `Sentry.captureException(` call sites:

case "$file" in
  specs/*/review.md|specs/*/tasks.md)
    # Audit-trail / task-decision prose. The literal string mentioning an
    # analytics function is the SUBJECT of the prose, not a new call site.
    continue
    ;;
esac
```

The exemption is path-shaped, not regex-content-shaped, so it can't be gamed by an actual `posthog.capture(` call landing in the middle of an audit file (the hook still catches when the literal lives in `apps/`, `packages/`, `supabase/functions/` — the actual call-site surfaces).

**Stage B (defense in depth):** When the hook _does_ fire on a non-exempt path, run a cheap **context check** before blocking:

````bash
# Is the `posthog.capture(` match inside a fenced code block (``` … ```) or
# inline code (`...`)? Markdown rendering and audit-trail prose use both.
# A `posthog.capture(` mention inside code-formatting is documentation, not
# a new call site.
if grep -nE 'posthog\.capture\(' "$file" | \
   while read -r match; do
     line=${match%%:*}
     # Check if the match line is inside a fenced or inline code block.
     # ...
   done | grep -q "in-prose"; then
  continue
fi
````

Stage B is more work; Stage A alone closes 95% of the pain.

**Why v0 — blocks next-project adoption:**

Every project that runs `/ak-pre-ship` (which is every project on the devshop) hits this on every PR that produces a `review.md` with detailed findings prose. The bypass-trailer cost compounds: per-PR operator attention to draft the reason, per-PR Sonnet call to verify, per-PR rebuild cycle. Stage A is a 5-line case-statement add in one shell script; saves operator + Sonnet time on every devshop PR going forward.

**Trigger:**

- home-os PR #9 — 3 bypasses in one PR (worst case observed so far)
- lalista PRs running `/ak-check-docs-and-tests` — same pattern at lower frequency (PRs that don't write detailed audit prose don't trip it)
- Every future project: identical fact pattern guaranteed

**Cross-ref:**

- `/devshop/kit/scripts/commit-hooks/check-docs-freshness-project.sh` — the grep loop to patch
- `/devshop/kit/scripts/commit-hooks/check-tests-coverage-project.sh` — symmetric exemption may apply (audit prose can also mention test-file paths in passing)
- home-os PR #9 — concrete bypass-trailer audit trail at `97bb365`, `8e88ca0`, `9580061`
- `/devshop/.claude/skills/ak-check-docs-and-tests/SKILL.md § Step 5 bypass trailer audit` — downstream consumer of bypass trailers

**Cost/risk:**

- Implementation: ~1 hour (Stage A: 5-line patch + bats test that exercises the exemption; Stage B optional follow-up).
- Risk: low. The exemption is path-scoped to `specs/*/review.md` and `specs/*/tasks.md` — neither path can legitimately contain runtime app code. Worst case if abused: an operator hides an actual analytics call site inside a review file (which would be obvious in code review and gets caught by `/review` Gate 9 on the next PR anyway).
- Benefit: zero false-positive bypass trailers on audit-prose files; ~$0.10–0.30 saved per PR on the deferred Sonnet round-trip; operator attention freed for real reviews.

[v0, surfaced-by home-os PR #9 § 5b reflection on 2026-05-13]

---

### `PRODUCTION_URL` onboarding gap — fill `.env` + rebuild container + verify (`/ak-new-project` Phase B + `/ak-go-live` Step 1.5 tri-state diagnostic)

**Problem.** `/ak-new-project` scaffolds `.devcontainer/.env` with an empty `PRODUCTION_URL=` slot. The Vercel URL isn't known until after `vercel link` + first deploy land, so scaffold-time population is impossible. By the time the URL is known (end of Phase B, when `CLAUDE.md § Deploy Configuration` gets written), the skill **doesn't prompt the operator to do anything with `.env`** — the gap silently propagates.

The downstream cost: `/usr/local/bin/refresh-allowed-ips.sh` reads `/etc/refresh-allowed-ips/production_url` (a tiny file populated by `init-firewall.sh` at container start from `.env`), no-ops on empty input, the firewall never allowlists the prod hostname, and **every post-deploy curl from inside the container returns HTTP 000** — including `/ak-go-live § Step 1.5` (pre-flight prod health probe), `/ak-go-live § Step 3`, and `/canary`. The disambiguation paragraph in `/ak-go-live § Step 1.5` catches the false positive correctly ("HTTP 000 = in-container, not pre-existing prod issue"), but at the cost of **disabling the prod probe for the project's lifetime** until the gap is closed.

**Two distinct failure modes** — the prior version of this entry only modelled the first; home-os auth-magic-link session (2026-05-13, immediately after home-os PR #9 deploy) surfaced the second:

| Mode  | `.devcontainer/.env` has `PRODUCTION_URL=` line? | `/etc/refresh-allowed-ips/production_url` populated? | Cause                                                                                                                                                                           |
| ----- | ------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | No                                               | No (0 bytes)                                         | Operator never pasted the URL into `.env` after first deploy.                                                                                                                   |
| **B** | **Yes**                                          | **No (0 bytes)**                                     | Operator pasted into `.env` AFTER container creation, but didn't rebuild. `init-firewall.sh` only runs at container start; mid-session `.env` edits don't propagate to `/etc/`. |
| **C** | Yes                                              | Yes                                                  | Working state. HTTP 000 from the container is unrelated (Vercel IP rotation — recovered via `sudo refresh-allowed-ips.sh` per `/devshop/CLAUDE.md § Known Footguns`).           |

Modes A and B both manifest as "HTTP 000 with empty `/etc/...` file" — the current Step 1.5 disambiguation can't distinguish them, so it gives identical generic advice ("set PRODUCTION_URL in `.env` and rebuild"). That's wrong-half-the-time: Mode A operators need both steps; Mode B operators have already done step one and just need rebuild.

**Concrete from home-os**:

- `/ak-go-live` for PR #9 (2026-05-13) ran with HTTP 000 on both Step 1.5 and Step 3 → **Mode A** at that time. The deploy completed on indirect signals (Vercel `state=READY`, `deploy-migrations.yml` green).
- Same session, post-deploy, operator pasted `PRODUCTION_URL=home-os-nu-two.vercel.app` into `.devcontainer/.env`. Did NOT rebuild → **Mode B**.
- Diagnostic confirming Mode B: `sudo cat /etc/refresh-allowed-ips/production_url` returns 0 bytes; file's mtime is `May 13 05:18` (container creation), not the time the operator pasted into `.env`. The /etc file IS the firewall's source of truth, and it's frozen at container-start state.

**Shape of the fix — three coordinated changes, all on the skill side:**

**Fix 1 (`/ak-new-project` Phase B): Explicit rebuild prompt at the moment `.env` is updated.** The natural spot is the existing step that writes `CLAUDE.md § Deploy Configuration` — that's when the URL becomes known. Add a structured operator-action block:

```markdown
After writing CLAUDE.md § Deploy Configuration, emit this verbatim to the operator:

Three side-effects to apply before the next session:

1. ! echo 'PRODUCTION_URL=<bare-hostname>' >> /workspace/.devcontainer/.env
   (bare hostname per CLAUDE.md § Gotchas — `.env` wants `<x>.vercel.app`,
   not `https://<x>.vercel.app`)

2. VS Code → Cmd+Shift+P → "Dev Containers: Rebuild Container"
   (init-firewall.sh runs at container start, reads .env, populates
   /etc/refresh-allowed-ips/production_url. Without this rebuild,
   every post-deploy curl from inside the container returns HTTP 000.)

3. After rebuild: ! sudo cat /etc/refresh-allowed-ips/production_url
   should print the bare hostname (proves init-firewall ran with the new .env).
```

Three steps because **all three are necessary** — operators who skip step 2 land in Mode B; operators who skip step 3 don't know whether they're in Mode B or genuinely-broken-prod.

**Fix 2 (`/ak-go-live § Step 1.5`): Tri-state diagnostic.** On HTTP 000, replace the current binary "in-container vs prod" disambiguation with a Mode A / B / C classifier:

```bash
# /ak-go-live § Step 1.5 — HTTP 000 branch
ETC_FILE=/etc/refresh-allowed-ips/production_url
HAVE_ETC=$(sudo cat "$ETC_FILE" 2>/dev/null | tr -d '[:space:]')
# Can't read .env directly (permission-denied). Ask the operator via ! grep.

if [ -z "$HAVE_ETC" ]; then
  cat <<MSG
HTTP 000 + /etc/refresh-allowed-ips/production_url is empty.

Either the .env line is missing (Mode A) or .env has it but rebuild is needed
(Mode B). To distinguish, run:

  ! grep '^PRODUCTION_URL=' /workspace/.devcontainer/.env

  - If the line prints with a value → Mode B (rebuild the container; the
    /etc file will populate at startup).
  - If empty / no line → Mode A (append the line, then rebuild):
      ! echo 'PRODUCTION_URL=<bare-host>' >> /workspace/.devcontainer/.env
      then VS Code → Cmd+Shift+P → "Dev Containers: Rebuild Container"

After rebuild: ! sudo cat /etc/refresh-allowed-ips/production_url
(should print the bare host).
MSG
  # Continue the pipeline — this is a probe-availability gap, not a prod issue.
else
  # Mode C: /etc has value but curl still 000 → Vercel IP rotation.
  echo "HTTP 000 with /etc populated — likely Vercel IP rotation."
  echo "Run: sudo /usr/local/bin/refresh-allowed-ips.sh"
fi
```

**Fix 3 (`/ak-go-live § Step 1.5`): Optional in-session shortcut for Mode A only.** When `CLAUDE.md § Deploy Configuration § Production URL` has a known value AND `/etc/...` is empty, offer to write the bare hostname directly to `/etc/refresh-allowed-ips/production_url` (sudo) and re-run `refresh-allowed-ips.sh`. **Ephemeral** — survives this session only; lost on next rebuild. Surface explicitly: "this is a session-only patch; for permanent fix, apply Fix 1's three-step procedure." Closes the gap for the current `/ak-go-live` run without requiring a rebuild mid-deploy.

**Why three coordinated changes, not one:** Fix 1 closes the gap **at the moment it's created** (best leverage; operators only configure once). Fix 2 catches **operators who skipped Fix 1** (the audit-time safety net; required because Fix 1 only ships to projects created after this lands). Fix 3 is the **session-recovery escape hatch** (lets a single deploy proceed even when Fix 1 + 2 haven't been applied).

**Why v0 — blocks next-project adoption:**

Every devshop project's first `/ak-go-live` lands in Mode A. Every project's first post-onboarding session at minimum tries the operator-side `! curl` path because the in-container probe is broken. For projects that ship UI early, the gap silently weakens canary coverage from "automated curl + screenshot diff" to "open-in-browser-by-hand if I remember." Fix 1 alone closes Mode A for all future projects; Fix 2 catches existing projects on next `/ak-go-live` run; Fix 3 keeps any individual deploy moving regardless.

**Trigger:**

- home-os `/ak-go-live` PR #9 (2026-05-13) — Mode A on the deploy; indirect signals carried it.
- home-os auth-magic-link session (same date, ~30 min later) — operator noticed the gap, pasted `PRODUCTION_URL` into `.env`, did NOT rebuild → **Mode B**. Confirmed via `sudo cat /etc/refresh-allowed-ips/production_url` returning 0 bytes with mtime = container creation. The prior version of this entry didn't model Mode B, so its Option A (auto-derive at Step 1.5) would have hit the same `.devcontainer/.env` permission-block AND still required a rebuild — not actually a fix.
- Lalista didn't surface this because `PRODUCTION_URL=lalista.app` was filled in `.env` BEFORE the first container creation (lucky timing), so Mode A and Mode B both bypassed.
- Every future project: identical default state, identical silent gap.

**Cross-ref:**

- `/workspace/CLAUDE.md § Gotchas § PRODUCTION_URL lives in two places` — the format-divergence warning (bare host in `.env`, full URL in GH Variable)
- `/devshop/CLAUDE.md § Known Footguns § Firewall IP rotation` — Mode C recovery path (refresh script, additive)
- `/devshop/.claude/skills/ak-go-live/SKILL.md § Step 1.5` — primary consumer; tri-state diagnostic patch lands here (Fix 2 + Fix 3)
- `/devshop/.claude/skills/ak-go-live/SKILL.md § Step 3` — secondary consumer; canary fallback inherits the tri-state diagnostic
- `/devshop/.claude/skills/ak-new-project/SKILL.md` — the Phase B step that writes `CLAUDE.md § Deploy Configuration` is where Fix 1's structured prompt belongs (exact step number TBD at implementation time — Phase B has ~25 steps; pick the one that produces the URL)
- `.devcontainer/init-firewall.sh` — the script that copies `.env`'s `PRODUCTION_URL` into `/etc/refresh-allowed-ips/production_url` at container start. Source of the Mode B gap (only runs at container start, not on `.env` change).
- `/usr/local/bin/refresh-allowed-ips.sh` — the runtime allowlist-refresh script that reads from `/etc/`
- `/etc/refresh-allowed-ips/production_url` — the runtime file; Mode B distinguisher
- home-os PR #9 (Mode A example) + home-os auth-magic-link session (Mode B example) — concrete prior art

**Cost/risk:**

- Implementation: ~30 min for Fix 1 (skill prose addition at one Phase B step); ~45 min for Fix 2 (tri-state diagnostic + bats coverage); ~20 min for Fix 3 (in-session shortcut + the "ephemeral" disclosure). Total ~1.5 hours. Recommend shipping all three together — Fix 1 alone leaves Mode B uncovered; Fix 2 alone leaves the Mode A default in place; Fix 3 alone doesn't propagate.
- Risk: low. Skill prose changes (Fix 1) are markdown-only. The Step 1.5 sudo-write (Fix 3) requires the already-documented sudo path to `/etc/refresh-allowed-ips/production_url` (Claude can't write to `.devcontainer/`, deliberately — that's where the operator action via `!` lives). Worst case for Fix 2 is a misclassification (Mode B routed to Mode A path or vice versa) — both paths surface the rebuild action prominently, so the misclassification adds at most ~30s of operator reading time.
- Benefit: every devshop project gets working in-container prod probes from first `/ak-go-live` onward. The HTTP 000 disambiguation paragraph in the skill becomes the rare-edge-case path it was meant to be, not the every-deploy default. Audit-time signal that the gap is closed: Step 1.5 produces a clean HTTP 200/3xx; the operator never sees the tri-state diagnostic message.

[v0, surfaced-by home-os PR #9 § 5b reflection on 2026-05-13; refined by home-os auth-magic-link session same day to add Mode B + tri-state Fix 2 + Fix 3]

---

### Template `ci.yml` — dedupe duplicate CI runs from overlapping `push` + `pull_request` triggers

**Problem.** `/devshop/template/.github/workflows/ci.yml:1-6` ships the workflow with two overlapping event triggers:

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches-ignore: [main]
```

Both fire for every commit pushed to a PR branch — `push` (because the branch isn't `main`) and `pull_request: synchronize` (because the PR's base is `main`) — and GitHub does not de-duplicate. The result is exactly two identical runs against exactly the same SHA every time a developer pushes during PR work.

The first push on a new feature branch also fires twice, asymmetrically: the `push` event fires immediately, then `gh pr create` opens a PR seconds later and fires `pull_request: opened` against the same SHA. So even the "PR open" moment costs 2 runs.

**Concrete numbers from home-os PR #9** (2026-05-13, the foundation supabase-schema-and-rls PR — a typical /ak-build cycle, nothing pathological about the flow):

- 3 SHAs landed on the branch (`/ship` commit, 5.6 BUILD-LOG bookkeeping commit, 5.8 Audit 2 commit).
- 6 CI runs fired (`gh run list --branch feature/... --json event` shows `event=push` and `event=pull_request` alternating for each SHA, all 6 conclusion `success`).
- Cost: 6 × `ubuntu-latest` minute, ~1 min each = ~6 GitHub-Actions-minutes burned for 3 logical checks. At Vercel preview + lint + typecheck + unit + build, each run is non-trivial.

Scaled across the v0 Phase 1 roadmap for home-os (15 features, ≥3 SHAs per PR typical given Phase 5.6 + 5.8 commits) the cost is ~90 extra runner-minutes per project per Phase 1, and the duplication compounds for every devshop project that inherits the template.

A secondary annoyance: dual runs confuse `/ak-build`'s Phase 5.8.1 polish-loop enumeration (`gh run list --limit 50 | select(.createdAt >= PR_OPENED_AT)`) — operators reading the audit-trail comment see "5 runs" or "6 runs" for a clean polish loop and have to mentally divide by 2 to get the actual SHA count. Phase 6's audit comment needs prose explaining the doubling. The duplicate runs are not informative — the second run tests literally the same SHA as the first and is guaranteed to produce the same answer (unless GitHub-runner flake, which is its own problem).

**Codified from** home-os PR #9 (2026-05-13). The /ak-build Phase 6 final audit-comment composition surfaced the doubling when the operator asked "why were there 5 CI runs?" — `gh run list --json event` exposed the dual-trigger pattern. No prior project had asked the question because nobody looked closely at the run count; the cost had been silently doubling on every project from day one.

**Shape of the fix — one of two patterns, both single-line edits to `template/.github/workflows/ci.yml`:**

**Option A (simplest — preferred):** Drop the `push` trigger entirely. Only `pull_request` fires.

```yaml
on:
  pull_request:
    branches: [main]
```

- **Catches**: every commit landed via a PR. Devshop's `/ak-build` flow always opens a PR before any non-trivial commit (per `/devshop/CLAUDE.md § Devshop shipping flow` — "Branch for anything beyond trivial"), so this covers 100% of real cycles.
- **Misses**: pushes to feature branches without a PR yet (rare; only if the operator pushes before `/ship` runs). On the `/ak-build` path, the first push and PR-open happen seconds apart in the same Phase 4 step — `pull_request: opened` will fire on PR creation, so even the first SHA gets CI.
- **Cost**: ~50% reduction in runner-minutes per project.

**Option B (preserves push-without-PR coverage):** Use GitHub's recommended `if:` guard on the push trigger:

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches-ignore: [main]

jobs:
  fast:
    # Skip the push run if a PR exists for this branch — pull_request: synchronize covers it.
    if: github.event_name == 'pull_request' || github.event.pull_request == null
    runs-on: ubuntu-latest
```

- The `if:` is **at the job level**, not the workflow level (GitHub doesn't support workflow-level `if:` on triggers). So the workflow still queues a run on every event, but the run no-ops to "skipped" instantly if the duplicate condition holds. UI shows the skipped run; minutes-burn is ~0 seconds.
- **Catches**: pushes to feature branches without a PR (run as `push`); pushes to branches with PRs (run as `pull_request: synchronize`, the `push` run is auto-skipped).
- **Slight UI cost**: skipped runs still show in `gh run list` output, so Phase 5.8.1's enumeration query needs to filter by `conclusion != "skipped"` to count "real" runs. One extra `.jq` clause.

**Recommendation:** ship Option A. Devshop's discipline is "PR-first for anything non-trivial," so the edge case Option B preserves doesn't exist in practice. If a project decides it needs push-coverage later, Option B is a one-line revisit.

**Other edits that may want to follow:**

- `/ak-build § Phase 5.8.1` — the polish-loop enumeration query parses `displayTitle` to identify runs. The displayTitle for `push` events is the commit message; for `pull_request` it's the PR title. Today's filter accidentally relies on this distinction. Once Option A lands the enumeration becomes single-event uniform; simplify the surrounding prose.
- `/ak-build § Phase 5.2 / 5.7` watch-loop — `gh run list --limit 1` returns the latest run on the branch; with Option A there's no ambiguity. With Option B the operator may need `gh run list --event pull_request --limit 1` if the synchronize run hasn't started yet.

**Why v0 — blocks next-project adoption:**

Every new project from this template inherits the dual-trigger workflow. Each project's GitHub-Actions-minute bill silently doubles. The bigger cost: every devshop project's CI logs are 2x noisier than they should be, every audit comment has to explain the doubling, every `/ak-build` watch-loop has to handle the asymmetric first-push-vs-subsequent-pushes case. Fix once at the template; every future project ships with the right shape. No project-level migration needed for already-onboarded projects (they can `cp template/.github/workflows/ci.yml apps/web/.github/workflows/ci.yml` once and pick up the dedupe).

**Trigger:**

- home-os PR #9 surfaced it (and home-os is currently the only second template-validation project — same dual-trigger pattern as lalista, just nobody asked at lalista).
- Next project that adopts the template will inherit the same doubling. The bill scales linearly with project count, not per-project work.

**Cross-ref:**

- `/devshop/template/.github/workflows/ci.yml:1-6` — the dual-trigger block to edit
- home-os `feature/supabase-schema-and-rls` PR #9 — concrete 6-run example
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 5.8.1` — polish-loop enumeration consumer
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 5.2` — watch-loop consumer
- GitHub Actions docs on overlapping `push` + `pull_request` — https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#using-events-to-trigger-workflows

**Cost/risk:**

- Implementation: ~15 minutes (one-line edit + a /ak-pre-ship dry-run + propagation note in the changelog).
- Risk: low. Option A loses CI coverage for the edge case "push to branch without PR" — but the devshop flow never produces that state for substantive commits. If a project's operator does push directly without a PR, the next push that creates the PR will fire `pull_request: opened` and run CI on the latest SHA, which is the same coverage with one-extra-cycle latency.
- Benefit: ~50% reduction in CI minutes per devshop project, ongoing.

---

### `/ak-pre-ship` LLM-mediated gate contract — prohibit `n/a` outcomes

**Problem.** Gates 6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa` are documented as "MUST emit `pass | findings | blocked` — never `skipped`" (see `ak-pre-ship/SKILL.md:640-648` for the `/qa` codification, traced to lalista PR #10's false-positive Gate 9 and PR #53's synthetic-harness substitution). The contract is enforced **by reading-comprehension only** — there is no parser, no grep, no Phase-3→4 refusal check. A subagent that writes `Result: n/a` for one of these gates produces a `review.md` that literally violates the SKILL.md prose, and nothing in the pipeline catches it.

Compounded by a related failure mode at the orchestrator layer: `/ak-build` Phase 3 spawns the pre-ship subagent with a free-form prompt. If the orchestrator pre-classifies gates as `n/a` in that prompt (e.g., "this is a logic-only PR; mark `/qa` as n/a"), the subagent obeys an authoritative-sounding instruction that contradicts the documented gate contract. Gate disposition belongs to the gate runner per its own SKILL.md, not to the orchestrator's preamble.

**Codified from** lalista PR #65 (2026-05-12). The Phase 3 orchestrator prompt instructed the subagent to mark `/qa` and `/design-review` as `n/a` with the rationale "logic-only PR; no visual surface." The subagent obeyed; `/qa` never ran; adjacent-flow regression risk (sign-in, add-item, mark-bought — any of which could be silently broken by the `ListClient.tsx` wake-recovery + `TOKEN_REFRESHED` listener changes) shipped without a live walk. The Phase 3 → 4 handoff parser (which already refuses to advance on `findings_pending > 0` or `blocked > 0`) silently passed the violation because `n_a > 0` is not a refuse-to-advance condition.

**Fix — three small, targeted edits across two files:**

| Fix | File                                                                   | Shape                                                                                                                                                                                                                                                                                                                                                                                                      |
| --- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A   | `.claude/skills/ak-pre-ship/SKILL.md § Outcome semantics`              | Add subsection "`n/a` is not legal for LLM-mediated gates." Codify: gates 6/7/8/9 emit `pass                                                                                                                                                                                                                                                                                                               | findings | blocked`. Scope exemptions emit `blocked (n/a per scope: <reason>)`—`blocked` is the literal outcome string; the adversarial-review chain judges the rationale. |
| B   | `.claude/skills/ak-build/SKILL.md § Phase 3 → Phase 4 handoff`         | Add third refuse-to-advance rung: parse `review.md` for `## Gate <N>: /(review                                                                                                                                                                                                                                                                                                                             | cso      | design-review                                                                                                                                                   | qa)`followed by`Result: n/a`(literal). Halt + surface the contract violation to the operator. Grep is anchored on the LLM-mediated gate names; no false-positive risk against legitimate`n/a` outcomes (Gate 3 responsive, Gate 11 hero shots — those gates' names don't match the grep). |
| C   | `.claude/skills/ak-build/SKILL.md § Phase 3: Pre-ship (quality gates)` | Add constraint paragraph to the Phase 3 agent prompt template: **"Do NOT pre-classify gates as `n/a` in your prompt or reasoning. Gate disposition belongs to the gate runner per its SKILL.md, not the orchestrator. If you find yourself thinking 'this gate doesn't apply because <reason>,' let the gate runner make that call and emit `blocked (n/a per scope: ...)` — that's its job, not yours."** |

**Coverage matrix:**

| Failure mode                                                                                                         | Caught by                                                                                                                                                                           |
| -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Subagent writes `Result: n/a` for an LLM-mediated gate                                                               | Fix A makes it a contract violation; Fix B halts the pipeline at Phase 3 → 4                                                                                                        |
| Orchestrator pre-classifies gates in the Phase 3 prompt                                                              | Fix C explicitly forbids it; even if Fix C is missed by a future caller, Fix A + B still catch the downstream violation                                                             |
| Genuine scope exemption (`/design-review` on a non-UI PR, `/qa` on a docs-only PR)                                   | Fix A allows `blocked (n/a per scope: <reason>)`; the existing adversarial-review chain judges whether the reason holds; review.md retains the audit trail (reason + chain verdict) |
| Subagent emits `blocked` legitimately but `dismissalLog` / shim-map dismisses it without LLM review (home-os PR #15) | **NOT yet covered.** See Fix D below.                                                                                                                                               |

**Fix D — `blocked` outcomes cannot be shim-mapped past LLM review (added 2026-05-15 after home-os PR #15):**

| Fix | File                                                                                                               | Shape                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D   | `kit/scripts/adversarial-review.sh` + `/ak-pre-ship § Outcome semantics` + `/ak-build § Phase 3 → Phase 4 handoff` | Two parts. **(D.1) Dismissal-log policy**: `dismissalLog` adversarial-reviewer must REJECT any dismissal whose underlying outcome is `blocked` — `blocked` is a tooling-gap signal, not a reviewable finding. Add a fast-path check before the LLM prompt: if the dismissed outcome is `blocked`, the dismissal is invalid and the reviewer returns FAIL with rationale "blocked outcomes cannot be dismissed via shim-map; resolve the tooling gap or report the gate as `blocked` to the caller." **(D.2) Phase 3 → 4 halt is unconditional on `blocked`**: confirm via test fixture that `blocked > 0` in the agent's return halts the pipeline regardless of whether matching dismissals exist in `review.md § Dismissals`. The two safety nets (per-gate `blocked` emission AND orchestrator-level halt count) must each independently work. |

**Verification task (high priority — feeds the fix):** home-os PR #15 (2026-05-14, feature/capture-flow) shipped with `blocked: 1` for Gate 9 `/qa` (Supabase Kong unreachable from container — pre-existing infra carry-over). The `/ak-build § Phase 3 → Phase 4 handoff` SKILL section explicitly says "If `blocked > 0` → **do NOT advance to Phase 4**." But the PR shipped — three anon-bounce placeholder hero shots embedded in the PR body in lieu of the actual feature captures, and the user only discovered post-creation when they noticed the screenshots showed the sign-in flow instead of the new features. Reproduce the failure mode: either (a) the halt path runs but the operator overrode without warning (in which case the SKILL says "Stop the pipeline. The user decides how to proceed" — the operator's continue-anyway decision was made silently), or (b) the halt path was bypassed by the `dismissalLog` / shim-map machinery treating `blocked` like a `findings` dismissal. Either is a contract gap. Fix D.1 addresses (b); a SKILL.md edit hardening the operator-override path to require explicit acknowledgement before continuing addresses (a).

**Why this lives in v0** — every project using `/ak-pre-ship` can hit this exact failure mode. Every PR that runs the gauntlet through an orchestrator subagent (which is every `/ak-build` invocation) is exposed today. The fix is small enough to ship without restructuring the pipeline; large enough that getting it wrong silently lets PRs ship without `/qa` evidence. The lalista PR #65 incident is the canonical worked example for Fixes A/B/C; the home-os PR #15 incident is the canonical worked example for Fix D. Both are codified by the structural fixes.

**Cost** — ~30 min. Three markdown edits in two SKILL.md files; one grep in the Phase 3 → 4 handoff; no script changes; no BATS tests strictly required (the new check is a single grep with anchored regex; structural-invariants.bats can be extended with one optional case asserting the grep matches a synthesized violating fixture).

**Reversibility** — each Fix lands as its own commit on devshop main. Fix A is purely additive prose; Fix B is the only behavior change (adds a halt path); Fix C is a prompt-template tightening. Reverting Fix B alone returns the pipeline to today's behavior (catches contract violations only via reading-comprehension); Fix A and C are no-cost-to-keep even if B is rolled back.

**Source.** lalista PR #65 (`fix/sync-banner-pwa-recovery`, 2026-05-12) — Phase 3 orchestrator prompt explicitly told the subagent to mark `/qa` and `/design-review` as `n/a`. User caught it mid-CI-watch ("did the pre ship happen according to the fix from today of running qa locally?") and asked for the structural fix to be added to the devshop roadmap. The fix-from-today reference is to devshop commit `c98722f` (2026-05-12 14:02 PT) which added `fast-job-local` + `preflight-final` gates — those ran correctly; the gap surfaced was a different one (LLM-mediated gate contract enforcement).

---

### Audit `kit/docs/guide/conventions.md` → distribute operational copy into the skills that fire

**Pre-implementation findings (verified 2026-05-14):** **PARTIAL.** Several destinations are already populated and the worked example (closure rule) shipped to `/devshop/CLAUDE.md` + `/ak-build § Phase 5.6`. What did NOT ship is the **deduplication** half of the audit — the table calls out 4+ sections that should drop from `conventions.md` but they're still there. Before reopening the full multi-skill audit, confirm what's actually left vs scoped-down:

- **Duplicates to delete from `conventions.md`** (CLAUDE.md is canonical):
  - `## Confidence Calibration` at `conventions.md:375-395` (table row says "Move to CLAUDE.md (Tier 1)" — already in `CLAUDE.md:130`)
  - `## TODO Protocol` at `conventions.md:397-403` (already in `CLAUDE.md:152`)
- **Lift-vs-cross-ref decision needed** for these sections — bodies are in `conventions.md`, skills only cross-ref:
  - `## Test Assertion Depth` (`conventions.md:491`, ak-tests-review only cross-refs)
  - `## SPEC.md Quality Checklist` (`conventions.md:85`, ak-spec only cross-refs)
  - `## DESIGN.md as Contract` (`conventions.md:89`, ak-pre-ship only cross-refs)
  - `## Screenshot Routing` (`conventions.md:106`, ak-pre-ship only cross-refs)
  - Pick one pattern (lift into skill OR canonical-Tier-3-with-cross-ref) and document the chosen rule.
- **Untouched rows** worth checking before scope: Backlog Routing Guide, Deploy Boundaries, Supabase Hardening Defaults, Testing Lifecycle (table rows 1006/1007/1010/1012 had non-deterministic "Verify; canonical home is the skill" actions).

**Realistic scope**: ~1 hr to land deduplication + decision, not 3-5 hr per skill. Spec below preserved for full original context.

---

**Problem.** `kit/docs/guide/` (including `conventions.md`) is loaded **on demand only** — never at session start. Skills load their own `SKILL.md` content when invoked. So a convention placed only in `conventions.md` is a paper rule: it never enters my context unless I happen to grep for it. The session that surfaced this (2026-04-26) read `/ak-build` SKILL.md's "Without this, gh run download fails" prereq line, decided artifact-pull was blocked, and never opened `conventions.md` to find the routing rule that would have told it otherwise.

**Tier model** (from the 2026-04-26 audit):

| Tier | Content                                                                        | Loaded when                                |
| ---- | ------------------------------------------------------------------------------ | ------------------------------------------ |
| 1    | `/devshop/CLAUDE.md` (+ project `CLAUDE.md` per session via SessionStart hook) | Every session start                        |
| 2    | Skill `SKILL.md` files                                                         | Only when the matching slash command fires |
| 3    | `kit/docs/guide/**`, `kit/docs/OVERVIEW.md` (incl. § Concept), `FAQ.md`        | Only when explicitly read or grep'd        |

Operational rules belong in Tier 1 (cross-cutting principles) or Tier 2 (skill-specific actions). Tier 3 is the human-browseable encyclopedia + cross-reference index.

**Audit (mapping each `conventions.md` section to its action skill, surfaced 2026-04-26):**

| Section in `conventions.md`                                           | Where it actually fires                                                                 | Current state                               | Action                                                                                                                               |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Metrics Lifecycle                                                     | `/ak-spec` (event-add gate at decision time), `/ak-build` Phase 0.2 (decisions preview) | Likely already in `/ak-spec`; verify        | Verify replication; remove from conventions.md if duplicated, OR keep conventions.md as reference + ensure skill copy is canonical   |
| Events / Feature Flags taxonomy                                       | reference taxonomy (no specific skill)                                                  | Reference-only                              | Keep in conventions.md as Tier 3 reference                                                                                           |
| TASKS.md Format                                                       | `/ak-implement` (writes the file)                                                       | Likely in `/ak-implement` SKILL.md; verify  | Verify; canonical home is the skill                                                                                                  |
| SPEC.md Quality Checklist                                             | `/ak-spec`                                                                              | Likely in `/ak-spec` SKILL.md; verify       | Verify; canonical home is the skill                                                                                                  |
| DESIGN.md as Contract (`design-conformance` (ak) gate)                | `/ak-pre-ship` Gate 3                                                                   | Likely in `/ak-pre-ship` SKILL.md; verify   | Verify; canonical home is the skill                                                                                                  |
| Screenshot Routing                                                    | `/ak-pre-ship` (screenshot capture)                                                     | Likely in `/ak-pre-ship` SKILL.md; verify   | Verify; canonical home is the skill                                                                                                  |
| Deploy Boundaries                                                     | `/ak-go-live`                                                                           | Possibly in `/ak-go-live` SKILL.md; verify  | Verify; canonical home is the skill                                                                                                  |
| Supabase Hardening Defaults (incl. `ON DELETE on auth.users` rule)    | migration time (no dedicated skill)                                                     | Reference-only                              | Lift the principles to `/devshop/CLAUDE.md § Implementation Approach`; keep details in conventions.md as reference                   |
| Confidence Calibration                                                | every decision the agent makes                                                          | Tier 3 only — paper rule                    | **Move to `/devshop/CLAUDE.md` (Tier 1)** — cross-cutting; affects every action                                                      |
| TODO Protocol                                                         | every out-of-scope discovery                                                            | In CLAUDE.md ✓ + conventions.md (duplicate) | Drop conventions.md copy; CLAUDE.md is canonical                                                                                     |
| Backlog Routing Guide                                                 | every TODO filing                                                                       | In CLAUDE.md (paraphrased) + conventions.md | Either lift the table verbatim into CLAUDE.md, or keep table in conventions.md and ensure CLAUDE.md cross-refs it                    |
| Test Assertion Depth                                                  | `/ak-test-review`                                                                       | Likely in `/ak-test-review` SKILL.md ✓      | Verify; canonical home is the skill                                                                                                  |
| Testing Lifecycle                                                     | `/ak-implement` (test-after-task discipline)                                            | Likely already there; verify                | Verify; canonical home is the skill                                                                                                  |
| Kit Testing                                                           | bash test authoring (no dedicated skill)                                                | Reference-only                              | Keep in conventions.md as Tier 3 reference                                                                                           |
| Non-Negotiables → Testing                                             | every commit                                                                            | Tier 3 only — but rule is cross-cutting     | **Lift to `/devshop/CLAUDE.md` § Non-Negotiables** (already exists there) — verify match + drop the conventions.md copy if redundant |
| Non-Negotiables → Metrics / Responsive + Theme / PWA / Code Structure | per-action gates                                                                        | Skill-resident                              | Verify each is in the right gate's skill copy                                                                                        |

**Why v0 — blocks next-project adoption:**

The first project that scaffolds the devshop today inherits a guide-conventions tree that looks authoritative but isn't load-bearing. Their first `/ak-build` run reads SKILL.md (good) and `/devshop/CLAUDE.md` (good) and never opens `conventions.md` (oops). Conventions written-but-never-followed are worse than no conventions, because they create the illusion that the agent will respect them. Fixing the placement once means future projects start with a tier model that actually fires.

**Trigger:**

- Lalista PR 26 (e2e-audit-fill-gaps) ships with the "closure rule" already moved correctly (`/ak-build` Phase 5.6 + CLAUDE.md + a one-line pointer in conventions.md). That's the worked example; the audit + sweep is the generalization.
- OR: a second project surfaces a "convention not followed" issue traceable to a conventions.md-only rule.

**Cross-ref:**

- `/ak-build § Phase 5.6` — the destination skill for the closure rule (worked example shipped 2026-04-26).
- `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — Tier 1 home for the closure rule.
- `/devshop/CLAUDE.md § Context Loading` — describes the load tiers but doesn't yet name the implication ("rules in Tier 3 don't fire").
- `/devshop/kit/docs/guide/conventions.md` — the file being audited.

**Cost/risk:**

- Implementation: ~3-5 focused hours per skill (read each skill's `SKILL.md`, identify operational rules, ensure each is restated where it fires; cross-ref conventions.md sections to confirm). Adversarial-review docs-drift will check each skill change carefully — budget review-cycle time accordingly.
- Risk: low — non-functional doc shuffling. Worst case: a temporary duplication that gets resolved on the next audit pass. No production code changes.
- Benefit: rules actually fire. Closes the "paper rule" footgun for every future devshop project.

**Adjacent v0 entry**: § Adversarial reviewer reads guide/ for convention checks (below) — the same audit's other half. They can ship as one PR (sweep skills + amend reviewer prompts in the same change) or as two — the latter is cleaner because the skill audit is more text-heavy and the reviewer change is more structural.

---

### Adversarial reviewer reads `guide/` for convention checks

**Pre-implementation findings (verified 2026-05-14):** **PARTIAL — the main mechanism shipped, the optional standalone gate didn't.** Before reopening this entry, confirm scope is still meaningful:

- **SHIPPED via `953e9a1`**: `CONVENTIONS_TO_INCLUDE` map at `kit/scripts/adversarial-review.sh:373-449` with `extract_convention_section()` helper + `get_conventions_to_inline()` dispatch + inlining loop. Currently routes `testReviewSkipReason`, `exemptAddition`, `dismissalLog` (gate-routed). Plus `WORKFLOW_TO_INCLUDE` for `coreUserStoryNaReason`. `/devshop/CLAUDE.md` documents this in present tense.
- **NOT SHIPPED**: optional standalone `kit/scripts/preship/check-conventions.sh` gate.
- **Scope shift**: the original RFC scope listed `docsReviewed` as a primary inlining target, but PR-C (the audit-time migration) REMOVED `docsReviewed` and other coverage check-types entirely — they're now `/ak-docs-review` + `/ak-tests-review` skills, which read their own guide content directly. So inlining them into adversarial-review is no longer the right shape; their convention exposure is via skill prompts, not commit-time hooks.
- **Decision needed**: either (a) close this entry — the inlining map shipped and the coverage check-types it would have wrapped have moved to a different layer; or (b) keep it open scoped ONLY to the optional standalone gate, sized at ~1 hr.

Spec below preserved for full original context.

---

**Problem.** The current pre-commit adversarial reviewers (`commit-guard.sh` + `adversarial-review.sh`) check whether **bypass reasons** are valid (e.g., is the docsReviewed note thorough? is the dirtyTreeReason load-bearing?). They don't check whether the **commit itself** follows the project's documented conventions. So a commit that adds a feature without a test, or adds a metric event without registering it in `METRICS.md`, or skips a doc update that conventions require, sails through the reviewer because the bypass-reason gate is the only checkpoint.

The agent often forgets convention X (especially one buried in conventions.md per the sibling audit above), and the reviewer doesn't catch it because it doesn't know X exists.

**Shape of the fix:**

Extend the adversarial-review prompt construction to **inline relevant `kit/docs/guide/` sections** as context the reviewer uses to flag convention violations. Two modes:

1. **Inline conventions in the existing per-flag reviewers** (cheap, additive). Each existing review (`docsReviewed`, `prDescStaleReason`, etc.) gets the relevant conventions appended to its prompt: "These are the documented conventions for this concern; flag the commit if it violates them." E.g., the `docsReviewed` reviewer gets `conventions.md § Metrics Lifecycle` and `§ Non-Negotiables → Testing`; the `prDescStaleReason` reviewer gets nothing (no relevant convention).

2. **A new "convention check" gate** that runs unconditionally on every commit (no bypass flag). Reads the diff, reads the conventions, asks the reviewer: "Does this diff follow them?" Cheaper path: only fire on commits that touch `apps/**` / `packages/**` / `supabase/**` (real code), skip on docs-only.

**Implementation surface:**

- `kit/scripts/adversarial-review.sh` — extend the prompt builder to inline guide sections by topic. Add a `CONVENTIONS_TO_INCLUDE` map keyed by review topic.
- `kit/scripts/commit-hooks/commit-guard.sh` — add a `convention-check` gate (or fold into existing gates per option #1 above).
- `kit/scripts/preship/check-conventions.sh` (new) — option #2's standalone check, invoked from pre-commit.
- `kit/tests/<corresponding>.bats` — coverage tests using fixture commits that violate / follow each convention.

**Why v0 — blocks next-project adoption:**

The whole reason `kit/docs/guide/conventions.md` exists is to encode "how this devshop wants you to work." Without an automated check, the conventions are aspirational — agents follow them when convenient and skip them when not, with no mechanism to catch the skip. New projects bring new convention pressure (mobile devshop adds touch-target rules, etc.); each new convention adds maintenance burden if it's only enforced by future-Claude-remembering. Codifying convention-check at commit-time means each documented rule is also enforced.

**Sequencing with the conventions audit (above):**

Order matters. Audit first, reviewer-check second. Reasons:

1. The audit moves operational rules out of conventions.md into skills. Once rules are in skills, the reviewer can prompt against the SKILL.md content directly (no need to inline guide/conventions.md). Conventions.md becomes pure reference (taxonomies, examples).
2. Without the audit first, the reviewer prompt would inline content that's also being moved — risky doc drift during the convention-check ship.
3. Audit also surfaces which conventions are operational (worth enforcing) vs aspirational (reference-only) — the reviewer should only enforce the former.

**Trigger:**

- Conventions audit (above) lands on devshop main.
- OR: a real "convention violation slipped through review" incident that costs an hour+ of debugging.

**Cross-ref:**

- `/devshop/kit/scripts/adversarial-review.sh` — the prompt builder to extend.
- `/devshop/kit/scripts/commit-hooks/commit-guard.sh` — the gate-orchestration point.
- `/devshop/kit/docs/guide/hooks.md` — documents the existing adversarial-review pattern; will need updates when this ships.
- Sibling entry above (conventions audit) — load-bearing prereq.

**Cost/risk:**

- Implementation: ~2-3 focused hours (prompt builder changes + new gate + bats coverage).
- Risk: false positives if the reviewer misreads convention scope (e.g., flags a "missing test" for a doc-only PR). Mitigate via narrow prompts + diff-aware filtering before invoking the reviewer.
- Benefit: documented conventions become enforced conventions, end-to-end. Closes the gap between "we wrote it down" and "the agent follows it."

---

### Migration sequencing safety nets for the Vercel-preview window

**Pre-implementation findings (verified 2026-05-14):** **PARTIAL — Track B shipped, Tracks A + C pending. ⚠️ Orphan reference exists.**

- **SHIPPED**: **Track B** (highest-leverage) at `.claude/skills/ak-go-live/SKILL.md:76-120` — Step 1.6 migration sequencing pre-flight with classification heuristic (`MIGRATIONS_TOUCHED` grep for additive vs mutating) + AskUserQuestion surface. Attributed via "Codified from kit/ROADMAP.md § Migration sequencing safety nets for the Vercel-preview window (Track B)".
- **NOT SHIPPED**: **Track A** (`/ak-spec` migration scoping prompt) and **Track C** (`kit/docs/guide/ops.md § Migration Sequencing` doc section). `grep "Migration Sequencing"` against `ops.md` returns zero matches.
- **⚠️ Orphan reference to fix**: `ak-go-live/SKILL.md:88` says "Track A of the migration-sequencing convention plants this at spec time" — but `ak-spec/SKILL.md:333` only has a "Deploy boundaries" bullet covering similar ground under a different name, with no `## Migration Sequencing` section. Step 1.6's look-for-spec-section logic will fall through silently on most projects. **Implementer must either** (a) ship Track A planting `## Migration Sequencing` under that exact name in ak-spec's section template, OR (b) rephrase ak-go-live:88 to be honest ("if `specs/<feature>/spec.md` happens to have a `## Migration Sequencing` section…").
- **Scope going forward**: Tracks A + C + the orphan-ref fix. Per the entry's own sequencing recommendation, A + C were always conditional on B firing often enough to warrant the doc/spec investment — re-check whether real cycles since 2026-05-08 ever exercised Step 1.6 before deepening.

Spec below preserved for full original context.

---

**Problem.** The lalista-style architecture pipes the same `NEXT_PUBLIC_SUPABASE_URL` (= prod) into all three Vercel envs (Production, Preview, Development) per `/ak-new-project § Step 13`, so **Vercel previews dial prod Supabase**. `deploy-migrations.yml` runs `on: push: main` — migrations apply only at merge-time, not when the PR opens. That creates a window between PR-open and PR-merge where:

- Feature branch has migration M+1 applied to its slow-job-CI local stack (`supabase start` + `supabase db reset` apply all migrations).
- Vercel preview front-end is on M+1 code, but reads prod which is still on schema M → preview is broken or surfaces wrong shape.
- Reviewer opens preview, can't tell whether what they see is a real bug or a schema-lag artifact.

The architecture's implicit assumption is that **all migrations are backwards-compatible in BOTH directions during the PR window**:

- New code on old schema must work (e.g., handles missing column with default)
- Old code on new schema must work (e.g., new NOT NULL column has a default)

Additive migrations satisfy this. Mutating migrations (renames, drops, NOT NULL without default, type changes) violate it — they break preview during the PR window.

**Why DiD doesn't fully solve this.** The pending lalista PLAN row `devshop-preship-hardening` ships DiD (`/var/run/docker.sock` bind-mount) so `supabase start` runs in the devcontainer. After that ships:

- ✅ qa-walk during dev runs against the local stack (no migration race)
- ✅ `pnpm dev` reads from local stack
- ✅ `/qa`, `/qa-only`, `/design-review` (when their separate v0 entry ships) run against local stack
- ❌ Vercel previews still hit prod (DiD is irrelevant — Vercel runs on Vercel's infrastructure)

So DiD closes the dev-side gap but not the Vercel-preview gap. This entry addresses the Vercel-preview side specifically.

**Shape of the fix** — three coordinated safety nets:

#### Track A: `/ak-spec` migration scoping prompt

When a feature spec includes a migration, the spec subagent (or `/ak-build § Phase 0` decisions preview) must ask:

> "Is this migration backwards-compatible in BOTH directions during the PR window? (a) New code on old schema works (e.g., handles missing column gracefully) AND (b) old code on new schema works (e.g., new NOT NULL column has a default)."

If yes (additive) → ship normally.

If no (mutating) → spec must include a **staged-deploy plan** under a "Migration Sequencing" section:

- Apply the migration to prod manually before merging the code PR (operator runs `supabase db push --include-roles` or triggers `deploy-migrations.yml` via `workflow_dispatch`); OR
- Document the brief preview-breakage window the team accepts during the PR review (timeboxed: "preview is intentionally broken from PR-open to PR-merge; expect <2hr").

The decision is recorded in the spec; later phases (`/ak-pre-ship` and `/ak-go-live`) cross-check.

**Edit targets:** `.claude/skills/devshop/spec/SKILL.md` (or wherever migration-scoping prompts live) — add the question + decision-tree paragraph. `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4` (Realtime publication) is adjacent but different — keep this in its own subsection.

#### Track B: `/ak-go-live § Step 1.6` migration sequencing pre-flight (do this first; highest-leverage)

Before invoking `/land-and-deploy`, if the PR diff touches `supabase/migrations/**`, classify the migration and surface the right action:

```bash
MIGRATIONS_TOUCHED=$(git diff --name-only "origin/${BASE}...HEAD" | grep -E '^supabase/migrations/' || true)
if [ -n "$MIGRATIONS_TOUCHED" ]; then
  # Read the migration file(s); classify additive vs mutating
  # Heuristic: presence of CREATE TABLE / ALTER TABLE ADD COLUMN ... DEFAULT
  # without DROP / RENAME / ALTER COLUMN SET NOT NULL → likely additive.
  # If the spec already declared the migration's compatibility in
  # specs/<feature>/spec.md § Migration Sequencing, trust that.
  ...
fi
```

If migration is **additive** → continue normally; the post-merge `deploy-migrations.yml` race is fine per the existing comment in that workflow.

If migration is **mutating** → AskUserQuestion before proceeding to merge:

> The PR's migration `<NNN>_<name>.sql` is mutating (rename / drop / NOT NULL without default). After merge, Vercel auto-deploys the front-end in parallel with `deploy-migrations.yml`; for ~30-60s prod runs new code against old schema → user-visible 500s.
>
> Options:
>
> - **Apply migration to prod first, then merge** — recommended. Run `supabase db push --include-roles` against prod (or trigger `deploy-migrations.yml` via `workflow_dispatch`); confirm prod schema is M+1; then merge the code PR. Closes the race window.
> - **Merge anyway, accept the brief breakage window** — only if the spec already documented this as an accepted trade-off (cross-check `specs/<feature>/spec.md § Migration Sequencing`).
> - **Pause and re-spec** — if the spec didn't document this, the spec author skipped Track A's check; surface the gap.

This is the **highest-leverage capture** because it catches the most dangerous case (non-additive migration about to merge with prod still on old schema) at the most actionable moment (right before merge).

**Edit targets:** `.claude/skills/devshop/go-live/SKILL.md` — add Step 1.6 between the existing Step 1.5 (prod-curl probe) and Step 2 (`/land-and-deploy`). Step 1.6 only fires when the diff touches migrations.

#### Track C: `kit/docs/guide/ops.md § Migration Sequencing` (documentation backstop)

Add a new section to ops.md documenting:

- The architecture's "additive-only during PR window" assumption (cross-ref `apps/web/.github/workflows/deploy-migrations.yml`'s sequencing-note comment as the authoritative source on the post-merge race; this section adds the pre-merge half).
- The two-phase manual deploy recipe (operator-side `supabase db push`).
- Decision tree: additive → ship normally; mutating → two-phase OR documented acceptance.
- Cross-ref to Tracks A + B as the operational enforcement points.

**Edit targets:** `kit/docs/guide/ops.md` — new `## Migration Sequencing` section (place after `## CI/CD` or wherever migration-related ops content lives).

**Why v0 — blocks next-project adoption:**

Every devshop project that adopts the Vercel + Supabase + auto-deploy-on-merge pattern (which is the default `/ak-new-project` shape) inherits this gap. Without these safety nets:

- Spec authors don't think about migration compatibility until reviewers spot it (or worse, until prod breaks).
- Operators rely on remembering to manually push migrations for non-additive changes — easy to forget.
- The Vercel preview's apparent brokenness during PR review confuses reviewers and erodes trust in the preview signal.

These three tracks codify the discipline once at the devshop level so every project gets it for free.

**Sequencing recommendation (do them in this order):**

1. **Track B first** (`/ak-go-live § Step 1.6` pre-flight). Highest leverage; catches the most dangerous case at the most actionable moment. Single SKILL.md edit, ~30 lines. If this fires often enough that the patterns become clear, escalate to Tracks A + C; if it fires rarely (because the team's migrations are mostly additive), Track B alone may be sufficient and Tracks A + C can be skipped or deferred.
2. **Track A second** (spec scoping prompt). Shifts the decision earlier — better, but requires `/ak-spec` (or Phase 0 decisions preview) to grow a new question category. Worth doing once Track B's data shows the pattern is real and frequent.
3. **Track C third** (ops.md doc). Wraps it up with the documentation backstop. Cheapest of the three (~30 min); ship after A + B so the doc references the actually-shipped operational rules rather than aspirational ones.

If the project's migration cadence is mostly additive (typical for early-stage products), **Track B alone** is sufficient and A + C can stay as "file-and-forget" reminders. The ordering preserves option value: Track B's data tells you whether to invest in A + C.

**Trigger:**

- A second project adopts the devshop and hits the migration-sequencing question on its first non-additive migration; OR
- Lalista hits a non-additive migration in PR 6 (Zod) / PR 7 (structured intent parsing) — Zod doesn't add migrations, structured intent parsing might add `quantity` / `unit` columns to `list_entries` (already exist per the v0 § 1k spec, so this is also additive). So lalista may not trigger this on its current PR queue; second-project adoption is the more likely trigger.

**Cross-ref:**

- `apps/web/.github/workflows/deploy-migrations.yml` — the sequencing-note comment in this file is the authoritative description of the **post-merge** race. This entry adds the **pre-merge** half (PR-open to merge window).
- `lalista PLAN.md row 2 (devshop-preship-hardening)` — closes the dev-side gap (DiD bind-mount, qa-walk against local stack); Vercel-preview gap remains regardless.
- `/devshop/kit/notes/roadmap/qa-options.md` — original QA-backend isolation discussion that surfaced the dev-side gap.
- `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4` (Realtime publication) — adjacent migration-discipline pattern; same migration file usually carries Realtime publication adds, so spec scoping in Track A naturally covers both.

**Cost/risk:**

- **Track B implementation**: ~1 hour (single SKILL.md edit + bats coverage if the existing pre-flight has bats). Adversarial-review docs cycles add 2-3 cycles per commit.
- **Track A implementation**: ~2 hours (spec subagent prompt extension + worked example in `kit/docs/guide/supabase-ssr-boilerplate.md`).
- **Track C implementation**: ~30 min (ops.md doc section + cross-refs).
- **Risk during rollout**: false positives in Track B's classifier (e.g., misclassifies an `ALTER TABLE` that's actually safe because of a default). Mitigate via the spec's pre-declared classification (Track A) when present; fall back to "ask the user, prefer manual two-phase" when uncertain.
- **Benefit**: catches the most dangerous migration-sequencing failure mode at the right moment; codifies the "additive-only during PR window" assumption explicitly so it's a deliberate architecture choice rather than an undocumented surprise.

**Out of scope (deferred to v1 if/when needed):**

- A **staging Supabase project** with separate Vercel preview env override + a staging-targeted `deploy-migrations.yml` variant. The full-isolation solution. Lower priority because (a) most projects accept the Vercel-preview gap as a trade-off if migrations are mostly additive, (b) it doubles the Supabase-project management overhead, (c) staging-vs-prod data drift becomes its own problem. Revisit if multiple projects adopt the devshop and report frequent Vercel-preview-broken-by-pending-migration incidents — that's the data signal that the trade-off is no longer acceptable.

---

### CI slow-job lifecycle convention — ship active from day one

Today `/devshop/template/.github/workflows/ci.yml` ships the `slow:` + `changes:` jobs entirely commented out (lines 75-113 + 142+, including the lalista-PR-26 edge-runtime health-check retry pattern). `/ak-new-project` Step 24 explicitly defers slow-job adoption to "after Phase 1c (integration tests + supabase start) or Phase 1g (Playwright E2E)" with branch-protection contexts updated from `["fast"]` to `["fast","slow"]`.

The deferral model is structurally flawed in practice: home-os PR #9 (rls-isolation.spec.ts) and PR #10 (magic-link.spec.ts) both crossed the Phase 1c/1g threshold without flipping the slow-job stub — each pre-ship raised `Gate 2c findings_pending`, each PR shipped with the finding as "infra carry-over," each next PR inherited the same gap. Home-os PR #15 (capture-flow) is now the third PR in a row with slow-job specs that aren't actually gated by CI. The deferred-until-threshold model created a structural drift loophole that operator memory cannot patch over.

**Revised shape — ship slow-job ACTIVE from `/ak-new-project` scaffold:**

The template + `/ak-new-project` should produce a working slow-job from day one, even when the project has zero integration / E2E specs to run. The slow-job is part of the new-project blocker contract alongside the fast-job, not an opt-in-later layer.

- **Template change**: uncomment the `slow:` + `changes:` jobs in `/devshop/template/.github/workflows/ci.yml`. They ship live from day one. Empty test-glob scenarios pass cleanly (no tests = no failures) — the lalista-PR-26 retry shell stays scoped to the `supabase start` step which only fires when tests actually exist.
  - The `changes:` setup-job (skip-on-docs-only filter) stays as-is per PR #29's design — a docs-only diff causes `changes.outputs.runtime=false`, the slow job's `if:` short-circuits, and the job reports `skipped` (which branch protection accepts as success). So docs-only PRs still cost ~5s for the `changes:` job, not ~8-10min for a full slow-job run.
  - The slow-job's test glob should be permissive (`apps/*/e2e/*.spec.ts`, `**/*.integration.test.ts`) so the first integration spec a project lands is automatically picked up — no glob update PR required.
- **`/ak-new-project` change**: Step 24's branch-protection setup must include `slow` (and the `changes:` job's check name, if branch protection enumerates the setup job) in the required-contexts list from day one. The current "add slow when Phase 1c crosses threshold" instruction is removed.
- **Empty-state semantics**: a brand-new project with zero E2E + zero integration tests should still see the slow-job run on every PR. It spins up Supabase, finds zero specs, reports "no tests matched glob — passed." That's intentional — the active job catches regressions when the FIRST spec lands (no manual flip), and the operator sees the job's health on every PR as ambient feedback that Supabase startup still works.
- **Convention doc** in `guide/conventions.md § Slow-Job Lifecycle`: rewrite to document the day-one-active model + the skip-on-docs-only filter contract + how to extend the test glob if the project's structure diverges from the template.
- **`/ak-pre-ship` gate** (Gate 2c): retained for projects that adopted the devshop before this convention shipped. Asserts (1) `slow:` job is uncommented, (2) `if:` references `needs.changes.outputs.runtime == 'true'`, (3) `supabase start` health-check retry is wired, (4) branch-protection contexts include `slow`. Block-on-failure with a clear remediation message. Once every active project is on the new template, this gate becomes obsolete — but keep it through the migration window so existing projects (lalista, home-os) get nudged forward.
- **Backfill PRs for existing projects**: home-os already has a TODOS row (`TODOS.md § ci-slow-job-activation`) tracking the manual flip. Lalista already has its slow-job uncommented. Once the template change ships, both projects can rebase onto the new template's CI shape (or just keep their hand-uncommented variants — the gate logic is the same).

**Why v0 — blocks next-project adoption:**

Every devshop project will adopt integration tests or E2E eventually — auth flows, Playwright happy-paths, RLS isolation specs. Three consecutive home-os PRs proved the deferred-until-threshold model doesn't survive contact with the build loop: each PR's author (Claude) cannot push `.github/workflows/**` changes because the devcontainer PAT lacks `workflow` scope, so the "uncomment slow-job" task gets routed to the human operator, who often hasn't been notified or is mid-other-work, and the gap persists. Shipping slow-job active from day one removes the routing problem entirely.

**Trigger:**

- Home-os PR #15 (capture-flow, 2026-05-13) is the third consecutive PR with slow-job specs gated on activation — the deferred model demonstrably doesn't survive a project's growth.
- Lalista's slow job is already active and includes the retry pattern. The template change extracts that shape as the default.

**Cross-ref:**

- `/devshop/template/.github/workflows/ci.yml:75-113 + 142+` — the commented-out slow-job + changes-job stubs
- `/devshop/.claude/skills/ak-new-project/SKILL.md:967-989` — the current Step 24 deferral language to remove
- `lalista/.github/workflows/ci.yml § slow:` — the live shape this convention codifies (especially the edge-runtime health-check retry)
- `home-os/TODOS.md § ci-slow-job-activation` — the recurring backlog item that this template change removes the need for
- `### Migration sequencing safety nets for the Vercel-preview window` above — adjacent CI/migration territory; both are about making CI behavior structural rather than operator-maintained

**Cost/risk:**

- Implementation: ~2–3 focused hours (uncomment template blocks + `/ak-new-project` Step 24 edit + branch-protection wiring + conventions doc rewrite + retain Gate 2c during migration window)
- Risk: low — all changes are CI/template surface, no prod data path. New projects spend ~3-5 min per PR on Supabase startup even with zero specs (cost of ambient feedback).
- Benefit: every new devshop project gets a working slow-job from PR #1 with no operator-memory dependency. The class of bug "I forgot to activate the slow-job" disappears from the failure modes.

---

### `/ak-go-live` post-merge prod-config sync (Arm B — automation core)

**Status:** Arm A (pre-flight surface) shipped 2026-05-10 via the devshop `feat/ak-go-live-arm-a-preflight` branch — `/ak-go-live` Step 1.8 reads the PR body + latest audit/ready-for-review comments, parses every `[ ]` checkbox grouped by section, annotates `[manual]` / `[deferred]` / `[!]`, and blocks on `## Out-of-band deploy items` only. Arm B (Management API integration that converts most `[manual]` items into `[auto]`) is scoped below and remains pending. The problem statement now narrows to the items Arm A surfaces but doesn't automate: the operator still pastes email templates, still verifies the auth allow-list, and still curls absolute-URL assets by hand.

**Problem.** Even with Arm A's pre-flight surface listing every pending item, the operator still types into the Supabase dashboard for each one. The recurring set:

- **Hosted Supabase email templates** (`[auth.email.template.confirmation]` + `[auth.email.template.recovery]` + `[auth.email.notification.password_changed]` from `supabase/config.toml` only auto-apply to the LOCAL stack; the prod project reads from its own dashboard). The operator logs into supabase.com/dashboard, navigates to Auth → Email Templates, pastes subject + body for each affected template by hand. Easy to forget; trivial to typo.
- **Hosted Supabase auth allow-list** (`additional_redirect_urls`). Local-stack glob patterns from `supabase/config.toml` are dev-only; prod's allow-list is configured separately on the dashboard. When a chapter changes the redirect surface (chapter 1l added `/auth/callback`), the operator verifies or updates the prod allow-list manually.
- **Static asset reachability** (e.g., `lalista-email-logo.png` referenced by absolute prod URL inside email templates). Vercel deploys it, but until verified the email might render with a broken image. A single curl confirms.

**Sibling to /ak-build Phase 5.8 + 5.9 — same family.** 5.8 catches test-coverage drift before merge; 5.9 refreshes visual evidence before merge; Arm B closes the gap AFTER merge so `/ak-go-live`'s output is a fully-deployed-and-verified state without manual paste-and-curl steps.

**Shape of the automation core.**

- **Email templates push** via Supabase Management API (`PATCH /v1/projects/<ref>/config/auth` with `mailer_subjects_*` and `mailer_templates_*` fields). Fires when the merged PR's diff touches `supabase/templates/**` or `[auth.email.template.*]` / `[auth.email.notification.*]` in `supabase/config.toml`. Reads the local files, posts the Management API call. Requires a Supabase Personal Access Token — new credential surface, separate from the service-role key used for ad-hoc admin queries.
- **Auth allow-list verification** via the same Management API (`GET /v1/projects/<ref>/config/auth`). Reads the prod allow-list, compares against the GLOB patterns in local `supabase/config.toml`'s `additional_redirect_urls` block (substituting the prod URL for `localhost` / `127.0.0.1`), warns or auto-updates depending on policy. The "auto-update" path requires user confirmation per the auto-mode-not-license-to-destroy rule — same shape as `/ak-go-live`'s existing rollback path (no auto-rollback because human judgment).
- **Static asset reachability check** via `curl -fsS https://<prod-domain>/<asset>` after Vercel reports deploy-ready. Specific to assets referenced by absolute URLs in places Vercel can't serve (email templates, third-party redirects). Reads which assets to check from a new `[ak-go-live.verify-assets]` block in the project's CLAUDE.md or `.devshop-deploy.toml` — explicit allow-list, not auto-discovery.

**Persistence**: `/ak-go-live` writes a per-run report to `specs/<feature>/go-live.md` with what ran, what passed/failed, and what's still pending. Reviewer of a future incident `git log`s `specs/*/go-live.md` to reconstruct what the deploy did.

**New credentials surface**: the Supabase Personal Access Token (`SUPABASE_ACCESS_TOKEN` env var convention) needs to live somewhere the skill reads at runtime. Two paths: (a) GH Secret + workflow-only access (skill reads via `gh secret get`); (b) operator's local `.devcontainer/.env` for local invocations + a CI run for merged-PR triggers. Recommend (a): `/ak-go-live` IS a deploy action and deploy actions belong in CI; locally it's "show me what would happen" mode without the actual prod-write authority. Same shape as `ANTHROPIC_API_KEY_PROD` today (CLAUDE.md § Anthropic API key split).

**Why this beats the obvious alternatives.**

- **"Keep pasting templates"** — Arm A's pre-flight surface already closes ~70% of forget-or-typo risk by listing the items unmissably; Arm B closes the rest by removing the manual step entirely.
- **"Use a generic `supabase config push` flow"** — the Supabase CLI doesn't have a clean equivalent for hosted projects (it's local-stack-focused). The Management API is the right shape.
- **"Roll into /ak-build Phase 7 instead of /ak-go-live"** — Phase 7 fires before the merge happens; the prod-config sync needs to happen AFTER. /ak-go-live is the correct skill.

**Why v0 — blocks next-project adoption.**

Every devshop project shipping features that touch email templates / auth allow-list / absolute-URL-referenced assets pays the manual-paste tax. Once a second project shows up, both projects pay until this lands. Closing it before that second project arrives means future projects inherit the protection.

**Trigger:**

- A second devshop project starts using `/ak-go-live` and hits the same paste-and-curl tax.
- OR: lalista chapter touches email templates / allow-list / absolute-URL assets again and the user asks to close the loop now that Arm A is shipped.

**Cross-ref:**

- `/devshop/.claude/skills/ak-go-live/SKILL.md § Step 1.8` — Arm A's surface; Arm B converts `[manual]` items it lists into `[auto]`.
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 6 § audit-comment template` — names the same items at a different lifecycle moment (just-shipped, not just-going-live); Arm B reads from this same convention.

**Cost/risk:**

- Implementation: ~6–10 hours — Management API integration (3 endpoints), credential plumbing, error handling, the per-run `go-live.md` report shape, bats tests for the auto-update confirmation flow.
- New-credential risk: the Supabase Personal Access Token has broad scope (project config write); leaking it = ability to misconfigure auth on the prod project. Same blast radius as today's `ANTHROPIC_API_KEY_PROD` (per the existing split convention) — manageable with the same CI-only + 1Password discipline.
- False-positive risk on the allow-list compare: `additional_redirect_urls` glob pattern matching is fuzzy; the safer default is "warn, don't auto-update" until the convention is exercised on a few real chapters and the failure modes are known.
- Pipeline-time risk: ~10–30 seconds for the Management API round-trips plus the curl check. Negligible.

---

### Generalize lalista PR #43's E2E + Supabase test-infra lessons to template + conventions

**Problem.** Four discrete testing-infrastructure lessons surfaced during chapter 1l's CI fix-loop are inline-documented in lalista's own files (forgot-password helper, auth-edge-cases spec) but not extracted to devshop. Every future devshop project that ships a Supabase auth flow + Playwright E2Es will rediscover all four from first principles. They cost lalista 9 CI fix-loop iterations + ~2 hours of debugging across two sessions; codifying them upstream cuts that to zero on the next project.

**The four lessons.** Each is reproducibly generic (not lalista-specific):

1. **Mailpit replaced Inbucket but Supabase CLI keeps the legacy `INBUCKET_URL` env var name.** Any devshop project using Supabase local stack with E2E helpers that need to read the mail relay hits this on Supabase CLI ≥ 2.x. The wire-level API differs (mailpit uses `/api/v1/search?query=to:<addr>`; inbucket used `/api/v1/mailbox/<addr>`). Inline doc lives at `lalista/apps/web/e2e/helpers/inbucket.ts:1-22`.

2. **Supabase's `{{ .ConfirmationURL }}` template variable renders with a bare `/verify` path on the auth host (port 54321) instead of the Kong-prefixed `/auth/v1/verify`.** Browsers follow the bare URL fine because they handle Kong's redirects, but `page.goto(link)` in Playwright 404s with "no Route matched." Affects any project that drives Supabase recovery/confirmation links via Playwright. Inline doc + the `rewriteBareVerify` function lives at `lalista/apps/web/e2e/helpers/inbucket.ts:108-128`.

3. **WebKit React-hydration race on controlled inputs.** `page.locator('#input').fill(value)` can resolve before React's state syncs back to the DOM `value` attribute on a freshly hydrated controlled input. The result: `fill` reports "value set", the next interaction observes the field as empty, the form submits with missing data. Reproduced identically across three CI runs in PR #43 (25258858879 / 25259626169 / 25260400981) before the fix landed. Robust pattern: `click + pressSequentially(value, { delay: 10 }) + expect().toHaveValue(value)` — real keystrokes give React time to settle, the value-equality assert auto-retries. Affects any Playwright + React project, not Supabase-specific. Inline doc at `lalista/apps/web/e2e/forgot-password.spec.ts:73-89`.

4. **Two-shape signup behavior depending on `[auth.email].enable_confirmations`.** When TRUE (prod's typical posture): Supabase returns `{ user: { identities: [] }, session: null }` for an existing-account second-signup — the no-enumeration shape. The app's /sign-up page can branch into AwaitingConfirmationCard, indistinguishable from a fresh signup. When FALSE (auto-confirm; CI's typical posture): Supabase returns an explicit `User already registered` error and the app's friendly-error mapping renders "already registered, try signing in instead." E2E tests on local stack (auto-confirm) exercise the visible-error path; unit tests should mock the prod shape to pin the no-enumeration parity. Inline doc at `lalista/apps/web/e2e/auth-edge-cases.spec.ts:155-174`.

**Shape of the convention.**

- **Lessons 1 + 2 → template helper file.** Ship `template/apps/web/e2e/helpers/inbucket.ts` (or whatever the canonical mail-relay helper is named for new projects — "inbucket.ts" preserves Supabase's env-var name; fine to keep) as part of the standard E2E scaffold. New projects scaffolding from the template inherit a working helper on day 1. The file's own docstring explains why the name is misleading + the bare-/verify rewrite. Pure code; no convention prose needed beyond what's in the file. **Canonical implementation now lives at `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 9`** (lifted verbatim from lalista's mature helper during home-os PR #15 — adds `deriveMailpitBase()`, wider regex, 6-entity decode, three-function API). When the `template/apps/web/` baseline lands, copy that pattern body into `template/apps/web/e2e/helpers/inbucket.ts` verbatim.

- **Lesson 3 → convention + skill amendment.** Convention prose lives at `kit/docs/guide/conventions.md § Playwright + controlled inputs on WebKit`. The rule: for forms with controlled inputs whose values are read at submit time (login, password reset, anything with `<input value={state} onChange=...>`), prefer `pressSequentially` over `fill` when targeting WebKit. One-line callout in `/ak-pre-ship` Gate 9 (QA walks) so it fires at the right moment.

- **Lesson 4 → convention + (optionally) template scaffold.** Convention prose at `kit/docs/guide/conventions.md § Supabase auth E2E patterns` covering: how to test the no-enumeration shape (mock at the unit level with `identities: []` + null session), how to test the auto-confirm shape (E2E against local stack), why the test-layer split is correct. If template ships any auth E2E examples, mirror this dual-layer pattern.

- **Cross-link from `kit/ROADMAP.md § Auth UX conventions`** (the existing v0 entry that extracts `AwaitingConfirmationCard` + `friendlyAuthError`). That entry is about UX components; this one is about test infrastructure. They pair naturally — UX work without test-infra produces flaky lessons-by-rediscovery loops.

- **Implementation order:** ship the template helper file FIRST (lessons 1 + 2 are pure code, easiest to verify), then the conventions (lessons 3 + 4 are prose, easier when there's a template helper to reference). One PR per lesson keeps the diff small; or one PR for the helper file + one for the conventions.

**Why this beats the obvious alternatives.**

- **"Just leave it inline in lalista"** — works for lalista (we wrote it; we'll find it), fails for the next project (they'll rediscover all 4 from first principles, costing ~2 hours each). The whole point of the template + conventions is to compound learning across projects.
- **"Wait for a second project to surface the gap"** — the Auth UX conventions entry already has this exact sequencing (extract after lalista soaks). Lessons 1-3 are technical and don't benefit from soak; the helper either works or doesn't. Lesson 4 might benefit from soak (the no-enumeration UX trade-off has UI implications worth seeing in production), but the convention prose can ship now and refine later.

**Why v0 — blocks next-project adoption.**

A second project shipping Supabase auth without these four lessons in template + conventions will hit them. Lessons 1 + 2 cost ~30 minutes each to debug from scratch (you need the trace.zip to see the URL form). Lesson 3 cost lalista a 9-iteration CI fix-loop because the symptom (test fails on WebKit, passes on Chromium) reads as flake. Lesson 4 is design-trade-off shaped (you need to KNOW about the two shapes to test correctly); without the convention, projects ship the wrong test layer and miss bugs.

**Trigger:**

- Lalista PR #43 just landed (2026-05-05); lessons are fresh. Ship the template helper this week.
- Conventions can be drafted alongside; pair-review with a future devshop project's auth flow as the validation pass.

**Cross-ref:**

- `lalista PR #43` (chapter 1l, merged 2026-05-05). The four files where the lessons currently live.
- `kit/ROADMAP.md § Auth UX conventions` — UX-side companion entry; pair these two to ship.
- `/ak-build` Phase 5.8 (shipped 2026-05-05) — the post-pre-ship audit re-runs `/ak-test-review` over the polish range; that's the gate where the "did you remember to use pressSequentially?" question fires (the WebKit convention below should be inlined into `/ak-test-review` so the audit catches violations).
- `kit/scripts/commit-hooks/check-test-coverage-project.sh` — the Layer-1 test-presence hook; the Layer-2 conventions ride on top.

**Cost/risk.**

- Template helper file: ~1 hour — copy lalista's file verbatim, generalize the comments, drop in `template/apps/web/e2e/helpers/`. Mirror in `template/apps/web/e2e/sign-up.spec.ts` + `forgot-password.spec.ts` skeletons that consume it.
- WebKit conventions: ~1 hour — prose in `kit/docs/guide/conventions.md` + the one-line callout in `/ak-pre-ship` SKILL.md.
- Two-shape signup convention: ~1 hour — prose + a small worked example in conventions.md.
- Total: ~3 hours for all four lessons. False-positive risk: zero (these are well-validated patterns from a 9-iteration debug loop).

---

### Auth UX conventions — shared error-surface + state patterns

Projects using Supabase auth keep re-solving the same UX gaps because there's no shared convention. Lalista surfaced two that every hosted-Supabase auth flow hits:

1. **Unconfirmed-signup silent bounce** — `mailer_autoconfirm: false` (default) makes a successful signup return no session. If the client immediately routes to an authed area, middleware redirects the unconfirmed user back to `/sign-in` with no feedback. Looks broken.
2. **Raw Supabase error strings leaking to users** — messages like "Invalid login credentials" / "Email rate limit exceeded" / "User already registered" are developer-facing. Users read them as "what does this mean?"

Both were fixed ad-hoc in lalista (commit `31b5637` on `feature/auth`: new `awaitingConfirmation` state + `friendlyAuthError()` helper). Every next project will hit the same gaps.

**Shape of the convention (not final):**

- **Package**: a thin `@devshop-template/auth-ux` helper module (or inline pattern in the template's sign-in page) providing:
  - `AwaitingConfirmationCard({ email, onBack })` React component — standardized "Check your email" UI
  - `friendlyAuthError(message: string): string` — normalizes Supabase error strings to user copy. Exhaustive coverage of the ~6 common cases (`invalid_credentials`, `email_not_confirmed`, `email rate limit exceeded`, `user already registered`, `over_email_send_rate_limit`, `signup disabled`). Unmapped messages pass through unchanged (safe default).
- **Convention doc** in `guide/conventions.md § Auth UX Conventions` with:
  - When to show awaiting-confirmation vs. sign-in-error UI
  - Error-copy style guide (user-action-oriented, not dev-state-oriented)
  - Email enumeration vs. UX-clarity trade-offs (projects pick a stance; document which one they picked)
- **Template sign-in page**: the lalista-auth-feature scaffold (or its successor) includes the pattern out-of-the-box so projects don't rediscover it.
- **Test helpers**: a standardized `e2e/helpers/auth-ux.ts` that exercises the awaiting-confirmation path, rate-limit path, wrong-password path — pairs with the "user-state matrix" expansion to Step 2's Fix C (QA walks must exercise more than the admin-API happy path).

**Password-reset sub-pattern (required for the full story):**

Surfaced 2026-04-20 while testing PR #10 on the Vercel preview. Supabase's dashboard "Send password recovery" email links to `<site_url>/#access_token=...&type=recovery`; if the project has no callback route to land on, the link hangs. Every Supabase project needs this plumbing.

- **`PasswordResetCard` component**: email input → `supabase.auth.resetPasswordForEmail(email, { redirectTo: <callback URL> })` → success state ("Check your email for a reset link"). Lives in the same `@devshop-template/auth-ux` module as `AwaitingConfirmationCard`.
- **`/auth/callback` route** (RSC + Route Handler hybrid): reads `code` query param, calls `supabase.auth.exchangeCodeForSession(code)` server-side, then redirects based on `type` (`recovery` → `/reset-password`; `email_change` → `/settings`; default → `/`). Sets the session cookie so subsequent requests are authed. **MUST anchor every redirect target on `request.headers.get('host')`, not `new URL(path, request.url)`** — Next.js 16 normalizes `request.url`'s hostname to its configured HOSTNAME (defaults to localhost) regardless of the actual Host header. Cookies set on the request host don't cross-send to the normalized redirect host, breaking the callback chain in CI/local even though prod (Vercel terminating TLS upstream with the canonical Host) masks the bug. Canonical helper at `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 10` (`sameOriginUrl(request, path)`); same fix applies to `/auth/signout` if the project ships a server-side signout route. Surfaced during home-os PR #15 slow-job rollout.
- **`/reset-password` route**: form to set a new password (validated against `password_min_length`). Calls `supabase.auth.updateUser({ password })` on submit — works because the callback already set a session. On success, push to `/` (or `/onboarding` if the user has no household).
- **Required Supabase config** (must be set at `/ak-new-project` time — see the `/ak-new-project` Phase B auth-hardening step):
  - `site_url` = production URL (e.g., `https://app.vercel.app`) — **NOT** `localhost:3000` (the free-tier default). Recovery emails embed this; a wrong value makes every reset link hang.
  - `uri_allow_list` includes: production URL, Vercel preview wildcard (`https://*-<team>.vercel.app/**`), and `http://localhost:3000/**` for dev. Without this, `redirectTo` values get rejected.

**Why v0 — blocks next-project adoption:**

Combined with the auth-hardening step (password_min_length: 8, landed in v1.11.0) and the invite-code signup (v1 entry below), this completes the "serious project auth out of the box" story. Waiting means every project gets an ad-hoc implementation. Lalista is example #1 with the `awaitingConfirmation` state and `friendlyAuthError()` function; lalista has a `TODOS.md § auth-ux-refactor-to-adopt` entry standing by to adopt the helper once it ships, which also verifies the helper works in practice.

**Trigger:**

- Second project adopts the devshop and hits the same silent-bounce bug (almost guaranteed)
- OR: lalista's implementation gets iterated on twice — the 3rd refinement is the signal to factor up
- OR: lalista clears its `auth-ux-refactor-to-adopt` verification debt as soon as the helper ships (current plan)

**Cross-ref:**

- Lalista commits `31b5637` (fix) and sign-in page.tsx / page.test.tsx — the concrete prior art
- Lalista `TODOS.md § v0 § auth-ux-refactor-to-adopt` — the refactor-to-adopt TODO that verifies the helper when it ships
- The `/ak-pre-ship` Gate 9 user-state matrix (landed in devshop v1.11.0) — the QA-side pair of this UX-side convention

---

### Latency feedback framework — 4-tier decision rule + primitives

**Pre-implementation findings (verified 2026-05-14):** **PARTIAL — skeleton doc shipped, rest pending.**

- **SHIPPED via `a9f364d`**: `kit/docs/guide/latency-feedback.md` exists (212 lines). Self-described as "focused stub; full 4-tier framework scheduled to lift post-soak."
- **NOT SHIPPED**: full 4-tier framework prose (the canonical content still lives in `lalista/specs/app-snappiness/spec.md § D1`); `template/CLAUDE.md` pointer to the guide; `/ak-spec` consultation step in `.claude/skills/ak-spec/SKILL.md`; primitives extraction (`useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation`) to a `@devshop-template/ui` package.
- **Blocked by**: primitives extraction is blocked by the missing `template/apps/web/` baseline (see new ROADMAP entry below) — there's no `template/packages/ui/` either; both need the template app scaffold first.
- **Realistic next step**: lift the 4-tier prose from lalista's spec into the existing `latency-feedback.md` (~30 min) + add `template/CLAUDE.md` pointer (~5 min) — these are pure doc, no scaffold dependency. Primitives extraction waits on the template baseline.

Spec below preserved for full original context.

---

Projects keep re-solving the same UX gap: how snappy to make a button / a route nav / an optimistic mutation. Defaults skew either too eager (spinner everywhere, including <250ms ops where it's noise) or too lazy (no feedback, user double-taps). Lalista chapter 1m (`feat/app-snappiness`, PR #49, shipped 2026-05-07) co-developed a 4-tier framework with the user that matches the affordance to the operation's actual latency. Every next project with interactive UI will hit the same decision tree.

**The framework** (lalista's `specs/app-snappiness/spec.md § D1` is canonical until this lifts):

- **5-tier table** (A1 / A2 / B / C / D) — pick by latency + whether we have local state to commit optimistically + whether failure is self-explanatory in context.
- **Decision rule** for picking a tier when adding a new interactive surface.
- **Primitives** (live in `lalista/packages/ui/`, ready to lift):
  - `useSubmitFeedback` — Tier B's 250ms-threshold spinner timer + cleanup state machine.
  - `SubmitButton` — Tier B affordance built on `useSubmitFeedback` + `Button`.
  - `LoadingArea` — Tier C placeholder (soft `animate-pulse` on `bg-muted/40`).
  - `useOptimisticMutation` — Tier A1/A2 hook with `failureMode: 'rollback' | 'banner'` discriminated union, retry sequence with budget check, banner state with retry/undo/dismiss callbacks.
- **Tokens**: `FEEDBACK_THRESHOLD_MS = 250`, `RETRY_BUDGET_MS = 15000`, `RETRY_BACKOFF_MS = [1000, 3000, 7000]`.
- **Load-bearing implementation detail (preserve verbatim if you fork)**: Tier A's `useOptimisticMutation` rollback uses `queueMicrotask` so the optimistic frame paints BEFORE the rollback's setState. React 19's auto-batching otherwise elides the visible "row appeared then disappeared" frame and the user sees no feedback at all. Same pattern lalista's `ListClient.handleAddResponse` realtime-merge race uses. Test coverage in `useOptimisticMutation.test.ts`.

**Implementation surface:**

- `kit/docs/guide/latency-feedback.md` (new) — full framework prose: 5 tiers, decision rule, retry-budget shape, queueMicrotask gotcha, worked examples (generic surfaces, not lalista-specific). Becomes the ground truth.
- `template/CLAUDE.md` — short pointer: "when adding a surface with feedback needs, see `kit/docs/guide/latency-feedback.md`." So new projects inherit by default.
- `.claude/skills/devshop/spec/SKILL.md` — `/ak-spec` consults the guide when the spec involves interactive UI or async ops; spec author produces a project-specific surface tier mapping table as part of `## Decisions` (same shape as PR #49's spec § D1, just systematic).
- **Primitives extraction** (separate PR after the framework doc lands and lalista soaks): lift `useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation` from `lalista/packages/ui/` to a `@devshop-template/ui` package. Lalista refactors to import from the package, deletes the inline copies.

**Why v0 — blocks next-project adoption:**

Same playbook as Auth UX conventions above. Every project with interactive UI hits the same decision tree; without the convention, every project re-derives ad-hoc spinners, miscalibrates the 250ms threshold, or skips optimistic UI entirely because the rollback timing is non-obvious (the React 19 auto-batching gotcha is the load-bearing detail nobody discovers until they ship it). Factoring up now avoids each project re-inventing the wheel.

**Trigger:**

- 2-4 weeks after lalista chapter 1m ships (2026-05-07) — gives the patterns time to surface real-world quirks before extraction. Same "ship inline → soak → extract" sequencing chapter 1l followed.
- OR: a second project adopts the devshop and the operator pushes back on "no convention for tap feedback" (almost guaranteed once anyone ships interactive UI).
- OR: lalista clears its `PRODUCT-ROADMAP.md § v1 § Devshop extraction of validated UX patterns` row by adopting the lifted primitives — the natural verification step.

**Cross-ref:**

- `lalista/specs/app-snappiness/spec.md § D1` — canonical framework + decision rule until this lift makes the devshop guide canonical. Source for the 5-tier table.
- `lalista/CLAUDE.md § Latency feedback tiers` — currently carries the 5-tier table, decision rule, and a lalista-specific surface mapping. After this lifts, lalista CLAUDE.md trims to just the surface mapping with a pointer to `kit/docs/guide/latency-feedback.md`.
- `lalista/DESIGN.md § Motion + feedback` — token values; lifts alongside the components.
- `lalista/PRODUCT-ROADMAP.md § v1 § Devshop extraction of validated UX patterns` (line 347) — the soak-reminder counterpart on the lalista side.
- `lalista/packages/ui/src/{useSubmitFeedback,SubmitButton,LoadingArea,useOptimisticMutation}.{ts,tsx}` — concrete prior art ready to lift.

**Cost/risk:**

- Implementation: ~30 min for the guide doc + ~15 min for the `/ak-spec` SKILL amendment + ~1-2h for the primitives extraction PR (separate, post-soak). Total ~2-3 focused hours across two PRs.
- Risk of premature extraction is the main cost of NOT waiting for the soak; once we've waited, the patterns have already proven themselves on real users. Lalista's CI fix-loop on PR #49 surfaced 4 fix-loop iterations worth of edge cases (overlay-z-index intercept on banner Retry/Undo, React batching defeats observable optimistic frame, schema-drift footguns in test queries) — the doc + primitives codify those lessons so the next project doesn't rediscover them.

[v0, surfaced-by lalista-PR49, 2026-05-07]

### Template PWA service worker baseline

The template ships a PWA manifest + meta tags out of the box (apple-touch-icon, viewport-fit=cover, standalone, start_url), which is enough to install — but it does NOT ship a service worker. Every PWA-shaped project will hit the same soak finding: iOS cold-launch feels slow because every fresh WebView process pays the full server-roundtrip cost (middleware token refresh + RSC fetches + client mount + realtime handshake) before first paint. Lalista's polish PR #68 (2026-05-13) parallelized the two server fetches in `/list/page.tsx` via `Promise.all` — the largest cheap win without a SW — but the user can still feel the difference between "warm WebView" and "cold WebView." From here the next lever is HTML caching via SW, and that pattern is general (every PWA-shaped project will want it).

**The pattern** — same shape as Auth UX conventions / Latency feedback framework: lalista soaks the implementation first, devshop extracts the convention once the edges are known. Lalista's `PRODUCT-ROADMAP.md § PWA service worker caching` carries the project-side row; this row is the template-side counterpart.

**Shape of the fix:**

- **Implementation library**: `@serwist/next` (the de-facto Next.js 15 PWA SW story). Add to `template/apps/web/package.json` as a dep; wire `next.config.ts` per the serwist docs.
- **Default caching strategy**: stale-while-revalidate for HTML (so cold-launch paints last-known content immediately + refetches in background), cache-first for static assets, network-only for `/api/**` + Supabase calls. The HTML SWR is the cold-launch lever.
- **Versioning**: serwist's `precacheManifest` regenerates on each build; updates propagate on next page nav after the new SW activates. Document the "tab close + reopen" worst-case staleness window in the convention so operators understand it.
- **Dev-mode behavior**: SW disabled in dev (or self-unregistering) — cached assets during HMR cycles is its own footgun.
- **Real-device validation**: a CI gate can't fully prove the win (headless Chromium doesn't model iOS WebView-process-reap cold-launch); the convention should require post-merge `/canary` to hit the production PWA from a real device and confirm.

**Implementation surface:**

- `kit/docs/guide/pwa-service-worker.md` (new) — full convention prose: caching strategies per asset class, versioning behavior, dev disable, real-device validation requirement, "what NOT to cache" list (Supabase calls, edge functions, `/auth/callback`).
- `template/apps/web/next.config.ts` + `template/apps/web/app/sw.ts` (new) — the serwist registration + precache manifest config, parameterized so projects can override the cache lists.
- `template/CLAUDE.md` — short pointer: "PWAs ship with a default SW per `kit/docs/guide/pwa-service-worker.md`; customize cache lists in `apps/web/sw.ts`." So new projects inherit by default.
- `.claude/skills/devshop/new-project/SKILL.md` — `/ak-new-project` Step N: ask "is this a PWA?" If yes, scaffold the SW config from the template; if no, skip (CLI tools / pure SPAs / SSR sites that aren't installed).
- `.claude/skills/devshop/pre-ship/SKILL.md` — pre-ship gate that lints the SW config for known footguns (e.g., caching `/auth/callback` would break magic-link flows; caching `/api/**` would hide DB writes from the user).

**Why v1 — soak-extract pattern, not blocking:**

Same playbook as Auth UX conventions / Latency feedback framework. The pattern needs lalista's SW implementation to ship first so the convention extracts from real lessons rather than aspirational design. Lalista's polish #68 parallelization is the last cheap win pre-SW; the next lalista PR that adds SW is the trigger to extract the convention here. Until then, projects that need a SW point at lalista's eventual implementation.

**Trigger:**

- Lalista clears its `PRODUCT-ROADMAP.md § PWA service worker caching` row by shipping a serwist-based SW.
- OR: a second devshop project adopts the template + is a PWA + hits the same cold-launch soak finding (which is the natural verification step).

**Cross-ref:**

- `lalista/PRODUCT-ROADMAP.md § PWA service worker caching` — the project-side counterpart with the cold-load context surfaced by polish PR #68.
- `lalista/apps/web/public/manifest.json` + `lalista/apps/web/app/layout.tsx` — the installability scaffolding that's already template-level; the SW lives one layer up.
- `lalista/apps/web/middleware.ts` + `lalista/apps/web/app/list/page.tsx` — the boot-path roundtrips a SW would short-circuit.

**Cost/risk:**

- Implementation: ~1h for the convention doc + ~1h for the template wiring + ~30 min for the `/ak-new-project` branch. Total ~2-3 focused hours, plus the upstream lalista SW PR (~half a day for caching strategy + real-device validation).
- Risk of premature extraction is the main cost of NOT waiting for the soak; cache invalidation is a classic footgun and the wrong default lasts forever (users keep stale HTML after deploys; the realtime channel + cached page disagree on the truth; etc.). Lalista's soak surfaces those edges before they become a template default.

[v1, surfaced-by lalista-polish-PR68-2026-05-13]

---

### Post-home-os onboarding learnings — skill / template / convention polish batch

Home-os was the SECOND project to bootstrap from the devshop template via `/ak-new-project` (lalista was first). Steps 0–25 ran across two sessions (2026-05-12 + 2026-05-13). 12 generalizations surfaced beyond the four critical template fixes already tracked in `PLAN.md § #4 (home-os-onboarding-template-patches)` + `#5 (firewall-extras-overlay-merge)`. Each generalization is small (15–60 min). They're grouped here as one ROADMAP entry so a single focused session can pick three or four at a time without context-switching across surfaces. Order is roughly "blast radius descending" — the first few hit every new scaffold; the last few are niche.

**Source detail:** `kit/notes/projects/home-os.md § "2026-05-13 session — devshop generalizations to surface"` carries the per-incident narrative for each item (#19–#30). When in doubt, read the tracker entry — it has the exact symptoms + the moment the generalization surfaced.

#### A. Skill text fixes (`/ak-new-project § Step <N>`) — sub-hour, one PR per sub-bundle

- **(A1) Step 13 `--token` echoes its value in CLI error JSON (gen #20)** — `vercel link --token $VERCEL_TOKEN` and `vercel env add --token $VERCEL_TOKEN` echo the resolved token in JSON error responses (e.g., when `--scope` is ambiguous). The token reaches stdout, then conversation log, then potentially session transcripts. `VERCEL_TOKEN` blast radius is "deploys to any of your Vercel projects." **Fix**: skill's Step 13 example loop sets `export VERCEL_TOKEN=…` once at the top instead of passing `--token` on every line; OR every example pipes through `sed 's/vcp_[A-Za-z0-9]*/vcp_***/g'`. Prefer export-once — eliminates the surface entirely. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 13`.
- **(A2) Step 14 `sudo apt-get install-deps chromium` is unnecessary (gen #22)** — the template's `.devcontainer/Dockerfile` already installs Chromium runtime deps. After `pnpm exec playwright install chromium`, a smoke test (`chromium.launch()` against `about:blank`) succeeds without sudo. The skill's prescribed `sudo npx playwright install-deps chromium` line wastes a sudo prompt and the apt-get cycle. **Fix**: change Step 14 from "run install-deps" to "verify chromium.launch succeeds via a one-liner smoke test; if it fails, run install-deps as fallback". **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 14`.
- **(A3) Step 3 should include Vercel GitHub Login Connection sub-bullet (gen #25 + #29)** — `vercel link --yes --project home-os` succeeded writing `.vercel/project.json` but emitted `Error: Failed to link meirmsn/home-os. You need to add a Login Connection to your GitHub account first.` even though the GH App was installed at org level. Until the operator visits `vercel.com/account/login-connections` and adds GitHub, auto-deploy on push:main does NOT fire (the API-level link exists, but the per-account Login Connection that bridges Vercel → GH personal account doesn't). Additionally (#29), Vercel team default for new orgs is `ssoProtection.deploymentType = all_except_custom_domains` — the team-canonical `<project>-<org>.vercel.app` alias gets SSO-gated by default; only the auto-allocated nu-two-style aliases stay public. **Fix**: skill Step 3 (Vercel account creation) gets two new sub-bullets: (i) "Add GitHub at `vercel.com/account/login-connections` BEFORE you proceed to Step 13's `vercel link` — otherwise that command warns and auto-deploy won't fire." (ii) "Check `vercel.com/{team}/{project}/settings/deployment-protection` — if SSO Protection is set to `all_except_custom_domains` (the team default), the canonical alias will sign-in-gate; for a public-facing PWA either disable SSO on production or treat the auto-allocated nu-two-style alias as the public URL (the latter is what home-os shipped with)." **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 3`.
- **(A4) Step 17 prefix `gstack-config set` defaults before invoking `/setup-deploy` (gen #27)** — `/setup-deploy` (and every gstack skill) has a 5-prompt preamble: gstack-upgrade check, Boil-the-Lake intro, telemetry, proactive, routing rules. Five interruptions before the skill does deploy config. For `/ak-new-project` use, sensible defaults are: telemetry=off (privacy), proactive=true (default), routing_declined=true (project CLAUDE.md design principle: no devshop cross-refs), lake intro marked seen, gstack-upgrade snoozed (major-version jumps deserve isolated sessions). **Fix**: skill Step 17 prepends a `gstack-config` batch that pre-answers those five prompts so the operator/agent never sees them. Idempotent (touch the marker files + set the configs). Where the binary lives matters — see (A5) below. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 17`.
- **(A5) gstack binary path: `~/.claude/skills/gstack/bin/...` vs project-local `/workspace/.claude/skills/gstack/bin/...` mismatch (gen #28)** — gstack-init in Step 9 clones to `.claude/skills/gstack/` (project-local), but every gstack SKILL.md hardcodes `~/.claude/skills/gstack/bin/<binary>`. The home dir path doesn't exist; the SKILL.md preambles call `gstack-config`, `gstack-update-check`, `gstack-timeline-log`, etc. and they all silently no-op. Daily use isn't affected (the skill survives the no-ops) but anything that DEPENDS on the helpers misfires. **Fix candidates** (pick one): (i) symlink `~/.claude/skills/gstack` → project-local during Step 9 init (cheap; ~3 lines in the setup script); (ii) update gstack's setup to install to `~/.claude/skills/` by default (changes gstack-side, affects upgrade path); (iii) SKILL.md preambles resolve via `$_ROOT/.claude/skills/gstack/...` first with `~/...` fallback (this is what the `browse` SETUP block already does; pattern is `B=""; [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/..."; [ -z "$B" ] && B=~/...`). **Note**: this overlaps with `PLAN.md § #2 (gstack-helper-path-resolution)` and `#3 (gstack-artifact-path-resolution)`. If those land first, this is closed. Otherwise: ship the symlink-on-Step-9 fix as a one-line workaround that doesn't depend on gstack-side changes. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 9` for the symlink fix; the deeper SKILL.md preamble fix is in `PLAN.md § #2 / #3`.

**Sub-bundle A acceptance**: shipped as one PR (`fix/ak-new-project-skill-polish`) with 5 commits, one per A1..A5. Each is a SKILL.md edit + (optional) skill-tests bats expectation. ~45–60 min.

#### B. Convention / template fixes — sub-hour, one PR each

- **(B1) Pre-commit clean-tree guard forbids stashes too (gen #21)** — when splitting commits via `git stash push <subset>` + `git commit` + `git stash pop`, the second commit step fails with `Stashed changes on current branch — address them before committing`. The hook treats stashes as "uncommitted work." Workaround used in home-os: combine the logical groups into one atomic commit with sectioned message, OR use `git -c devshop.dirtyTreeReason="..." commit`. **Severity: low** — friction more than correctness — but the clean-tree-no-stash invariant is non-obvious and operators learn it the hard way. **Fix**: document in `/devshop/CLAUDE.md § Two repos, two commit flows` (and project CLAUDE.md scaffold templates) that "atomic commits MUST be one transition each — stash-then-commit will trip the guard. To split: combine into one commit with sectioned message, OR use the `devshop.dirtyTreeReason` opt-out with a real justification." **Where**: `/devshop/CLAUDE.md`. ~10 min.
- **(B2) Next 16 `middleware.ts` → `proxy.ts` deprecation (gen #24)** — `pnpm build` in apps/web emits `⚠ The "middleware" file convention is deprecated. Please use "proxy" instead.` (https://nextjs.org/docs/messages/middleware-to-proxy). The Supabase SSR boilerplate guide at `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 1` AND the template's `apps/web/middleware.ts` scaffold still use the deprecated name. Functional in Next 16 (warning only) but will harden into an error in Next 17. **Fix candidates**: (i) proactively rename the template + the supabase-ssr-boilerplate.md § Pattern 1 from `middleware.ts` to `proxy.ts` now, so new projects start on the supported convention; (ii) defer until Next 17 release, then rename. Prefer (i) — the rename is mechanical (one file move + one SSR boilerplate text change) and stops accumulating projects on the deprecated convention. **Where**: `template/apps/web/middleware.ts` → `template/apps/web/proxy.ts` (file move) + `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 1`. ~15 min.
- **(B3) Pre-commit clean-tree guard's PR-desc-stale check is sensitive to bypass reason quality (gen — observed this session)** — when the PR body genuinely matches the commits and the reviewer is asked to PASS via path (a) of the prompt, the reviewer can still FAIL the bypass if `BYPASS_REASON` is `"no reason given"` (the default when no `devshop.prDescStaleReason` config is set). The reviewer's prompt says "Default position: REJECT bypass reasons" — so an empty reason gets penalized even when the description is current. **Fix**: when the operator goes through `gh pr edit` and the PR body now covers all commits, the pre-push hook should re-run a fast path-(a) check (compare PR body's commit-SHA enumerations against `origin/main..HEAD` SHAs) and short-circuit-PASS before invoking the adversarial reviewer. OR: the reviewer prompt should explicitly score on path-(a) FIRST (description match) and only consult `REASON` on path-(b) (structural-delay justification). Current state: the operator has to write a specific bypass reason ("PR body just updated via gh pr edit; commits X, Y, Z are at lines N, M, P") every time, which is friction. **Where**: `/devshop/kit/scripts/adversarial-review.sh` + `/devshop/kit/hooks/pre-push.sh` § "Check 2: PR description staleness". ~20 min. **Severity: low** — friction more than correctness.
- **(B4) Next 16 `allowedDevOrigins` template default — required for Playwright / `/qa` driving via either `localhost` or `127.0.0.1` (added 2026-05-15 after home-os PR #15)** — Next 16 blocks cross-origin HMR + dev-resource fetches by default. The dev server prints its "Local" URL as `http://localhost:3000`, so a Playwright / `/qa` script driving via `http://127.0.0.1:3000` (or vice versa) gets HMR-blocked. Symptom: static HTML renders fine, but React hydration never fires — interactive elements (form `onSubmit` handlers, click handlers) never attach. Home-os PR #15 hit this debugging the magic-link round trip: the `/login` form submitted as plain `GET` because `onSubmit` was never bound. Surface error message is the dev-log warning `⚠ Blocked cross-origin request to Next.js dev resource /_next/webpack-hmr from "127.0.0.1"` — easy to overlook. **Fix**: template's `apps/web/next.config.ts` defaults to `allowedDevOrigins: ['localhost', '127.0.0.1']` so Playwright / `/qa` driving via either hostname passes. Document the rationale inline: Supabase auth issues URLs rooted at `127.0.0.1` per `site_url`, while Next 16 prefers `localhost` for HMR — both must be allowed so the round-trip flow doesn't drop hydration. **Where**: `template/apps/web/next.config.ts` (after the template-apps-web-baseline scaffold lands; until then, document in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 10` as a corollary to the localhost-vs-127.0.0.1 narrative). ~10 min for the template edit + ~5 for the boilerplate cross-ref. **Severity: medium** — every Playwright-driven gate on a project that doesn't ship this default trips on it; the symptom (form submits as GET) takes a while to diagnose without the cross-origin block being top-of-mind.

#### C. Template / manifest fixes — sub-hour, one PR

- **(C1) CI Node 20 vs pnpm-11 Node-22 requirement (gen #30)** — `template/.github/workflows/ci.yml` pins `node-version: '20'` but `pnpm/action-setup@v3 with version: latest` resolves to pnpm 11.x at the runner, which imports `node:sqlite` — a Node-22-only builtin. Result: `actions/setup-node@v4`'s pnpm-cache restore step crashes with `Error [ERR_UNKNOWN_BUILTIN_MODULE]: No such built-in module: node:sqlite` and CI fast-job fails in 12-23s. Home-os shipped a 2-line fix on its own branch (bump `node-version` to `'22'` + `.nvmrc` `20` → `22`). **Fix**: same 2-line patch in `template/.github/workflows/ci.yml` + `template/.nvmrc`. **Where**: `template/.github/workflows/ci.yml` line 22 (or wherever node-version pin lives) + `template/.nvmrc`. ~5 min. **Severity: blocks every new project's first CI run** — fast-job fails immediately on first push to a feature branch.
- **(C2) Manifest gap: compose-isolation files not in `kit/manifest.txt` `[locked]` list (gen #26)** — `init-devshop.sh`'s [locked]-manifest enforcement at container start chowns `devcontainer.json`, `init-firewall.sh`, `Dockerfile`, `checksums.sha256`, `.env`, `firewall-extra-domains`, etc. to root:root 644 on every start. BUT the compose-isolation set (`compose.yml`, `init-host-env.sh`, `supabase-runner/Dockerfile`, `supabase-runner/cmd-relay.mjs`) is NOT in the manifest. Step 21 of `/ak-new-project` carries a conditional sudo block for these 4 files; if the operator skips that block, the files stay node:node and a compromised npm transitive can rewrite them. **Fix**: extend `kit/manifest.txt`'s [locked] list to include the four compose-isolation files; then `/ak-new-project § Step 21` simplifies to "verify all `.devcontainer/*` files are root:root; if not, rebuild devcontainer (init-devshop.sh re-applies on start)." Mind execute-bits — `init-host-env.sh` and `cmd-relay.mjs` are 755 (executed scripts); manifest enforcement should preserve mode per-file. **Where**: `kit/manifest.txt` + `kit/scripts/init-devshop.sh` (the [locked] processor — confirm mode-per-file support) + `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 21` (simplification after manifest extension). **Bundle with**: `PLAN.md § #5 (firewall-extras-overlay-merge)` PR — same surface, same shape. ~30 min if the manifest mode-per-file support is already there; ~1h if not. **Severity**: low (Step 21 currently catches the gap via the conditional sudo block) but the manifest is the right home for this.

#### D. Devshop-registry-driven Supabase port offsets (gen #1 from earlier session; redesigned 2026-05-15)

**Problem**: when 2+ projects run concurrently on the same host, the supabase local stack collides on ports 54321/54322/54323/54324/54327. Today lalista holds the default block; home-os manually rebound to +100 (api 54421, db 54422, studio 54423, inbucket 54424, realtime/analytics 54427) with the recipe captured in `kit/notes/projects/home-os.md`. The earlier framing offered two fix candidates — (i) a `SUPABASE_PORT_OFFSET` env knob with runtime templating across `compose.yml` + `supabase-runner/Dockerfile` + `init-firewall.sh` + `supabase/config.toml`, or (ii) an inline manual recipe in `/ak-new-project § Step 2b` — and deferred both pending a third project. A third design is simpler than either: bake the numbers in at scaffold time, source-of-truth in the devshop.

**Design — devshop-side port registry**:

1. **Registry** lives in `kit/notes/projects/<name>.md` frontmatter as `supabase_port_offset: <N>` (N = multiple of 100). The notes file already exists per project and tracks bootstrap lifecycle — no new artifact, no new index file.
2. **Auto-assign at scaffold time**. `/ak-new-project` Phase A bash block: `grep -h "^supabase_port_offset:" /devshop/kit/notes/projects/*.md | sort -u`, picks the lowest unused 100-block, writes it into the new project's notes frontmatter, writes `SUPABASE_PORT_OFFSET=N` into the scaffold's `.devcontainer/.env`, runs a sed pass over the freshly-generated `supabase/config.toml` (post-`supabase init`) to substitute the port numbers.
3. **Standalone fallback** for public contributors cloning the project repo without `/devshop` bind-mount: one conditional at the top of `/ak-new-project` Phase A — `if [[ ! -d /devshop/kit/notes/projects ]]; then OFFSET=0; fi`. They get default ports, exactly what they expect.
4. **Backfill** existing projects: write `supabase_port_offset: 0` into `kit/notes/projects/lalista.md`, `supabase_port_offset: 100` into `kit/notes/projects/home-os.md`. Same commit as the skill change.

**Files that actually need to move (template side, ~3 files)**:

- `template/.devcontainer/compose.yml` — replace hardcoded `54321`/`54322` in the socat lines + `SUPABASE_URL` env with compose env interpolation (`${SUPABASE_PORT_API:-54321}` etc.; compose supports this natively).
- `template/.devcontainer/init-firewall.sh` — read the port pair from `.devcontainer/.env` rather than hardcoding `54321`/`54322` in the `iptables -A OUTPUT ... --dport` lines.
- `template/.devcontainer/supabase-runner/Dockerfile` — `EXPOSE 54321 54322 9000` either takes a build arg or stays (EXPOSE is metadata-only; the actual binding happens in compose.yml).

**Files that stay hardcoded** (the 33 grep hits are misleading — most don't need to move):

- `template/.github/workflows/{ci,deploy-migrations}.yml` + `template/scripts/ci-rollback-explain.sh` — CI runs one project per job, no host-port collision possible. Defaults are correct.
- `template/packages/core/src/supabase.ts` + `.test.ts` — the `assertNotProdUrlInTestEnv` guard's error string and test assertions reference `127.0.0.1:54321` as the canonical local URL; not behavior-affecting.
- `template/.devcontainer/README.md` — doc-only; rephrase to "default block + offset" rather than parameterize.

**Skill change** (one file): `/ak-new-project § Step 2/Phase A` gets ~30 lines of bash for the registry lookup + assignment + scaffold-time sed. Plus a one-line update to Step 16 to sed `supabase/config.toml` ports after `supabase init`.

**Optional follow-on**: `kit/scripts/rebind-supabase-ports.sh <project> <new-offset>` for collision recovery (multi-file sed + container rebuild prompt). Not required for v1 — the registry's "pick next free" rule means collisions only happen via manual override, which is rare enough to handle by hand.

**Gotchas to document**:

- Re-running `supabase init` later resets `config.toml` to default ports. Document in `kit/docs/guide/architecture.md` or the project's CLAUDE.md scaffold: "ports are baked at scaffold time; if you re-run `supabase init`, re-apply the offset from `.devcontainer/.env`."
- Deleting a project doesn't reclaim its slot unless the notes file is also deleted. Probably fine (slots cheap, notes file is the audit trail); document the lifecycle rule "delete `kit/notes/projects/<name>.md` when the project repo is gone."

**Size**: ~1–2 focused hours, one PR (`feat/supabase-port-registry`), ~5-7 files touched in the devshop:

- 3 template files (compose.yml, init-firewall.sh, Dockerfile)
- 1 skill (`/ak-new-project`)
- 2 backfilled notes files (lalista, home-os)
- 1 docs note in architecture.md or CLAUDE.md scaffold

**Severity**: medium — current state has lalista on defaults, home-os rebound, no live collision. But the moment a third project bootstraps, the manual recipe ages out (someone has to remember which offset is taken). Ship before the third project rather than during.

[v0, redesigned 2026-05-15 — replaces the earlier "env knob vs inline recipe" framing with a registry-driven approach that's simpler than both]

##### Additional scope discovered during home-os PR #15 hero-shot backfill (2026-05-15)

The registry design above covers API + DB ports (54321/54322 → rebound). Three additional gaps surfaced when home-os's magic-link `/qa` flow exercised the full Supabase surface for the first time on a rebound-port project. None invalidate the registry design — they expand its scope.

**1. `init-firewall.sh` allow-list must cover the full rebound port set, not just api + db.** Today the template's `init-firewall.sh:232-234` allows `host.docker.internal` on `54321` + `54322` only. Studio (54323), Mailpit (54324), and Realtime/Analytics (54327) are silently REJECTed. The gap had never surfaced because lalista uses password-shortcut auth in E2E (`admin.createUser` + `signInWithPassword`, no email round trip — touches only Kong on `54321`). Home-os is the first project to adopt magic-link auth as the canonical shape, so its E2E + `/qa` flow needs Mailpit reachable to retrieve the magic-link URL. Session-only workaround applied during home-os PR #15: `sudo iptables -I OUTPUT 1 -d 192.168.65.254 -p tcp -m multiport --dports 54421,54422,54423,54424,54427 -j ACCEPT`. The durable fix: when the registry parameterizes the iptables rules, parameterize all five ports, not two. Same `.devcontainer/.env` source.

**2. `kit/scripts/preship/supabase-bootstrap.sh` hardcodes the upstream-default port pair throughout.** Lines `104`, `154`, `162`, `192`, `207`, `210`, `220`, `225` all reference `54321` / `54322` literally. On home-os (offset +100), every Gate 9 preflight reported `degraded: no local Supabase reachable` even with the stack fully healthy — the probe was looking at the wrong port. This is a kit-side script (not in `template/`), but the parameterization shape is the same: read `SUPABASE_PORT_API` + `SUPABASE_PORT_DB` (or whatever names the registry settles on) from `.devcontainer/.env` once at the top, substitute throughout. Add to the "Files that actually need to move" list — extends scope from 3 template files to 3 template + 1 kit script.

**3. `supabase init` writes `additional_redirect_urls` with two bugs that the registry's Step-16 post-`supabase init` sed pass should also fix.** The Supabase CLI default emits `additional_redirect_urls = ["https://127.0.0.1:3000"]` — `https` typo (Next dev is HTTP-only) and exact-string match with no `/**` wildcard. The exact-match policy rejects `emailRedirectTo` values that include any path (e.g., the canonical `${origin}/auth/callback?next=/home` from the SSR boilerplate's `LoginForm.tsx`), so GoTrue falls back to bare `site_url` and the `/auth/callback` PKCE-exchange handler never runs — magic-link arrives, navigates to `<site_url>?code=...`, the home page doesn't handle the code, user lands authless. Home-os fix applied at `90b8aaf`: `additional_redirect_urls = ["http://127.0.0.1:3000/**", "http://localhost:3000/**"]` (both hosts because Next 16 HMR/hydration requires `localhost` for client-side JS — see Pattern 10 in `kit/docs/guide/supabase-ssr-boilerplate.md` for the localhost-vs-127.0.0.1 failure narrative). The Step-16 sed pass already substitutes ports; one additional `sed -i` line over `[auth]` block lands this fix for free on every fresh scaffold.

**Updated scope** (replaces "Files that actually need to move" — same items, expanded coverage):

- `template/.devcontainer/compose.yml` — env-interpolation for **all 5** rebound ports (api/db/studio/mailpit/realtime), not just api/db. Compose supports this natively (`${SUPABASE_PORT_STUDIO:-54323}` etc.).
- `template/.devcontainer/init-firewall.sh` — `iptables -A OUTPUT ... --dport` lines parameterized for **all 5 rebound ports**, not just the api/db pair. Read all five from `.devcontainer/.env`.
- `template/.devcontainer/supabase-runner/Dockerfile` — `EXPOSE` either takes build args for all 5 ports or stays static (metadata-only).
- `kit/scripts/preship/supabase-bootstrap.sh` — parameterize the 8 hardcoded port references from `.devcontainer/.env`. Same source-of-truth as the template scripts; different repo (kit), different invocation context (host-side script reaching into project's stack).

**Updated Step-16 sed pass** (replaces "one-line update to Step 16"):

- Port substitution across the `[api] / [db] / [studio] / [inbucket] / [analytics]` blocks of the freshly-`supabase init`'d `supabase/config.toml`.
- `additional_redirect_urls` fix in the `[auth]` block: substitute the buggy default with `["http://127.0.0.1:3000/**", "http://localhost:3000/**"]`. Two-line sed extension.

**Updated severity rationale**: the registry's "ship before a third project bootstraps" framing stands — but the Mailpit-port gap actually fires today on home-os (Gate 9 silently degraded; PR #15 shipped with anon-bounce placeholder hero shots because authenticated routes were unreachable to the local browser). Closing the gap requires shipping the full 5-port parameterization, not the 2-port version. The home-os escape hatch (session-only `iptables -I OUTPUT 1`) reverts on every container rebuild, so home-os contributors will repeat the manual recipe until the durable fix lands.

[2026-05-15 — extends the registry design with the home-os-PR-#15-surfaced gaps]

#### E. First-session generalizations (2026-05-12 — surfaced before the Step-12.5/13/14/15/17 marathon)

Each is small and ships as a SKILL.md text edit, a template patch, or a docs note. Bundle into one PR with one commit per item, OR roll into sub-bundle A above if scope feels right. Same per-incident detail in `kit/notes/projects/home-os.md § Devshop generalizations § #2–#16` if you need the full narrative.

- **(E1) gen #2 — Sentry platform = Next.js, not React.** `/ak-new-project § Step 3` (account creation) currently says "Sentry: create account at sentry.io, create a project (platform: **React**, slug: `<project-name>`)". The template is Next.js-only; Sentry's Next.js SDK does SSR + Route Handler + Server Action error capture (the React-only SDK doesn't). **Fix**: change Step 3 platform to `Next.js`. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 3`. ~2 min. **Severity: low (operator can change post-hoc in the Sentry UI) but documenting the right default avoids confusion.**
- **(E2) gen #3 — Pre-burn `SUPABASE_SERVICE_ROLE_KEY` published local-stack JWT into `template/.devcontainer/.env`.** The value is identical across every Supabase install (published default, signed with a hardcoded supabase-cli secret). Currently the operator has to either run `supabase start` to discover it, or ask Claude. Pre-filling it in the template eliminates a friction point and reinforces "this is public, not prod-sensitive." Keep the `# NOT the prod admin key` comment inline. **Where**: `template/.devcontainer/.env` (this is the example/seed file the operator copies; or rename `.env.example` if that's the template pattern — verify against current template shape). **Caveat**: don't drift if Supabase ever rotates the local-stack default (rare; the value has been stable since supabase-cli 1.x). ~5 min.
- **(E3) gen #4 — Sentry DSN UI navigation guidance is stale.** `/ak-new-project § Step 4` points at "Project Settings → Client Keys" which doesn't match current Sentry UI (multiple reorgs since the original skill text). The reliable path is the direct URL `https://sentry.io/settings/<org-slug>/projects/<project-slug>/keys/`. **Fix**: replace the navigation paragraph with the direct-URL form, OR replace with a `sentry-cli` invocation that fetches the DSN non-interactively. Prefer direct-URL — `sentry-cli` requires a separate auth setup. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 4` (Sentry credentials sub-bullet). ~5 min.
- **(E4) gen #5 — Drop `SUPABASE_DB_PASSWORD` from `.devcontainer/.env`.** Same blast radius as the prod service-role key (direct DB connection, bypasses RLS) — but the skill currently persists it locally while telling operators NOT to persist the service-role prod key. The `.env` line isn't what CI consumes (CI reads the GH Secret). The only operator-side use is rare ad-hoc prod DB ops, which can follow the same paste-from-password-manager-then-clear pattern as the prod service-role key. Asymmetric treatment is skill drift, not deliberate design. **Fix**: remove `SUPABASE_DB_PASSWORD=` from `template/.devcontainer/.env` (or the example shape in skill Step 4); update Step 4's "Three non-obvious things" + Security Posture surface matrix to mark it `❌ NEVER` in the `.devcontainer/.env` column with a "paste from PW manager for ad-hoc" note. Pairs with the existing service-role guidance — consistent narrative: prod-DB-admin credentials don't live on operator disks. **Where**: `template/.devcontainer/.env` + `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 4` (+ § Security Posture surface matrix). ~15 min.
- **(E5) gen #10 — Step 10 sed substitution misses `packages/core/vitest.config.ts` placeholder.** Skill's sed runs on `src/supabase.ts src/supabase.test.ts` (PROJECT_REF) + `package.json src/index.ts` (PROJECT_NAME), but `vitest.config.ts` has a `// @PROJECT_NAME_PLACEHOLDER/core` comment header that stays unsubstituted. Cosmetic for tests (comment only), but it shows in `grep -r PROJECT_NAME_PLACEHOLDER` audits and confuses future readers. **Fix**: extend Step 10's PROJECT_NAME sed list to include `vitest.config.ts`, OR change the template comment to a placeholder-free phrasing (e.g., `// Vitest config for packages/core` — no project name). Prefer the second — less brittle. **Where**: `template/packages/core/vitest.config.ts` (comment rewrite) — no skill change needed. ~3 min.
- **(E6) gen #11 — Docs-freshness hook fires at Step 12 before Step 18 fills the skeletons.** `kit/scripts/commit-hooks/check-docs-freshness-project.sh` blocks the apps/web scaffold commit because new `app/page.tsx` / `app/layout.tsx` / `middleware.ts` are user-visible-flow / module-map surfaces that require CLAUDE.md + OVERVIEW.md + ARCHITECTURE.md staging. The three docs all exist at HEAD (skeleton from template), so the hook is active — but their content is still placeholder until Step 18 of the skill. Two consequences: (a) the operator either bypasses with `devshop.docsCoverageReason` at Step 12 and re-bypasses at every subsequent app-modifying commit until Step 18; OR (b) brings Step 18's doc-fill forward to Step 12, which is what home-os did. **Fix candidates**: (i) reorder the skill so Step 18 moves to ~Step 12.5 (after apps/web scaffold lands, before Sentry/PostHog); (ii) drop Step 18 entirely and bake "fill docs from design review (if present) or capture-as-you-go" into Step 12 itself. Lalista's pattern (CLAUDE.md filled gradually as features ship) is the alternative — but home-os benefited from front-loading because the design review existed. Prefer (i): reorder. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md` — re-number Step 18 → Step 12.5; renumber subsequent steps as needed. ~30 min (the renumbering touches multiple cross-refs).
- **(E7) gen #12 — Root + create-next-app build-script approval conflict.** `create-next-app --use-pnpm` writes `apps/web/pnpm-workspace.yaml` with `ignoredBuiltDependencies: [sharp, unrs-resolver]`. The template's root `package.json` `pnpm.onlyBuiltDependencies` includes the same two packages. pnpm 10 surfaces this as conflicting policy. **Clean reconciliation**: drop sharp + unrs-resolver from root `onlyBuiltDependencies`, move them to root `ignoredBuiltDependencies`, delete apps/web/pnpm-workspace.yaml (the file create-next-app wrote). Single source of truth. **Where**: `template/package.json` (rename `onlyBuiltDependencies` entries for sharp + unrs-resolver) + add `/ak-new-project § Step 12` sub-step note: "after `pnpm create next-app`, `rm apps/web/pnpm-workspace.yaml` — root manages build-script policy for the workspace." ~10 min. **Severity: low** — discovery cost is one search + reconcile, but documenting prevents the next operator from re-experiencing it.
- **(E8) gen #13 — `pnpm create next-app` writes files even when interrupted.** apps/web/ partially exists from an interrupted invocation; on second invocation, the tool refuses with "directory contains files that could conflict." Recovery requires manual cleanup OR live with the partial scaffold (workable if `package.json`, `app/`, `tsconfig.json` exist). **Fix**: skill Step 12 gets a sub-step note: "If `pnpm create next-app` was interrupted, inspect `apps/web/` — if `package.json`, `app/`, and `tsconfig.json` exist, proceed with customization; if anything's missing, `rm -rf apps/web/` and rerun. Don't try to merge the partial state with a second create-next-app run — it'll refuse." ~5 min. **Severity: low** — interruption is rare — but the symptom is opaque enough to warrant a note.
- **(E9) gen #14 — Step 6 tracker mark `[x]` without verifying file state — multiple downstream steps silently failed.** The home-os tracker had `[x]` on Step 6, but `.devcontainer/init-firewall.sh` showed none of the project-specific entries actually added (only the static template list). Discovered when Step 15 `supabase link` failed with `EHOSTUNREACH` and Step 14 chromium install failed similarly. Root cause: the operator marked the step done prematurely OR (more likely after gen #17 surfaced) the additions were rolled back by the [locked]-file refresh. With the firewall-extras-overlay fix (PLAN.md § #5), this specific failure mode is closed — but the tracker-verification gap remains. **Fix**: Step 6 ends with a verification command — `grep -E "supabase\\.co|ingest\\.sentry|posthog\\.com" .devcontainer/firewall-extra-domains` — that the operator runs before marking [x]. Same pattern would catch similar slips at other tracker checkpoints (could be generalized to a "verify step before [x]" rule on every Step that touches non-source files). **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 6`. ~5 min.
- **(E10) gen #15 — Claude can't edit `.devcontainer/*` files; firewall + compose.yml fixes are operator-only.** `.claude/settings.json` has `Edit(/workspace/.devcontainer/*)` in the deny list (good security posture: prevents accidental modification of attack-surface-critical files). But it means the firewall additions (Step 6) AND any future compose.yml mount-addition AND the Step 21 chown block are BOTH operator-only edits. Two consequences: (a) the rebuild that fixes both is operator-driven, which becomes a natural batching moment — fix everything `.devcontainer/`-shaped at once, rebuild once; (b) skills that depend on `.devcontainer/*` (Step 6, Step 7, Step 21) MUST be explicit about the operator-only constraint so Claude doesn't try-and-fail then mark partial-progress. **Fix**: skill text should explicitly say "STOP and ask the operator to apply the following diff to `.devcontainer/...`" rather than implying Claude can patch. Affected steps: Step 6, Step 7, Step 21 (and any future `.devcontainer/`-touching step). Add the framing at the top of each as "**[OPERATOR-ONLY]**" prefix on the Step header. **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 6 / Step 7 / Step 21`. ~10 min.
- **(E11) gen #16 — Steps blocked on firewall additions form a natural [HUMAN] batching moment.** Step 14 (chromium install), Step 15 (`supabase link`), Step 17b (auth hardening) all share the same root cause: missing firewall entries for project-specific external services. A single operator-side action (edit firewall-extra-domains + rebuild) unblocks ALL three. The skill currently spreads the discovery across Steps 14/15/17b individually. **Fix**: Step 6 ends with a "smoke test the additions" sub-step that curls the project-specific endpoints (`api.supabase.com`, the project's `<ref>.supabase.co`, `*.ingest.us.sentry.io`, `us.i.posthog.com`, `playwright.download.prss.microsoft.com`) and surfaces failures BEFORE proceeding to Step 7's rebuild. So Step 6 either fully unblocks downstream OR surfaces the gap immediately rather than at Step 14 / 15 / 17b. **Pairs with E9 (verification command)** and PLAN.md § #5 (firewall-extras-overlay-merge). **Where**: `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 6` (sub-step at end). ~10 min.

**Sub-bundle E acceptance**: shipped as one PR (`fix/ak-new-project-first-session-polish`) with up to 11 atomic commits (E1..E11), OR bundled into sub-bundle A above as one combined skill-polish PR. Both A + E are pure SKILL.md / template-text edits and they share a surface; bundling is probably faster (~90 min total) but creates one larger diff to review. The B + C bundles touch different surfaces and should stay separate.

**Total estimate for the whole entry (A + B + C + D + E)**: ~3-4 focused hours, split across 3-4 PRs. Half-day session covers everything.

#### Acceptance — sub-bundle level

- **A bundle**: one PR, five commits, ~45–60 min. Tests-side: bats expectations for the SKILL.md text changes (where they exist; A2/A3 are pure prose so visual review is the gate).
- **B bundle**: three independent PRs (B1 + B2 + B3 each ~10–20 min). Could bundle as one if scope feels right, but they touch different surfaces (CLAUDE.md / template / hook).
- **C bundle**: one PR (C1 + C2 together, both touch templates / manifest). ~30–45 min. C1 should ship FIRST because it unblocks every new project's CI.

#### Verification — whole entry

- Fresh `/ak-new-project` from scratch (Phase A clone of template into `/tmp/<fresh>`) should produce: (i) `apps/web` build with no Sentry deprecation warnings; (ii) `pnpm --filter @<fresh>/core test:unit` 5/5 with prod-URL guard tests not skipping; (iii) `pnpm --filter @<fresh>/web test:unit` clean with `@/` alias resolving; (iv) CI fast-job green on Node 22 + pnpm 11; (v) `.devcontainer/` 14 files all root:root after rebuild without any manual `sudo chown` from the operator.

[v0, surfaced-by home-os-onboarding-2026-05-13]

---

### Strip devshop-meta seed content from template tracker stubs; audit all template/\*.md skeletons

**Problem.** `template/PRODUCT-ROADMAP.md` ships with **three pre-populated v1 entries** — PWA service worker caching, visual regression testing, performance baselines for API. None of these are project-deferred work: they're devshop-meta concerns (template-level capabilities the devshop hasn't built yet) that leaked into the per-project "deferred/long-term" doc when the template was authored. Two of the three are already correctly filed in this same `kit/ROADMAP.md` (`§ Template PWA service worker baseline` v0; `§ Visual regression testing` v1). The third (API perf baselines) is unfiled. Every project scaffolded from `/ak-new-project` starts life with a `PRODUCT-ROADMAP.md` claiming three deferred items the project never opted into.

Every other template tracker stub ships the right shape — empty placeholders with HTML-comment scaffolding showing how to fill: `template/PLAN.md` ("_No work in progress._"), `template/TODOS.md` ("_No pre-ship items._"), `template/BUILD-LOG.md` ("_No builds yet._"), `template/DEPS-WATCH.md` ("_No parked dependencies._"). `PRODUCT-ROADMAP.md` is the outlier.

The principle: **a fresh project's tracker docs should start empty.** Per-project deferred work accumulates as the project ships features, not at scaffold time. Devshop-meta concerns belong in `kit/ROADMAP.md`.

**Scope.**

- (1) Strip the three sample entries from `template/PRODUCT-ROADMAP.md`. Replace the body with the same empty-placeholder + HTML-comment-scaffolding shape `template/TODOS.md` uses, so an operator sees the structure but no pre-seeded content.
- (2) File the orphan into `kit/ROADMAP.md`: a new entry "API performance baselines for `/benchmark`" (the existing `/benchmark` skill checks Core Web Vitals frontend-side; an API-side companion checking key query response-times-vs-data-volume is the natural extension). v1 unless there's a forcing project incident.
- (3) **Audit every other `template/*.md` and `template/<path>/*.md` skeleton for the same smell.** Each stub should answer "does this content describe THIS project's state, or some devshop-meta concern that leaked in?" — if devshop-meta, route it. Files in scope: `template/{README,CLAUDE,OVERVIEW,ARCHITECTURE,METRICS,DEPS-WATCH,BUILD-LOG,PLAN,TODOS,PRODUCT-ROADMAP}.md`, plus any per-package skeletons (`template/apps/*/README.md`, `template/packages/*/README.md`, `template/supabase/functions/README.md` if/when they get added). The smell to look for: pre-populated rows / entries / examples that name specific capabilities, libraries, or behaviors a fresh project hasn't chosen yet. Scaffolding HTML comments + empty-placeholder language are fine; pre-seeded specifics are not.

**Why this is v0.** Same forcing function as the home-os onboarding batch: every fresh `/ak-new-project` scaffold ships the bug. Lalista already has the contaminated `PRODUCT-ROADMAP.md` (and may have copy-paste-edited the three sample entries into something project-shaped, which would need to be checked). Home-os just got scaffolded; either it inherited the same three entries (then needs the same cleanup) or the operator manually pruned them.

**Fix shape.**

- One PR, three commits: (a) `template/PRODUCT-ROADMAP.md` strip; (b) `kit/ROADMAP.md` add "API performance baselines for `/benchmark`" (v1 section, sized like the existing visual-regression entry); (c) audit results from sweeping the other stubs — either confirm "no other leaks found" in the commit message, or fix found leaks in the same commit. Estimate: 30–45 min including the audit sweep.
- Migration for existing projects (lalista + home-os): diff each project's `PRODUCT-ROADMAP.md` against the cleaned template. If the three sample entries are still verbatim, delete them; if they've been edited into something project-shaped, leave them (the project owns its own roadmap once it's started shipping). Quick check per project; no risky migration.

**Verification.**

- Fresh `/ak-new-project` from a post-fix template: `cat /tmp/<fresh>/PRODUCT-ROADMAP.md` should show only the header + sectioning + HTML-comment scaffolding + an "_No deferred work yet._" placeholder. Zero specific capability names.
- `grep -lE 'service worker|visual regression|response time'` against `template/PRODUCT-ROADMAP.md` returns nothing.
- `kit/ROADMAP.md` contains entries for all three of the previously-seeded concerns (the existing two + new API perf baselines).
- Audit sweep of every `template/*.md` stub completes; either no further leaks found (recorded in the commit message) or all found leaks fixed in the same commit.

[v0, surfaced-by home-os-onboarding-2026-05-13]

---

### Scaffold `template/apps/web/` baseline — landing zone for soak-extract entries

**Problem.** `/devshop/template/apps/web/` does not exist as a tracked tree at HEAD. `/devshop/template/` contains only `packages/core/`, `.devcontainer/`, `.github/`, `screenshots/`, `scripts/`, `.husky/`. The convention today: `/ak-new-project` Phase B Step 12 runs `pnpm create next-app` per-project, then layers in Sentry / PostHog / Supabase SSR / etc. via subsequent steps. Each new project recapitulates the same wiring; nothing accretes back to template.

This blocks five separately-tracked v0 entries that all need a place to ship code into:

| Entry                                          | What it needs `template/apps/web/` for                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **R12** Lalista PR #43 E2E lessons             | `template/apps/web/e2e/helpers/inbucket.ts` (Mailpit + bare-/verify rewrite) + e2e spec skeletons |
| **R13** Auth UX conventions                    | `template/apps/web/app/auth/callback/` route, `app/reset-password/` route, sign-in page pattern   |
| **R14** Latency feedback primitives extraction | `template/packages/ui/` package (which depends on having `apps/web/` to consume it)               |
| **R15** PWA service worker baseline            | `template/apps/web/next.config.ts` serwist wiring + `app/sw.ts`                                   |
| **T5** Tap-feedback CSS contract               | `template/apps/web/app/globals.css` (file doesn't exist anywhere under template/)                 |

The five entries above are each individually-sized at 15 min – 4 hr, but ALL of them are gated on this single missing surface. Currently they sit in the v0 backlog without an obvious unblocker — implementers picking them up have to choose between "scaffold the surface inline first" (mixing scope) or "skip these v0 entries indefinitely."

**Shape of the fix.** Scaffold a minimal `template/apps/web/` that mirrors what `/ak-new-project` Phase B produces from `pnpm create next-app` + the canonical wirings, then point `/ak-new-project` at the template tree (copy-and-substitute) instead of re-running create-next-app per-project.

Minimum tracked tree:

- `template/apps/web/package.json` (Next.js + React + minimum deps; project name placeholder)
- `template/apps/web/next.config.ts` (Sentry wrapper, PostHog instrument, env validation — placeholders for project-specific values, **plus `allowedDevOrigins: ['localhost', '127.0.0.1']`** per R16-B4 — Next 16 blocks cross-origin HMR by default, both hosts needed because Supabase auth issues URLs rooted at `127.0.0.1` while Next 16 prefers `localhost` for HMR)
- `template/apps/web/tsconfig.json` (with `@/*` alias matching create-next-app convention)
- `template/apps/web/app/{layout.tsx,page.tsx,globals.css}` (minimal landing-page shell; design-system tokens go in globals.css)
- `template/apps/web/middleware.ts` (or `proxy.ts` post-Next-16 rename per R16-B2 — see also)
- `template/apps/web/e2e/` (Playwright config + helpers/ stub directory). **`playwright.config.ts` MUST include a `webServer: { command: 'pnpm dev', port: 3000, reuseExistingServer: !process.env.CI, timeout: 120_000 }` block** so `pnpm test:e2e` boots the dev server itself rather than requiring out-of-band `pnpm dev` in another shell. Home-os PR #15 hit this — Gate 9 `/qa` couldn't run locally without the operator manually managing the dev server lifecycle; `webServer` closes that friction.
- `template/apps/web/vitest.config.ts` + `vitest.setup.ts` (per PLAN.md § #4 generalization #9 — WebSocketStub) + `@/` alias (per generalization #23)
- `template/apps/web/instrumentation.ts` + Sentry server/edge files

**Why v0 — blocks next-project adoption + unblocks 5 other v0 entries.** Five v0 entries are structurally stalled waiting on this surface. Without it, the "second project adopts and surfaces the lift trigger" path is hollow — there's no template tree to lift INTO. Ship this once; each blocked entry becomes a small targeted PR after.

**Sequencing recommendation:**

1. **Scaffold first** (~half-day): produce the minimum tracked tree above. Validate by running `/ak-new-project` Phase B copying from template instead of generating with create-next-app — fresh project should still produce a buildable, testable app.
2. **Then unblock the five v0 entries** (each as its own PR): T5 (15 min CSS), R12 (1 hr helper file lift), R15 (~2 hr serwist wiring), R13 (~4 hr auth UX scaffold), R14 primitives (~2 hr after framework prose lifts).

**Cross-ref:**

- `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 12` — the current `pnpm create next-app` path; post-scaffold this step shifts to "copy template/apps/web/ + sed-substitute project name."
- `kit/ROADMAP.md § v0 § Generalize lalista PR #43 E2E + Supabase test-infra lessons` (R12) — blocked dependent
- `kit/ROADMAP.md § v0 § Auth UX conventions — shared error-surface + state patterns` (R13) — blocked dependent
- `kit/ROADMAP.md § v0 § Latency feedback framework — 4-tier decision rule + primitives` (R14) — blocked dependent
- `kit/ROADMAP.md § v0 § Template PWA service worker baseline` (R15) — blocked dependent
- `kit/TODOS.md § Port the tap-feedback press-state contract` (T5) — blocked dependent
- `lalista/apps/web/` + `home-os/apps/web/` — concrete shapes that exist post-scaffold to mine for the template tree

**Cost/risk:**

- Implementation: ~4-6 hr for the scaffold (initial tracked tree + sed-substitute logic in Step 12 + validation on a fresh `/ak-new-project` run). Plus an additional ~1 hr of cross-project diff work to pick which canonical shape to ship (lalista's vs home-os's are close-but-not-identical post-onboarding; need to choose one as the template canonical or extract common shape).
- Risk: medium. Template drift is the failure mode — if the template's app shape doesn't match what create-next-app produces in 6 months, projects that copy from template will diverge from upstream Next.js conventions. Mitigation: pin the template's Next.js version explicitly and refresh the template every Next.js minor.
- Benefit: closes the unblocker for five v0 entries; reduces `/ak-new-project` runtime (no more 90s `pnpm create next-app` round-trip per scaffold); creates a single canonical "what does a devshop project look like" reference.

**Trigger:**

- Verified 2026-05-14 during v0 triage that R12, R13, R14, R15, T5 all share this blocker. Originally each entry was filed as "soak-extract from lalista" with the assumption the destination would obviously exist — turns out the destination is the missing piece.

[v0, surfaced-by 2026-05-14 v0-triage verification pass]

---

### Home-os PR #15 hero-shot backfill — devshop fixes (2026-05-15)

Five gaps surfaced during the home-os PR #15 hero-shot backfill session that don't fit into any existing ROADMAP entry — orthogonal to the supabase-port-registry redesign (which absorbed D3/D4/D6 from this batch), the LLM-mediated gate contract entry (which absorbed D2), and Sub-bundle B (which absorbed D7/D8). Each item below is independently shipped — no shared surface.

**Context.** Home-os PR #15 (`feature/capture-flow`, 2026-05-14) shipped with anon-bounce placeholder hero shots because Gate 9 `/qa` was `blocked` (Supabase Kong unreachable from container — pre-existing infra carry-over). The post-ship hero-shot backfill session (2026-05-14 → 2026-05-15) found four stacked root causes — `supabase-bootstrap.sh` port hardcode, `.env.local` pointing at prod, Google Fonts blocked by firewall, Mailpit port blocked by firewall — and the discovery process surfaced these additional five devshop-side fixes that aren't covered by existing roadmap entries.

#### `/ak-new-project § Step 13b` — `.env.local` default values (safety bug)

**Problem.** `/ak-new-project § Step 13b` generates `apps/web/.env.local` with **production** Supabase / PostHog / Sentry values (`SUPABASE_PROD_URL`, `SUPABASE_PROD_ANON_KEY`, prod PostHog key, prod Sentry DSN). The rationale documented in the SKILL.md is "`pnpm dev` should mirror prod-runtime behavior (consistent SSR data, no migration drift)" — a deliberate design choice. But the choice conflicts with `/ak-pre-ship` Gate 9 `/qa`, every Playwright E2E, every `/qa` invocation, and every operator dev session that needs a working local Supabase round trip: they all need to dial the local stack, not prod.

The conflict manifests as **silent prod pollution**: any form submission during local dev / `/qa` hits the prod Supabase project. Home-os PR #15's hero-shot Playwright run created a real auth.users row on the prod project under a fake `@test.local` email before the operator caught it. The same configuration would have hit Supabase's per-email OTP rate limit on retry, leaving the operator confused about why magic links stop arriving locally.

Lalista's `.env.local` already uses local-stack values (URL = `http://host.docker.internal:54321`, anon JWT = published demo) — the operator manually fixed it. Home-os was operator-fixed mid-PR-#15. Every new project ships with the prod-default until manually corrected. The same gen #3 (E2) entry pre-burns the local-stack JWT into `template/.devcontainer/.env` — the asymmetry is that Step 13b still wires prod into the BROWSER bundle even though E2 wires local into the shell env.

**Fix.** Flip the Step 13b default to **local-stack values**:

```bash
cat > apps/web/.env.local <<EOF
NEXT_PUBLIC_SUPABASE_URL=http://host.docker.internal:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY  # local-stack default JWT from .devcontainer/.env
EOF
```

Omit `NEXT_PUBLIC_POSTHOG_KEY` + `NEXT_PUBLIC_SENTRY_DSN` from the default seed — both libs silently no-op when keys are missing. Operators who want local-dev telemetry firing should opt in explicitly with a separate dev project (NOT prod). Document the explicit override gesture for the rare case of needing prod-data SSR via `pnpm dev`:

```bash
# Temporarily dial prod from local dev (be aware: form submits hit prod Supabase):
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_PROD_URL pnpm dev
```

**Where.** `/devshop/.claude/skills/ak-new-project/SKILL.md § Step 13b`. Rewrite the heredoc + the "Why prod by default" rationale paragraph. The rest of Step 13b (gitignore verification + "Without this step, every browser-dependent gate breaks" warning) stays.

**Cost.** ~15 min — single SKILL.md edit + rewrite of the rationale block. Cross-link to home-os PR #15 + lalista's already-correct pattern.

**Severity.** **High (safety).** Every new project ships polluting prod by default. Every `/qa` invocation, every Playwright form submit, every `pnpm dev` form submit on a fresh project goes to prod. Discovery happens during the FIRST QA-style debug — too late.

#### `template/.devcontainer/firewall-extra-domains` — seed Google Fonts hostnames

**Problem.** Template's `apps/web/app/layout.tsx` imports `Inter` from `next/font/google` (the canonical Next.js font pattern). At dev-server request time, Next fetches `fonts.googleapis.com` + `fonts.gstatic.com`. The container's default-DROP firewall REJECTs both hosts, the font fetch hangs indefinitely (no timeout in the framework path), the dev server's request handler stalls then exits silently with NO error in the log — only `[?25h` (cursor-show terminal escape) as last output.

The symptom looks like "Next dev silently dies under load" — took multiple debug cycles on home-os PR #15 to trace because the dev process re-spawns from systemd-like supervision and the failure happens between "✓ Ready in <N>ms" log lines.

**Fix.** Seed both hostnames in the template's `firewall-extra-domains`:

```diff
+# next/font/google fetches these at request time. Without them, the
+# dev server hangs serving the first request (font fetch never returns)
+# and exits silently with no error logged.
+fonts.googleapis.com
+fonts.gstatic.com
```

**Where.** `template/.devcontainer/firewall-extra-domains` — currently this file is scaffold-once + project-owns after, so the template adds the seed and existing projects (lalista, home-os) backfill manually.

**Cost.** ~5 min — two-line template edit + a comment block explaining the load-bearing nature. Plus a backfill check on lalista (home-os already has them — landed on PR #15 in `90b8aaf`).

**Severity.** **Medium.** Every new project using the canonical `next/font/google` pattern hits this on first dev-server boot. Symptom is opaque (silent exit, no error). One-time cost per project is high (~hours of debugging without prior knowledge).

#### Browse daemon — fall back to system Chromium when Playwright's binary is missing

**Problem.** `/devshop/.claude/skills/gstack/browse/src/browser-manager.ts:172` calls `chromium.launch({ headless, chromiumSandbox })` without specifying `executablePath`. Playwright then looks for its own downloaded Chromium at `~/.cache/ms-playwright/chromium_headless_shell-<rev>/chrome-linux/headless_shell`. In container environments where Playwright's Chromium isn't installed (auto-mode classifier rejects external downloads, fresh container without `npx playwright install`), the launch fails with `Executable doesn't exist at ...`.

System Chromium is usually available at `/usr/bin/chromium` (Debian/Ubuntu container base). Empirically verified during home-os PR #15: `chromium.launch({ executablePath: '/usr/bin/chromium' })` works with Playwright's launch API (system Chromium 147 + Playwright 1.60). Today's manual workaround is symlinking `/usr/bin/chromium` to the Playwright-expected path — session-only, reverts on container rebuild.

**Fix.** At launch time, check if Playwright's expected binary exists; if not, probe for system Chromium and use `executablePath`:

```ts
async launch() {
  // ...existing launchArgs setup...

  // Detect Playwright-vs-system Chromium availability. Playwright's downloaded
  // binary is the default; system Chromium is the fallback for container
  // environments where the operator hasn't / can't run `npx playwright install`.
  let executablePath: string | undefined;
  const playwrightDefault = await fs.promises
    .access(chromium.executablePath())
    .then(() => true)
    .catch(() => false);
  if (!playwrightDefault) {
    for (const candidate of ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome']) {
      if (await fs.promises.access(candidate).then(() => true).catch(() => false)) {
        executablePath = candidate;
        console.log(`[browse] Playwright Chromium not found; falling back to system: ${candidate}`);
        break;
      }
    }
  }

  this.browser = await chromium.launch({
    headless: useHeadless,
    chromiumSandbox: process.platform !== 'win32',
    ...(launchArgs.length > 0 ? { args: launchArgs } : {}),
    ...(executablePath ? { executablePath } : {}),
  });
}
```

**Where.** `/devshop/.claude/skills/gstack/browse/src/browser-manager.ts § launch()`. Add a fallback block; preserve the existing behavior when Playwright's binary is available.

**Cost.** ~30 min — code edit + bun-test addition stubbing the file-existence check + visual verification on a container without Playwright's Chromium.

**Severity.** **Medium.** Affects every `/qa`, `/design-review`, `/benchmark`, and `/canary` invocation on a container without Playwright's Chromium. Today's workaround (symlink) requires sudo + reverts on rebuild — not durable.

#### Browse daemon — extend screenshot path allow-list to include `.gstack/` outputs

**Problem.** `/devshop/.claude/skills/gstack/browse/src/...` enforces a path allow-list on screenshot output: today only `/tmp/**` and `/workspace/apps/web/**` are accepted. Standard `/qa` skill output goes to `<git-root>/.gstack/qa-reports/screenshots/` per the skill's own template. The path-allow-list rejects writes there with `Path must be within: /tmp, /workspace/apps/web`. Today's workaround is a 2-step copy: browse writes to `/tmp/qa-shots/<name>.png`, then a `cp` to `.gstack/qa-reports/screenshots/`.

**Fix.** Extend the allow-list to include `<git-root>/.gstack/**` (any sub-path) and `<git-root>/specs/**/hero/**` + `<git-root>/specs/**/screenshots/**` (per the `/ak-pre-ship` Phase 7 hero-shot convention):

```ts
const ALLOWED_SCREENSHOT_ROOTS = [
  '/tmp',
  '/workspace/apps/web',
  resolveGitRoot('.gstack'),
  resolveGitRoot('specs'), // sub-paths matching /hero/ or /screenshots/
];
```

**Where.** Wherever the path allow-list lives in `/devshop/.claude/skills/gstack/browse/src/`. Search for the literal error string `"Path must be within"`.

**Cost.** ~15 min — extend the allow-list + bun-test addition asserting the new paths pass and unrelated paths still reject.

**Severity.** **Low.** Friction, not correctness — the 2-step copy works. But it's a papercut every `/qa` run pays.

#### Convention — daemon-survival shell pattern in Claude Code harness

**Problem.** Long-running processes spawned via `command &` or `run_in_background=true` in the Claude Code harness get reaped when the foreground Bash tool call exits. Several `/qa` / `/design-review` / debugging workflows need a dev server (Next, Vite, etc.) alive across multiple browse / Playwright invocations. Today the harness silently kills the server between tool calls, producing opaque `ERR_CONNECTION_REFUSED` errors with no log trail.

The pattern that empirically survives in the harness (proven during home-os PR #15 hero-shot capture):

```bash
(nohup <long-running-command> </dev/null > /tmp/output.log 2>&1 &)
```

The outer parens spawn a subshell; `&` puts the command in that subshell's background; the subshell exits immediately; the command's parent reparents to PID 1 (init); `nohup` ignores SIGHUP. The harness's bg-reap mechanism (which terminates background jobs when the parent shell exits) doesn't follow the reparented process to init. Confirmed survives across multiple subsequent Bash tool calls in the same harness session.

A second corollary discovered alongside: `next dev` must be spawned with the correct `cwd` (the project's `apps/web/` directory), not the workspace root. Running from `cwd=/workspace` produces the cryptic error `Couldn't find any pages or app directory. Please create one under the project root` even though the directory clearly exists at `apps/web/app/`. The pattern when used with `next dev` (or any other Next-discovery-aware tool) is:

```bash
(cd /workspace/apps/web && nohup ./node_modules/.bin/next dev </dev/null > /tmp/output.log 2>&1 &)
```

**Fix.** Document the pattern in `kit/docs/guide/conventions.md § Long-running processes in the Claude Code harness` (new section). Cross-link from `/qa`, `/design-review`, `/benchmark`, and any other skill that spawns a dev server. Worth a worked example with the home-os hero-shots script as the canonical reference.

**Where.** `kit/docs/guide/conventions.md` — new section + cross-refs from the four skills that need it.

**Cost.** ~30 min — write the convention prose + the worked example + add four cross-ref lines to the skill SKILL.md files.

**Severity.** **Low.** Pattern is non-obvious enough that operators (and Claude) discover it via debugging, not docs. Documenting saves the same debug arc from being repeated each session.

[v0, surfaced-by home-os-PR-15-hero-shot-backfill-2026-05-15]

---

## v1 (after v0 is validated on the first project)

### Test-coverage hook scope: extend to template/.devcontainer/\*.sh + reframe EXEMPT_SCRIPTS as warn-not-block

**Problem.** `kit/scripts/commit-hooks/check-tests-coverage-devshop.sh` only scopes to `kit/scripts/*.sh` (line 51-52: `git diff --cached --name-only --diff-filter=A | grep '^kit/scripts/.*\.sh$'`). Template-side devcontainer scripts (`template/.devcontainer/init-firewall.sh`, `init-prod-url.sh`, `refresh-allowed-ips.sh`, `init-host-env.sh`, `init-devshop.sh`) are outside the scope — additions or non-trivial behavior changes there ship without any test-coverage check.

Audit-time `/ak-tests-review` catches the gap (it did during the firewall-extras-overlay merge, 2026-05-14), but the Layer 1 hook misses two surfaces today:

- `template/.devcontainer/init-prod-url.sh` (added 2026-05-09, `f94a121`) — zero bats coverage.
- `template/.devcontainer/refresh-allowed-ips.sh` (same commit) — zero bats coverage.

Both are security-relevant scripts (they govern firewall allowlist updates). The pattern: when a template-script feature ships, the same author often forgets the bats — exactly the case the hook should catch.

Separately, `EXEMPT_SCRIPTS` (line 32-40) is over-broad. It exempts `init-devshop.sh`, `session-start.sh`, etc. with the rationale "runs as root — needs integration test environment" — true for **runtime** integration tests, but **static-grep tests** (the pattern used by `structural-invariants.bats` and `template-compose-isolation.bats`) work without root. In practice operators add static tests anyway: `init-devshop.sh` has 5 bats files referencing it, `adversarial-review.sh` has 14 — the exemption is honored in the breach. The exemption should distinguish "no runtime test feasible" (still warn for static gaps) from "no test of any kind possible" (truly exempt).

**Shape of the fix:**

1. Extend the hook's path filter from `^kit/scripts/.*\.sh$` to also match `^template/\.devcontainer/.*\.sh$`. Template-side devcontainer scripts get the same "added → block" / "modified → warn" treatment.

2. Reframe `EXEMPT_SCRIPTS` semantics. Either (a) split into two lists — `RUNTIME_EXEMPT_SCRIPTS` (no execution-test required, static-grep still warned-on) vs `FULLY_EXEMPT_SCRIPTS` (no test of any kind required) — or (b) keep one list but downgrade the exemption to warn-only for added scripts. Option (b) is the smaller change.

3. Update the hook's bypass message to direct operators to static-grep tests as the cheap path.

**Cost.** ~30 minutes. Pure script edit + 2-3 new bats assertions in `kit/tests/guard-tests-coverage-devshop.bats` to pin the new behavior. No semver impact.

**Why v1 not v0.** Layer 2 audit catches this — there's no silent-coverage-gap ship today. The cost of the gap is "Layer 2 surfaces a finding that Layer 1 should have blocked" — paper-cut, not silent miss. Promote to v0 if a third missed-coverage incident surfaces.

### Pre-push reviewer recognises canonical Phase 5.6 / 5.8 / 5.9 bookkeeping commits

**Problem.** `/ak-build` Phase 5.6 (BUILD-LOG bookkeeping), Phase 5.8 (post-pre-ship docs+tests audit append), and Phase 5.9 (visual evidence refresh) each produce a commit that the project's pre-push reviewer flags as "PR description appears stale relative to commits — N additional commits without justification." The reviewer is correctly conservative by default. But the canonical phase commits are **defined to be additive** to whatever the PR body already says:

- **Phase 5.6** message pattern: `chore(build-log): record <feature>`. Edits PLAN.md + BUILD-LOG.md + PRODUCT-ROADMAP.md. The PR body's `**Docs**` paragraph already names "BUILD-LOG.md gains the canonical ship entry" — the commit IS the fulfillment of an already-described claim.
- **Phase 5.8** message pattern: `docs(<feature>): Phase 5.8 Audit 2 (post-pre-ship <findings-summary>)`. Edits only `specs/<feature>/review.md`, appending one `## Audit N` section. The PR body's `## Pre-ship audit trail` already attests Audit 1; Audit 2 is the documented Phase 5.8 step.
- **Phase 5.9** message pattern: `chore(<feature>): refresh visual evidence at HEAD (Phase 5.9)`. Edits only `specs/<feature>/{hero,screenshots}/*.png`. The PR body's `### Evidence` section already embeds those exact paths.

Each push after these commits triggers the reviewer, and each requires `git -c devshop.prDescStaleReason="..."` with a 2–4 line justification. The justification is **identical every PR** ("Phase N fulfills the already-described claim"). Sonnet adversarially reviews, accepts, push goes through. Net cost: one round-trip of operator + reviewer attention per Phase 5.6/5.8/5.9 commit per PR.

**Concrete from home-os PR #9** (2026-05-13):

- `00e614f` (Phase 5.6): blocked by pre-push reviewer; bypassed with `prDescStaleReason="The Phase 5.6 bookkeeping commit is the canonical /ak-build BUILD-LOG record for this PR..."`. Adversarial reviewer accepted (Sonnet ~30s).
- `9580061` (Phase 5.8): blocked; bypassed with `prDescStaleReason="Phase 5.8 audit commit only appends a clean Audit 2 section..."`. Adversarial reviewer accepted.

Both reasons collapse to the same pattern: **this is a known canonical phase commit, recognised by message prefix; the PR body's narrative covers it by reference.**

**Shape of the fix:**

Teach `check-pr-desc-staleness.sh` to **recognise** the canonical phase-commit patterns and auto-accept them WITHOUT requiring a bypass reason. Detection is regex-only on the commit message subject + the touched-file set; sub-millisecond compared to the Sonnet adversarial round-trip.

```bash
# kit/scripts/preship/check-pr-desc-staleness.sh — proposed addition

# Canonical /ak-build phase-commit patterns. Each pairs a subject regex
# with a file-touch allowlist. A commit matching BOTH is auto-accepted.
declare -a PHASE_PATTERNS=(
  '^chore\(build-log\): record [a-z0-9-]+$|^(PLAN\.md|BUILD-LOG\.md|PRODUCT-ROADMAP\.md|TODOS\.md)$'
  '^docs\([a-z0-9-]+\): Phase 5\.8 Audit 2|^specs/[a-z0-9-]+/review\.md$'
  '^chore\([a-z0-9-]+\): refresh visual evidence at HEAD \(Phase 5\.9\)$|^specs/[a-z0-9-]+/(hero|screenshots)/.+\.png$'
)

for pattern in "${PHASE_PATTERNS[@]}"; do
  subject_re="${pattern%%|*}"
  paths_re="${pattern#*|}"
  if echo "$LATEST_COMMIT_SUBJECT" | grep -qE "$subject_re"; then
    bad_files=$(git diff --name-only "$RANGE" | grep -vE "$paths_re" || true)
    if [ -z "$bad_files" ]; then
      echo "Phase commit pattern matched (subject + path allowlist); auto-accepting"
      exit 0
    fi
  fi
done
```

Three guards make this safe:

1. **Subject + path conjunction**: a `chore(build-log): record foo` commit that ALSO edits `apps/web/...` does NOT auto-accept (the path-allowlist catches scope creep).
2. **Exact-match regex on subject**: `chore(build-log): record foo BREAKING CHANGE` won't match.
3. **Range scope**: only the latest-commit subject matches, but the path-allowlist runs over the full range — catches bundling a Phase 5.6 commit on top of unrelated changes.

**Why v1 — not v0:**

- The cost is real (operator drafts the same recurring bypass reason every PR + Sonnet round-trip, ~30s × 2–3 phase commits per PR), but scales linearly with phase commits, not catastrophically.
- The bypass mechanism works correctly today; failure mode is paper cut, not silent risk.
- The v0 entries above this one (docs-coverage hook, PRODUCTION_URL onboarding) are higher-priority structurally — they cause silent gaps where this one only adds friction.

Promote to v0 if friction becomes load-bearing: e.g., if a future automation phase requires Claude to push without operator drafting bypass reasons.

**Trigger:**

- home-os PR #9 — 2 bypasses for canonical phase commits
- lalista PRs running `/ak-build` — same pattern at every Phase 5.6/5.8 commit
- Every future project: identical fact pattern guaranteed

**Cross-ref:**

- `/devshop/kit/scripts/preship/check-pr-desc-staleness.sh` — the reviewer to teach
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 5.6 / 5.8.3 / 5.9.2` — phase commit-message specifications
- home-os PR #9 — concrete bypass-trailer evidence at `00e614f` (5.6) and `9580061` (5.8)

**Cost/risk:**

- Implementation: ~1 hour (regex matrix + bats coverage for happy path + the "phase-commit subject + scope-creep file" failure case).
- Risk: low. Three guards layer; worst case is a benign scope-creep auto-accepts (caught by the next `/ak-pre-ship` audit or code review).
- Benefit: zero adversarial-reviewer round-trips for canonical phase commits; ~$0.05–0.10 saved per PR; operator attention freed from drafting the same justification every push.

[v1, surfaced-by home-os PR #9 § 5b reflection on 2026-05-13]

---

### JIT DB password entry for prod migration deploys via `/ak-go-live`

_Deferred from v0 on 2026-04-27 — no incident forcing it; lalista v0 GA (PR 7 + launch-day seed) ships first._

The just-shipped security-posture cleanup keeps `SUPABASE_DB_PASSWORD` as a GH Secret consumed by `deploy-migrations.yml`. That works but leaves the highest-blast-radius credential (direct Postgres access, bypasses RLS, full DB admin on prod) sitting in CI surface 24/7. Edge function deploys use only `SUPABASE_ACCESS_TOKEN`, so they don't have this concern; the asymmetry between functions and migrations is the lever.

**Shape of the fix** — split auto-deploy by blast radius:

| Surface        | Auto-deploy via GH?                           | Credential surface                                                                         |
| -------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Edge functions | ✅ keep — `deploy-functions.yml`              | Only `SUPABASE_ACCESS_TOKEN`; account-wide blast already in GH Secrets, narrow consumption |
| Migrations     | ❌ remove — operator-driven via `/ak-go-live` | DB password never enters GH; entered just-in-time at deploy moment                         |

**`/ak-go-live` flow change**:

1. After merging the PR, detect if `supabase/migrations/**` changed in the merged commits.
2. If yes, prompt the operator for `SUPABASE_DB_PASSWORD` via one of two paths (operator picks at `/ak-new-project` time + documents in CLAUDE.md):
   - **Path A — password manager CLI** (preferred when available): `op read 'op://Personal/<project>/db_password'` (1Password) / `bw get password '<project> db'` (Bitwarden) / `pass show <project>/db` (pass) / `gpg -d ~/.secrets/<project>-db.gpg` (gpg-encrypted file). Zero prompts; works in non-interactive Bash tool calls.
   - **Path B — `!`-prefix shell escape** (Claude Code session fallback): `/ak-go-live` emits a single `!`-prefixed multi-line block with `read -s -p "DB password: "` + `supabase db push`. The user's CLI has a TTY; `read -s` works; password doesn't enter the transcript because `read -s` doesn't echo and the variable lives in shell state, not stdout. One paste per migration deploy.
3. `/ak-go-live` runs `supabase link --project-ref <derived-from-SUPABASE_PROD_URL> && supabase db push --include-roles` with `SUPABASE_DB_PASSWORD` set inline (env var prefix on the command, never `export`ed; cleared from process state when the command exits).
4. Verify the push succeeded; continue with canary checks. If `supabase/functions/**` also changed, GH Actions' `deploy-functions.yml` already fired in parallel — `/ak-go-live` watches that run for the green check.

**Trade-offs vs the persisted-Secret status quo**:

| Aspect                         | Current (persisted Secret)                               | JIT prompt                                                                                                     |
| ------------------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Operator-side friction         | Zero — auto-deploys on merge                             | One paste per migration deploy (Path B) or zero (Path A)                                                       |
| GH Secret exposure window      | Indefinite — Secret sits there 24/7                      | None — DB password never enters GH                                                                             |
| `.devcontainer/.env` exposure  | DB password persisted on disk                            | Password lives only in password manager (Path A) or operator's memory at deploy moment (Path B)                |
| Catches "operator absent" race | Auto-deploys without supervision                         | Requires operator presence (a feature for prod migrations, not a bug; `/ak-go-live` is operator-driven anyway) |
| Failure mode                   | Workflow fails red in GH Actions; operator notices later | `/ak-go-live` reports failure inline; operator addresses immediately                                           |

**Implementation surface**:

Devshop side (`/devshop`):

- Delete `template/.github/workflows/deploy-migrations.yml`. Drop the `[deploy-migrations.yml]` row from any docs that list it.
- Update `/ak-go-live` skill (`.claude/skills/devshop/go-live/SKILL.md`) — add a "detect migration changes + JIT password fetch + local `db push`" phase between merge-complete and canary checks. Reference both Path A (password-manager CLI) and Path B (`!`-prefix), with detection: try Path A's CLI first (e.g. `command -v op`), fall back to Path B's `!`-prefix block if no manager CLI is present.
- Update `/ak-new-project` Step 5 — drop `SUPABASE_DB_PASSWORD` from the GH Secrets list (only `SUPABASE_ACCESS_TOKEN` + `ANTHROPIC_API_KEY_QA` + `ANTHROPIC_API_KEY_PROD` + `SENTRY_*` + `VERCEL_TOKEN` remain as Secrets).
- Update `/ak-new-project` Step 4 — remove `SUPABASE_DB_PASSWORD` from `.devcontainer/.env`. Add a new Step 4 sub-bullet asking the operator which password-manager path they'll use; document the chosen path in CLAUDE.md so `/ak-go-live` knows which to invoke.
- Update `/ak-new-project` § Security Posture — update the blast-radius table row for `SUPABASE_DB_PASSWORD` (now: lives only in password manager + Supabase project; never in GH Secrets / `.devcontainer/.env`).
- Update `/ak-new-project § Migration: existing project to current credential layout` — add a final step "delete `SUPABASE_DB_PASSWORD` GH Secret + `.devcontainer/.env` row; install your password manager CLI in the devcontainer; document the path in CLAUDE.md."
- Update `kit/docs/guide/conventions.md` § Deploy Boundaries — split the migrations row from the functions row in the auto-deploy table; note migrations are operator-driven via `/ak-go-live`.
- Update `kit/docs/guide/security.md` § CI Credential Isolation — add a third structural defense: "DB password is operator-side, entered just-in-time, never persisted in CI or `.env`."

Project side (any project that adopted the cleanup):

- Delete `.github/workflows/deploy-migrations.yml`.
- Update CLAUDE.md gotcha entry to reflect the operator-side migration flow + which password-manager path the operator chose.
- Update PR body's pre-merge actions — drop "Add GH Secret SUPABASE_DB_PASSWORD"; add "Install <password-manager-CLI> in devcontainer + provision the DB password item."
- Optionally rotate the prod DB password at this point — the prior value sat in GH Secrets, so assume it's burned.

**Why v1 (deferred from v0 on 2026-04-27)**:

This is the structural completion of the security-posture cleanup, not a "something is broken" fix. The cleanup closed the prod-service-role-in-CI gap by moving service-role to local-stack defaults; the symmetric move for DB password is to take it out of CI entirely. Without this, the cleanup is "partially structural" — service-role is fully off CI, DB password isn't. Closing the asymmetry is a small skill rewrite + a docs cascade; the cost is low compared to the principal-of-least-privilege payoff.

Demoted to v1 because: (a) lalista v0 GA depends on PR 7 + launch-day seed, neither blocked by this; (b) the existing GH-Secret flow has shipped successfully and there's no incident forcing the JIT move; (c) the docs cascade is cleaner once lalista has actually run a prod migration deploy via the existing flow at least once, so the JIT skill rewrite is informed by live operational experience rather than aspirational design.

**Trigger**:

- Lalista v0 GA ships and the existing auto-deploy migration flow runs at least once on a real prod migration; OR
- A second project adopts the devshop and the operator pushes back on persisting prod DB password in GH Secrets — that's the cue to ship.

**Cross-ref**:

- Security-posture cleanup (shipped via `631dc7e` on `feat/security-posture-cleanup`; entry closed and removed from `kit/ROADMAP.md` per the closing-entries rule) — the structural enabler this entry completes.
- `lalista/.github/workflows/deploy-migrations.yml` (5b248d9) — the file to delete project-side.
- `/devshop/.claude/skills/devshop/go-live/SKILL.md` — the skill to extend with the JIT phase.
- 1Password CLI: `op read` docs ([1password.com/downloads/command-line](https://1password.com/downloads/command-line)).
- `kit/docs/guide/security.md § CI Credential Isolation` — the home for the third structural-defense bullet.

**Cost/risk**:

- Implementation: ~2-3 focused hours (skill rewrite + doc cascade across 5 files + project-side mirroring + adversarial reviews × 2-3 cycles).
- Risk during rollout: if the password-manager CLI isn't installed at the moment `/ak-go-live` runs the JIT phase, fall-back to Path B (`!`-prefix) keeps the deploy unblocked — no infrastructure prerequisite.
- Benefit: fully closes the persisted-prod-credential-in-CI risk class; the DB password joins the prod service-role key in "lives in password manager + Supabase project, nowhere else." Combined with the just-shipped cleanup, CI's only prod-grade credential becomes `SUPABASE_ACCESS_TOKEN` (account-wide but narrow consumption — used only by `deploy-functions.yml` for management API auth).

---

### Tiered pre-ship pipeline

Auto-detect change scope and pick a tier:

- **Full** (schema, auth, new API, security): all steps
- **Standard** (UI features, new screens): skip `/cso` and `/benchmark`
- **Light** (bug fixes, styling, docs, config): lint + tests + `/review` + `/ship`

Announce which tier was picked. Override with `--full` or `--light`.

### Cheap-test-gates-local sub-fix 2 stage 2 — per-project `.devshop/test-impact.json` path-pattern map

**Problem.** The shipped `changed-tests-local` gate runs the convention-based smoke-set floor only — `apps/web/e2e/*-qa-walk.spec.ts` ∪ `apps/web/e2e/qa-walk.spec.ts`. A project that doesn't follow that convention gets no smoke set; a project that follows it gets a fixed-cost floor but nothing precision-targeted to the diff. The path-pattern layer is the next precision rung above the floor.

**Shape.** Per-project config at `.devshop/test-impact.json` (or `.devshop/test-impact.toml` — pick one) mapping changed source paths to spec paths via filename regex. Example:

```json
{
  "patterns": [
    {
      "match": "apps/web/components/(.+)\\.tsx",
      "specs": [
        "apps/web/e2e/$1-qa-walk.spec.ts",
        "apps/web/e2e/add-item-banner.spec.ts"
      ]
    },
    {
      "match": "packages/core/src/api/(.+)\\.ts",
      "specs": ["packages/core/src/api/$1.integration.test.ts"]
    }
  ]
}
```

`changed-tests-local.sh` reads the file (when present) AFTER the convention-based smoke set, deduplicates against already-running specs, and adds the resolved patterns to the spec list. Wallclock cap unchanged (specs that exceed the budget defer to CI per the existing triage line).

**Cost/risk.** ~2-3h (file format + reader + dedup + tests). Backward-compatible: projects without the file get the same behavior as today. Risk: false positives (running specs that don't actually exercise the diff) cost wallclock but never silent breakage.

### Cheap-test-gates-local sub-fix 2 stage 3 — import-graph match via `tsc --listFiles` / `madge`

**Problem.** Stage 2's path-pattern map catches the cases the operator can express as a regex; helper changes that ripple into specs without filename overlap escape it. The shipped `changed-tests-local` gate catches this only when the spec itself is in the diff.

**Shape.** For each changed source file, walk the TypeScript reference graph (`tsc --listFiles` or a lightweight tracer like `madge`) to find every spec that transitively imports the changed file. Cache the graph against the diff hash so repeated invocations within the same session don't re-walk. ~5-15s on a typical project.

The new match logic ORs with stage 1 (smoke set) and stage 2 (path-pattern map) — a spec runs locally if any layer surfaces it.

**Cost/risk.** ~3-4h (tsc/madge integration + cache + budget enforcement + tests). Risk: tsc invocation cost can spike on large projects — wallclock cap is the safety valve. Defer until the smoke + path-pattern layers prove insufficient on a real project.

### Lalista adoption of cheap-test-gates-local

**Problem.** The devshop ships the new gate, but lalista — the validation ground — needs an explicit adoption PR to (a) verify the convention-based smoke set fires correctly on a real diff (already organically present: `core-flows-qa-walk.spec.ts`, `disambig-add-new-hero-qa-walk.spec.ts`, `qa-walk.spec.ts`, `ci-slow-job-qa-walk.spec.ts`), (b) exercise sub-fix 3's `blocked` promotion against a real degraded-stack scenario, and (c) verify the bypass flow (`devshop.localTestSkipReason` + adversarial review).

**Shape.** Devshop pull, then a deliberately stack-needing PR (e.g. minor UI change in `apps/web/components/`) with the local stack stopped, observe the preflight emit `blocked:` for the stack-needing diff, fix recipe surfaces, restart the stack, the gate passes. Then a docs-only PR to verify the same degraded stack does NOT block (legacy `pass-with-note:` advisory). Add a short note to the project's CLAUDE.md or ROADMAP about adoption status. ~30 min once the devshop merge has propagated to the project.

**Cost/risk.** Pure validation — no code changes in the project. The risk is the gate firing falsely on a real diff (false positive caught by the validation PR; correctable in devshop if needed). The benefit is empirical confirmation that the convention-based smoke set + the D6 promotion both behave as specified.

### Persona-axis pre-ship gates (designer / backend-eng / frontend-eng / security / data)

**Problem.** Today the "hat" the pipeline reviews under is hardcoded into the gstack skill that runs the gate — `/review` carries the staff-engineer mindset, `/cso` the security mindset, `/design-review` the visual mindset. The operator has no surface for layering opinionated, project-specific philosophies on top: "we always prefer SECURITY DEFINER RPCs over service-role escalation," "our designer never uses centered headlines on long-form pages," "our backend convention is repository pattern, not active record." There's nowhere for those to live and be enforced. Putting them in `CLAUDE.md` (the Phase 1 fallback) makes them background context every skill sees, but doesn't enforce them — gstack's `/review` won't fail a PR for violating a project convention buried in a CLAUDE.md section unless the convention happens to overlap with what `/review` already checks for.

**The load-bearing constraint** — gstack is third-party. We cannot modify `/review`, `/cso`, `/design-review` directly because `/gstack-upgrade` will overwrite the changes. Customization has to live outside the gstack tree.

**Precedent.** `/ak-design-conformance` already solves this shape for one axis: gstack's `/design-review` covers visual hierarchy / typography / spacing / AI-slop patterns; the devshop-owned `/ak-design-conformance` runs alongside it in `/ak-pre-ship` and covers the orthogonal axes (DESIGN.md voice doctrine drift, explicit-token conformance, canonical-example matching, imperative `must/never` rules). Same pattern, applied to more personas.

**Shape of the fix** — per-persona devshop gate, layered defaults:

| Layer               | Path                                           | Inherited by                            | Owner              |
| ------------------- | ---------------------------------------------- | --------------------------------------- | ------------------ |
| 1. Devshop-default  | `/devshop/template/personas/<role>.md`         | every new project via `/ak-new-project` | devshop maintainer |
| 2. Project-override | `/workspace/personas/<role>.md` (project repo) | this project only                       | project operator   |

The devshop-side gate reads layer 1 (always present, ships with the template), then merges/overrides with layer 2 if the project has one. Override semantics: project-override file replaces specific named sections of the devshop-default (per-section override, not whole-file). Sections without a project-side override fall through to the devshop default. Each persona file follows the DESIGN.md template — normative claims expressed as `must / should / always / never` rules, plus canonical examples, scoped by file globs (e.g. `personas/backend-eng.md § Database access` claims apply when the diff touches `apps/web/api/**` or `packages/core/api/**`).

**Personas to ship — initial set:**

| Persona           | Devshop gate                               | Runs alongside                      | Scope (file globs)                                                  |
| ----------------- | ------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------- |
| `designer.md`     | `/ak-design-conformance` (extend existing) | gstack `/design-review`             | `apps/web/components/**`, `packages/ui/**`, `apps/web/app/**/*.tsx` |
| `backend-eng.md`  | `/ak-backend-review` (new)                 | gstack `/review`                    | `apps/web/api/**`, `packages/core/api/**`, `supabase/functions/**`  |
| `frontend-eng.md` | `/ak-frontend-review` (new)                | gstack `/review` + `/design-review` | `apps/web/components/**`, `apps/web/app/**`, `packages/ui/**`       |
| `security.md`     | `/ak-security-conformance` (new)           | gstack `/cso`                       | full diff                                                           |
| `data.md`         | extend existing `rls-coverage` gate        | —                                   | `supabase/migrations/**`, `packages/core/api/**`                    |

**Implementation surface:**

Devshop side (`/devshop`):

- New skills: `/ak-backend-review`, `/ak-frontend-review`, `/ak-security-conformance` under `/devshop/.claude/skills/devshop/`. Each follows the `/ak-design-conformance` template — extract normative claims from `personas/<role>.md` (LLM, cached by sha256 of merged file), verify each against the diff (grep for code-level claims, LLM-judge for prose claims), emit `pass | findings (N) [fixed|pending] | n/a`. Caching key combines devshop-default sha + project-override sha so layer changes invalidate correctly.
- Extend `/ak-design-conformance` to additionally read `personas/designer.md` (today it reads only DESIGN.md). Designer persona content is "philosophies and tendencies"; DESIGN.md is "system tokens and contracts." Both stay separate files; the gate reads both.
- Extend `rls-coverage` gate's helper script (`kit/scripts/preship/rls-coverage-check.sh`) to additionally consult `personas/data.md` rules (e.g. "all migrations must specify ON DELETE explicitly" — already a lalista convention, generalizable).
- New shared helper `kit/scripts/preship/persona-merge.sh` that produces the merged persona file (devshop-default + project-override) the gates read. Merge semantics + sha caching live here so each gate's SKILL.md stays thin.
- Wire all five into `/ak-pre-ship`'s gate ordering. Per `pre-ship/SKILL.md § Gates (canonical order + named IDs)`. Add gate IDs `backend-review (ak)`, `frontend-review (ak)`, `security-conformance (ak)`. Each gate's `n/a` rule fires when no persona file exists at either layer (so projects opt in by writing the file, not by editing the pipeline).
- New template directory `/devshop/template/personas/` with an initial set of stub files (designer, backend-eng, frontend-eng, security, data) — empty headers + the section template, no opinionated content yet. Populated incrementally from real shipping experience (don't pre-fill from imagination).
- Update `/ak-new-project` Phase B — add a step that explains the persona files: "if you have opinions about how backend code should be structured, edit `personas/backend-eng.md` here. Otherwise leave the file empty and the gate returns `n/a`."
- Update `kit/docs/guide/conventions.md` § DESIGN.md as Contract — generalize to "Personas as Contract" with DESIGN.md and personas listed as concrete instances of the same pattern.
- Update `kit/docs/guide/workflow.md` § Pre-ship gate map + the gate count (currently 14 → 16 after backend-review + frontend-review land; security-conformance is wired into the existing `cso` slot rather than as a new gate).
- Update `/devshop/CLAUDE.md` Tier 1 — add a "Persona-axis customization" entry explaining the layering so the rule is in always-loaded context.
- BATS test coverage in `kit/tests/` — at minimum a smoke test that the merge helper produces a stable output across `(default-only, override-only, both, neither)` permutations and that the cache invalidates on either file's sha change.

Project side (any project that adopts):

- Create `personas/` at repo root (gitignore nothing — personas are project-tracked).
- Edit `personas/<role>.md` files only when there's an actual opinion to enforce. Empty files → gate is `n/a`. Don't fill in slop just because the file exists.
- Phase 1 (CLAUDE.md sections) is **not deprecated** — it remains the cheap channel for cross-cutting rules that don't fit a single persona axis. Personas are for axis-scoped opinionated guardrails; CLAUDE.md is for everything else.

**Trade-offs vs the Phase 1 (CLAUDE.md sections) status quo:**

| Aspect                             | Phase 1 — CLAUDE.md sections                                                      | Phase 2 — persona files + gates                           |
| ---------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Setup cost                         | Zero — append a section to `CLAUDE.md`                                            | New skills + helper + template + gate wiring              |
| Enforcement                        | Background context only — gstack skills "see" it but don't fail PRs on violations | Gate-level enforcement; PRs blocked on violations         |
| Scoping                            | Loaded for every action regardless of relevance                                   | Loaded per-gate, scoped by file globs                     |
| Per-project override               | One `CLAUDE.md` per project (no devshop default to inherit from)                  | Devshop-default inherited; project-override layers on top |
| Cross-`/gstack-upgrade` durability | Safe (gstack doesn't touch `CLAUDE.md`)                                           | Safe (devshop-owned skills outside gstack tree)           |
| Failure granularity                | None — convention-violation just doesn't surface                                  | `findings (N)` with line-level diffs                      |

**Why v1 (not v0):**

Doesn't block next-project adoption. The first project (lalista) shipped successfully with no persona enforcement; gstack's general gates plus per-project `CLAUDE.md` covered the ground. The persona axis is "valuable opinionated layer," not "structural gap." Phase 1 (CLAUDE.md persona sections in `/devshop/CLAUDE.md`) gives 60% of the value at 5% of the cost — that should ship first as a v0 entry if the operator wants the surface immediately, leaving this v1 entry for promotion to enforcing gates.

**Trigger:**

- Phase 1 (CLAUDE.md persona sections) ships and the operator finds the rules getting ignored by gstack skills (because background-context isn't enforcement); OR
- A second project adopts the devshop and the operator wants to ship project-specific philosophies that the first project doesn't share (proves the override layer is needed); OR
- A specific class of bug ships through pre-ship that a persona rule would have caught — that's the case study justifying a new gate.

**Cost/risk:**

- Implementation: ~1 focused day per new gate (3 new gates + 2 extensions ≈ 4-5 days total). Each new gate is a SKILL.md + extraction script + adversarial review wiring + pre-ship registration, following `/ak-design-conformance` as the template.
- Risk during rollout: an over-eager persona file produces noisy `findings (N) pending` blocking PRs. Mitigation — every persona gate's `n/a` rule fires when the file is empty (just like DESIGN.md today), so adoption is opt-in section-by-section. Operator writes one rule, ships it, sees it fire, decides whether to keep going. No big-bang.
- Benefit: enforces project taste at the pipeline level, not just as background context. Per-role mindsets become first-class artifacts the operator can read, edit, version-control, and override per-project. The 3-layer model (gstack toolbox / devshop workshop / project) gets symmetric enforcement on each layer.

**Cross-ref:**

- `/devshop/.claude/skills/devshop/design-conformance/SKILL.md` — the working template for "devshop gate that reads a project-side contract file and runs alongside a gstack gate." All new persona gates copy this shape.
- `kit/docs/guide/conventions.md § DESIGN.md as Contract` — the convention that this entry generalizes from one file (DESIGN.md) to N files (personas/\*.md).
- `pre-ship/SKILL.md § Gates (canonical order + named IDs)` — the gate ordering registry that needs three new entries.
- `/devshop/template/personas/` — the new template directory this entry creates; new projects inherit it via `/ak-new-project`.

### Adversarial reviewer Phase 5 — tool-use grep for `dismissalLog`

_Deferred from the doc-inlining-architecture RFC (`kit/notes/roadmap/adversarial-review-doc-inlining.md` § Phase 5). Phases 1+2+open-Q1+open-Q4 shipped 2026-05-01 (commits 0fcd4c5, 9b18f46, 889c883). See [`kit/notes/roadmap/adversarial-review-doc-inlining-followups.md`](notes/roadmap/adversarial-review-doc-inlining-followups.md) for related deferred items (operational follow-ups, open Q2/Q3/Q5)._

Today the adversarial reviewer is no-tool (LLM gets a context block, returns PASS/FAIL). Rule 1(a)'s named-edits requirement is verified by the LLM scanning the inlined diff text — fast but bounded by what was inlined. For commit-time check-types this is fine (the diff is small, fully inlined). For pre-ship `dismissalLog` it's the wrong shape: each gate-run can fire up to 11 reviews, each reviewing claims like "covered by spec § In scope" or "this RLS policy is intentional per ARCHITECTURE.md § Auth" — the reviewer needs to verify those claims against current state on disk, not just what was pre-inlined.

**Shape of the fix** — equip the `dismissalLog` reviewer (only that check-type) with a `grep <pattern> <path>` tool. Branch on `case "$CHECK_TYPE" in dismissalLog) <use tool-equipped path> ;; esac` in `adversarial-review.sh`. Add a prompt instruction: "before passing a dismissal, verify the cited spec/doc claim by greping current state on disk." Commit-time check-types (`docsReviewed`, `dirtyTreeReason`, etc.) keep the no-tool fast path.

**Why deferred** — pre-ship pipeline already runs many gates serially with their own LLM calls; an extra tool-use round-trip per dismissal is negligible. Commit-time can't afford the variance because the user is waiting at the prompt. Splitting is correct, not premature.

**Implementation surface** — `kit/scripts/adversarial-review.sh` (case branch + prompt edit + tool wiring), `kit/docs/guide/hooks.md § Dismissal Log` (document the new tool), bats tests in `kit/tests/util-adversarial-review*.bats` (verify tool is wired only for dismissalLog).

**Sequencing** — wait for one cycle of real `dismissalLog` rejections that would have caught real drift if the reviewer could grep. Build the case in incidents, not speculation.

### Adversarial reviewer Phase 6 — out-of-band coherence sweep

_Deferred from the doc-inlining-architecture RFC (`kit/notes/roadmap/adversarial-review-doc-inlining.md` § Phase 6 / § 10). See [`kit/notes/roadmap/adversarial-review-doc-inlining-followups.md`](notes/roadmap/adversarial-review-doc-inlining-followups.md) for related deferred items (operational follow-ups, open Q2/Q3/Q5)._

Commit-time `docsReviewed` catches drift introduced **by** a commit. It can't catch drift that existed before the commit and survived. Across many commits, the doc set silently degrades — one entry says N, another says M, neither commit alone touched both. Today's only catch-mechanism is rule 1(c)'s cross-file-coherence sweep when reference docs are co-staged, which only fires on overlap.

**Shape of the fix** — periodic gate (e.g., weekly cron via `/schedule`) that reads all reference docs and asks the reviewer to flag contradictions across them. Output: a checklist of "X says A, Y says B — pick one." Operator (or a follow-up agent) reconciles.

**Why deferred** — the rule 1(a) sharpening landed in PR 9b18f46 already raises the per-commit catch rate substantially (validated by the reviewer catching three real coherence issues against this same RFC's own commits). Out-of-band sweep is a backstop, not the primary defense. Build it once we have data on what slips through despite rule 1.

**Implementation surface** — a new skill or scheduled agent (`/coherence-sweep` candidate name); reads all reference docs, drives the existing `adversarial-review.sh` engine in a "compare across all" mode (or builds a parallel one); reports out via Slack / Linear / a dedicated `kit/notes/coherence/<date>.md`.

**Sequencing** — also gated on Phase 5 landing first. Tool-use grep makes the coherence reviewer materially better at verifying claims across many docs in one pass; without it, a coherence sweep is a much more expensive token-burn.

### Weekly pg_dump backup (beyond pre-migration dumps)

Pre-migration `pg_dump` lands in Phase 1c. This v1 item adds a weekly scheduled
backup independent of deploys — catches data corruption that isn't tied to a
migration. GitHub Action cron → `pg_dump` → artifact or private gist.

### Devshop observability — skill invocation log

Each devshop skill appends one line to `kit/log.csv`:
timestamp, skill name, duration, outcome (pass/fail/paused), notes.
`/retro` reads it to inform retrospectives with real data instead of opinions.

### Migration rollback integration testing

CI runs migration forward → rollback → re-apply to prove rollback SQL actually
works against real data. Currently only syntax-validated (v0). Full forward+backward
testing catches data-dependent rollback failures.

### Automated service quota monitoring

GitHub Action cron (weekly or monthly) that checks usage against quotas for
Supabase, Sentry, PostHog, GitHub Actions, and Vercel. Warns when usage > 80%.
v0 has manual dashboard links in the guide; this automates the check.

### Local integration test alternatives to DinD

v0 uses Docker-in-Docker for `supabase start` inside the devcontainer (16GB+ RAM).
If DinD proves too heavy, evaluate alternatives: host-side Supabase with devcontainer
connecting via `host.docker.internal`, or optimized CI-only workflow.
Full research: `kit/notes/integration-test-local-alternatives.md`

### Subagent architecture for `/implement`

v0 uses single-agent implementation (full spec in one context, 1M model).
When context pressure is observed (agent losing track of earlier tasks, hitting
limits on large features), switch to orchestrator + per-task subagents.
Design: main agent manages TASKS.md, spawns subagent per task with task description,
relevant spec sections, hat principles, and a shared context summary file
(`CONTEXT.md`) that grows as tasks complete.
Trigger: when `/implement` starts losing context on features with 10+ tasks.

### Changesets

`@changesets/cli` + `.changeset/config.json` — automated changelog generation in PRs.
Removes manual CHANGELOG maintenance. Each PR includes a changeset file describing
the change; on merge, changesets auto-generates the changelog entry.

### `/ak-commit` skill + husky gate

Replace raw `git commit` with an `/ak-commit` skill that owns the full commit loop:
assess dirty state in both repos → classify files → plan commits → execute → verify
clean → repeat until done (or ask user for unknowns). Enforced by a husky pre-commit
gate (`check-ak-commit.sh`) that blocks raw commits — bypass requires a descriptive
reason, adversarially reviewed. Same pattern as `dirtyTreeReason` and `docsReviewed`.

Problem it solves: raw `git commit` has no skill-level orchestration of the
assess → classify → plan → commit → verify loop. The pre-commit husky gates
block bad commits and the pre-push gate blocks stale PRs / dirty pushes (since
the 2026-04-19 hook architecture migration), but neither plans multi-commit
sequences. `/ak-commit` would own the commit loop end-to-end, replacing raw
`git commit` for anything beyond a single-file change.

Full design: `kit/notes/ak-commit-design.md`

### PR-description staleness check — layer + approach decision

**Context:** The 2026-04-19 hook architecture migration replaced the old PostToolUse `check-pr-description.sh` with a blocking `.husky/pre-push` check (`prDescStaleReason`). It catches a real observed bug — Claude has been seen pushing new commits without updating the open PR's title/body. But the current implementation fires the adversarial reviewer on EVERY non-trivial push, and a blank bypass reason auto-rejects regardless of whether the description is actually aligned → per-push friction even when the description matches. Tactical TODO + inline options captured in `kit/TODOS.md`.

**Alternatives considered (2026-04-19 session):**

- **(A) Prompt tune.** In `kit/scripts/adversarial-review.sh`, run item 8(a) "PR description genuinely matches the commits" alignment check BEFORE the generic blank-reason auto-reject path. Keeps the reviewer always-on; reduces false positives on aligned descriptions. ~10 LoC. Risk: shared-engine regression on other check types that rely on the "blank reason → generic → reject" semantics.
- **(B) Symptom detection in the hook** ("reframe-B"). Short-circuit when PR title prefix matches the highest-impact commit prefix + no bypass reason set → skip reviewer. Fire reviewer only on prefix mismatch OR explicit bypass. Parallels the `check-clean-tree.sh` pattern — deterministic symptom gate, reviewer only for edge cases. ~15-20 LoC in `.husky/pre-push`. False negative: title-aligned-but-body-stale slips through — same miss rate as the old advisory-hook era. Acceptable tradeoff per hook-migration precedent.
- **(C) Both A + B.** Most robust. Moderate effort.
- **(D) Drop the hook check entirely.** Rejected — the forget-to-update-PR bug has been observed in practice; the hook is earning its place.
- **(E) Move to skill layer.** Remove from the hook; add "verify + update PR description" step to skills that own PR operations (`/ship` gstack, `/ak-build` Phase 5 devshop, future `/ak-ship-devshop`). Architecturally cleaner: workflow concerns in workflow-owning skills, hook layer reserved for safety invariants (dirty tree, stash, release-coverage). Gap: ad-hoc `git push` from Claude outside pipeline-driven skills would have no check. Could combine with (B) as "hook = safety net for ad-hoc pushes, skill = active workflow step."

**Current lean:** (B) as the hook tune + (E) added to `/ak-build` Phase 5 in a separate follow-up. Hook stays as the belt-and-suspenders safety net for ad-hoc pushes; skill step is the active reminder where most PR operations actually happen.

**Decision trigger:** after PR 3 (`/ak-build core-flows`) has surfaced real data on (a) the false-positive rate of the current always-fires implementation, (b) whether the prefix-match heuristic holds up against real PR-desc patterns, (c) whether Claude's forget-to-update bug recurs during PR 3's pushes. Decide between A / B / C / E / hybrid with evidence.

**Cross-refs:** `kit/TODOS.md` (tactical TODO — compressed to a pointer back to this section). Origin in the 2026-04-19 hook architecture migration — see git log around v1.10.0.

### `/ak-merge-devshop` skill — audit + ff-merge + push + cleanup

**Problem.** Devshop has no GitHub PRs and no `/ak-go-live` equivalent. The merge moment today is multi-step and entirely manual: invoke `/ak-check-docs-and-tests` before each ff-merge, react to high/medium findings on the branch, ff-merge to main, push, delete the merged branch local + remote, optionally hand off to `/ak-release-devshop` if a tag is warranted. Skipping the audit step is silent — pre-commit Layer 1 has no concept of "merge moment" and won't catch the omission.

The PR-A+B+C inaugural devshop run (2026-05-07) made the gap concrete: the operator ran `/ak-check-docs-and-tests` manually, the audit caught 7 medium drift findings against a clean-attestation bypass body, the operator iterated on the branch (a fix commit), re-ran the audit (Audit 2 clean), then ff-merged. Every step was correct but every step was hand-driven. The skill captures that exact sequence so the next devshop merge doesn't depend on operator memory.

**Shape.** Closer to `/ak-go-live` than `/ak-build`. `/ak-build` is the build pipeline (spec → implement → ship); `/ak-go-live` lands what the build produced (land → deploy → verify). The devshop analog of `/ak-go-live` is "audit → ff-merge → push → cleanup → optional release" — that's this skill. Naming `/ak-merge-devshop` mirrors the existing `/ak-release-devshop` suffix pattern.

**Scope (skill steps):**

1. **Sanity preconditions.** Assert: on a non-`main`/`master` branch (audit is feature-level — `/ak-check-docs-and-tests` already errors out on `main`, but catching it here surfaces the misuse with the right framing); working tree clean (no unstaged changes — operator's stashable WIP is theirs to manage before invoking, not the skill's to handle implicitly); branch fast-forward-able onto `origin/main` (no divergent history).
2. **Run `/ak-check-docs-and-tests`** over `origin/main..HEAD` (skill computes the range itself; this skill just invokes it). Halt on any high-severity finding — surface them and exit with a fix-then-rerun message. On medium-only findings, surface them and ask: fix on branch, accept and continue, or abort. Default to "ask" — the convention I wrote into `CLAUDE.md` says "before each ff-merge"; the skill enforces by making the audit non-skippable, not by auto-deciding what to do with mediums (they're judgment calls). Pre-PR-C the project-side equivalent decision was the human-driven "review the PR" step; devshop has no PR review surface, so the skill's medium-handling IS the review surface.
3. **ff-merge to main + push.** `git checkout main && git merge --ff-only <branch> && git push origin main`. The pre-push hook's devshop-mode short-circuits on push to main (no PR-desc check, no main-block) so no friction. Idempotent: if main is already at branch HEAD (operator already merged manually), step is a no-op rather than an error.
4. **Branch cleanup.** `git branch -d <branch>` + `git push origin --delete <branch>` if the remote ref exists (silently no-op if it doesn't — the inaugural PR-C run exercised this; the branch never had an origin counterpart).
5. **Release suggestion (chained, not auto-run).** Run the same logic `/ak-release-devshop` Phase 0 uses to decide if a bump is warranted (commits since last tag include `feat:` / `fix:` / `BREAKING CHANGE:`). If yes, surface the suggestion + the proposed bump tier, but do NOT auto-invoke `/ak-release-devshop` — release is a deliberate decision per the existing convention. Operator decides whether to chain it. (Compare to `/ak-go-live`'s decision to chain `/canary` automatically: there, the deploy is non-optional once the merge lands; here, the release is optional even when there are shippable commits.)

**Cost/risk.**

- Implementation: ~3–5h. Most of the logic exists — `/ak-check-docs-and-tests` is the heavy lifting and already shipped in PR-A; the merge / push / cleanup sequence is 4 git commands; the release-suggestion logic lifts the existing `release.sh` tag-derivation. The skill body is mostly orchestration + UX (medium-finding decision prompt, halt messages, idempotence checks).
- Risk: medium-finding handling is the load-bearing UX call. Auto-accepting mediums would defeat the audit's purpose ("the audit is the review"); auto-blocking on any medium would over-correct and produce a "kit/notes/\*\* mention is medium because grep matched it" friction loop. Defaulting to "ask" is the right escape hatch for a single-developer flow but means the skill can't run unattended in a CI-like context (devshop has no CI; this constraint is acceptable).
- Benefit: makes the convention enforceable rather than aspirational. Shifts the audit from "operator remembers to run it" to "the merge entry point IS the audit." The PR-C session's manual sequence becomes one command.

**Out of scope (separate roadmap entries):**

- **Mode-aware `/ak-build` for devshop** — covered by the next entry (`Devshop self-build pipeline`). That's the build-side counterpart; this is the merge-side counterpart. Ship them independently if at all.
- **Auto-chain to `/ak-release-devshop`** — release deliberation has historically been non-automatic; that stays. The skill suggests, doesn't act.
- **Auto-fix medium findings** — categorically not the skill's job. Audit-time review surfaces; operator decides; skill records the decision (via the audit's `## Audit N` section + the merge commit's audit pointer). Auto-fix would re-introduce the per-commit Sonnet pattern PR-C just removed.

**Trigger.** Lands when the next devshop merge is queued — the inaugural PR-C run is the validating use case behind this entry; the next devshop merge is the trigger to ship the skill rather than re-run the manual sequence.

**Cross-refs:**

- `/ak-go-live` (project-side analog).
- `/ak-release-devshop` (chained from this skill's step 5).
- `/devshop/CLAUDE.md § Devshop shipping flow` (the convention the skill enforces).
- `CLAUDE.md § Non-Negotiables` — "Adversarial Layer 2 reviews fire at audit moments, not per commit" (the "before each merge to main" rule the skill operationalizes; structural migration shipped via PR-A/B/C `b02d531`/`a0f1705`/`a2e1f34`).

### Devshop self-build pipeline

Use the project build machinery (`/ak-build`) for devshop changes themselves.
Currently devshop work is manual: branch, edit, commit, push, PR. The project pipeline (spec → implement → quality gates → ship) is
tightly coupled to project conventions (specs/ dir, metrics, responsive/theme
checks) and doesn't fit devshop changes.

**Options (pick at implementation time):**

- **`/ak-devshop-build`** — lighter devshop-specific pipeline: branch → edit →
  commit guard → docs consistency check → push → PR. Reuses `/ship` for the PR
  step. Skips specs, metrics, responsive checks.
- **Mode-aware `/ak-build`** — detect devshop branch prefix → swap in devshop
  conventions (devshop commit prefix, docs drift checks, script tests) instead of
  project ones. Single entry point but more complex.

**Devshop quality gates (different from project):**

- Commit guard passes (no mixed commits)
- Docs consistency (three-way: CLAUDE.md ↔ README ↔ GUIDE)
- Script tests (when they exist — see TODOS.md)
- No responsive/theme/metrics checks

**Trigger:** when devshop changes become frequent enough that the manual
branch-edit-commit-push flow feels like friction.

### CLAUDE.md block assembly

Template snippets in `kit/templates/claude-blocks/` — one per technology choice
(`supabase.md`, `vercel.md`, `posthog.md`, `sentry.md`, etc.). Each block contains the
env vars, migration commands, file path patterns, and conventions for that tool.

`/ak-init` assembles the project's `CLAUDE.md` from the relevant blocks based on which
services are set up (steps 3-6 already know). Same content across all projects using
the same stack; different for projects with different tech choices.

`/document-release` maintains "Where Things Happen" as paths get added post-init.

### Staging migration validation

Local `supabase start` and CI both run migrations against fresh DBs from seed.sql.
Neither tests against production data shapes. Data-dependent migration failures
(NOT NULL on columns with legacy nulls, table locks on large tables) only surface
in production. `-- ROLLBACK` and `pg_dump` are recovery, not prevention.

Options:

- Restore latest pg_dump into temporary local Supabase, run new migration against it
  before deploying (automated in `/post-merge`)
- At minimum, make every migration a "stop and ask" item with human review against
  production schema (already the convention — this automates verification)

### Accessibility testing in E2E (axe-core)

`eslint-plugin-jsx-a11y` already runs via `eslint-config-next`. Add runtime a11y
testing with `@axe-core/playwright` in E2E tests — catches issues that static
analysis misses (dynamic content, focus management, ARIA state). Wire into Playwright
test setup so every E2E page visit runs an axe scan.

Trigger: when the first E2E-testable flow exists (Phase 1e or equivalent).

### Sync script improvements

Current: simple `cp` guided by `manifest.txt`. Improve to:

- Diff before overwrite — show what changed, ask for confirmation
- Create PR on the devshop repo instead of direct push
- Conflict detection with abort + diff shown

### `/ak-collateral` skill — marketing / landing-page asset composer

Devshop has design-ops skills (`/design-consultation`, `/design-review`, `/plan-design-review`) but nothing that composes marketing collateral. Produce README banners and landing-page imagery from assets the pipeline already generates.

**Shape (not final):**

- Inputs: latest `specs/<feature>/hero/*.png` across merged features, project `README.md`, `DESIGN.md` tokens, optional `PRODUCT-ROADMAP.md` teaser line.
- Output: one or more composed PNGs (README banner, social card, hero strip) + an HTML landing-page layout (one page, static, design-system-consistent) in `docs/collateral/` or similar.
- Related: similar compositional pattern to `/design-html` + `/design-shotgun` — reuse that infrastructure if possible.

**Why not now:**

Projects need something to showcase before showcase tooling matters. lalista is pre-MVP (PR 2 = auth, PR 3 = core flows) — nothing to feature yet. The `guide/conventions.md § Screenshot Routing` table explicitly defers README-banner / marketing imagery until "the first project needs one." When the first flow ships with a visible product surface, that's the signal to build this.

**Trigger:**

- First project has at least one merged feature with committed `hero/*.png` showing end-user value (not just an auth gate).
- OR: user explicitly asks for a README banner and we realize this is the fourth ad-hoc composition request.

**First-pass design work:**

- Whether to reuse `/design-html`'s Playwright + screenshot pipeline vs. a new sharp/canvas-based compositor.
- Whether output lives in `docs/collateral/` (per project) or `specs/_collateral/` (spec-adjacent).
- How to handle brand assets (logo, fonts) — point at `DESIGN.md` token set or require a separate brand kit.

### Invite-code signup control — opt-in at `/ak-new-project`

Some projects launch invite-only (private beta, controlled rollout, reputation-protection while testing). Supabase's built-in signup is open by default; the only lever is `disable_signup: True` which blocks everyone indiscriminately. Invite-code gating is the common middle-ground and will be a repeat request.

**Shape (not final):**

- **Migration**: `invite_codes` table — `id uuid`, `code text unique not null`, `created_by uuid references auth.users(id)`, `used_by_user_id uuid references auth.users(id)`, `created_at`, `expires_at`, `invalidated_at`, `notes text`. RLS: service_role full access; authed users can only SELECT their own redeemed code (for UI confirmation).
- **Admin RPCs** (SECURITY DEFINER, grant to `authenticated` with admin check inside):
  - `create_invite_code(p_notes text, p_expires_in interval default '30 days')` returns `text` (the new code).
  - `invalidate_invite_code(p_id uuid)` returns `void`.
  - `list_active_invite_codes()` returns `setof invite_codes`.
- **Edge function `signup-with-invite`** (public endpoint) — accepts `{email, password, invite_code}`, validates the code against the table, marks it used atomically, calls `auth.admin.createUser` with service role. All in one transaction so a failed `createUser` doesn't burn the code.
- **Supabase auth config**: `disable_signup: True` to force all signups through the edge function.
- **Optional admin surface**: simple CLI script under `kit/scripts/invite-codes.sh` (list/generate/invalidate). A full UI page is project-specific — out of scope for the devshop template.

**Integration pattern:**

- `/ak-new-project` Phase B: interactive prompt "enable invite-code signup control? [y/N, default N]". If yes, run an `ak-scaffold-invites` sub-step that:
  1. Drops the migration into `supabase/migrations/`
  2. Drops the edge function into `supabase/functions/signup-with-invite/`
  3. Patches auth config to `disable_signup: True`
  4. Drops the CLI script + seed invite code into `kit/scripts/`
  5. Updates project `README.md` with a "Closed beta — signups require an invite code" note
- If no, skip — open signup stays default. Projects can opt in later by running the same scaffold-invites step manually (or via a future `/ak-add-invites` skill).
- Existing projects (like lalista) that want to adopt invite-only post-launch: point them at this scaffold flow.

**Why v1, not v+:**

This was the second auth-hardening request in one conversation (password_min_length: 8 was first, now invite-code gating). Paired with the Supabase hardening step shipping in Step 2 — the auth-defaults story is incomplete without a controlled-signup option. Invite-only is table stakes for any serious closed-beta launch; waiting until v+ means the first project needing it gets an ad-hoc implementation.

**Trigger:**

- First project explicitly asks for invite-only signup (lalista might; future projects very likely when launching)
- OR: second project adopts the devshop and hits the same "bots will hammer the site" concern — that's the "don't forget reviewing this again on next project" moment

**Cross-ref:**

- The `/ak-new-project` Phase B auth-hardening step (landed in devshop v1.11.0) — mandatory password-length + interactive CAPTCHA ship first; invite-code gating is the next layer up for projects that need it.

### `/setup-email` skill — custom-domain transactional emails (Resend + Supabase Auth SMTP)

Devshop projects ship on Supabase's default sender (`*.mail.app.supabase.io`) for v0 — fine for closed dogfood behind a "we're early" footer note, looks like phishing the moment unfamiliar users see it. The cutover to a branded `from:` address is a multi-surface operator dance: domain at the registrar, Resend signup + SPF/DKIM/DMARC, Supabase dashboard SMTP + templates + URL allow-list, plus repo-side edits (config.toml SMTP block, email-template logo URL, drop "Supabase is the messenger" footer, CLAUDE.md gotcha for the three-surface dance). Each piece is small but the orchestration is non-obvious, especially "templates in `supabase/templates/*.html` don't auto-deploy — you must paste into the prod dashboard" (this trap caught lalista at chapter 1l ship time).

**Why a dedicated skill instead of folding into `/ak-new-project` Step 3 (account creation):**

- Resend earns its keep ONLY after a custom domain is provisioned. At new-project time, projects are on `<project>.vercel.app` and don't have a domain yet — Resend signup at day 1 just leaves an unverified domain on their dashboard.
- DNS verification is async (5min–2hr); the new-project flow can't block on it, so half the setup gets deferred anyway.
- Not every project needs transactional email (internal tools, B2B with SSO, CLI products) — making it a Step 3 line item adds friction with no payoff for those.
- The trigger isn't "creating a project"; it's "you have a domain and want branded emails." Those are decoupled in time. Lalista hit the email-cutover moment ~6 months after `/ak-new-project` ran.

**Shape (not final):**

- Precondition check: project has a verified custom domain (read from CLAUDE.md § Deploy Configuration, or prompt). Block + pointer to "buy a domain first" if not.
- Walk the operator through Resend: sign up at resend.com, add domain, copy 3 DNS records (SPF `TXT @ "v=spf1 include:_spf.resend.com ~all"`, DKIM `TXT resend._domainkey ...`, DMARC `TXT _dmarc "v=DMARC1; p=none; rua=mailto:dmarc@<domain>"`), wait for verification, mint API key, **1Password reminder** (never local disk, never `.env`).
- Walk the Supabase dashboard:
  - Auth → SMTP Settings: paste host `smtp.resend.com`, port `465`, user `resend`, password `<API key>`, sender email `noreply@<domain>`, sender name = project name.
  - Auth → Templates: paste each `supabase/templates/*.html` body + subject (the dashboard does NOT pull from the repo — this is the trap).
  - Auth → URL Configuration: Site URL = canonical custom domain; allow-list includes `https://<domain>/auth/callback?**`.
- Repo edits: uncomment-form update to `supabase/config.toml [auth.email.smtp]` block (Resend recipe, kept commented — local-dev still mailpit, prevents test traffic burning the free tier); drop "Supabase is the messenger" footer from email templates; swap email-logo URL from `*.vercel.app` to custom domain; add CLAUDE.md gotcha capturing the three-surface dance + the "templates don't auto-deploy" trap.
- Smoke test from a clean inbox: confirmation + forgot-password emails. Verify `from:` reads project name, DKIM=PASS in Gmail "Show original", inbox placement = primary tab, links land on canonical domain natively (no redirect hop).
- Optional commit + PR.

**Trigger:**

- Second project adopts devshop and hits the "default sender looks like phishing past first users" gap — that's the moment to encode the skill.
- OR: lalista hits the cutover a second time on a future project, or has to repeat any part of the dance (unlikely — it's mostly one-shot per project).

**Why v1, not v+:**

The diff is well-understood now (lalista ran it 2026-05-05). Encoding is cheap relative to the payoff — every project past closed dogfood needs this, and the operator-time cost of doing it ad-hoc each time is meaningful. Deferred to v1 (not v0) because no project is currently in the "second time" state — lalista's first run IS the reference implementation, and the skill earns its keep on project #2.

**Cross-ref:**

- Pattern reference: lalista's cutover branch (commit lands as the canonical diff template the skill applies elsewhere). Touched files: `supabase/templates/{confirmation,recovery}.html`, `supabase/config.toml`, `OVERVIEW.md`, `PRODUCT-ROADMAP.md`, `CLAUDE.md`.
- Related skill shape: `/setup-deploy` is the precedent — "you have a thing (deploy target), walk through configuring it." Same skeleton applies here.
- Related v1 dependent (lalista-side): `PRODUCT-ROADMAP.md § v1 § Existing-account sign-up nudge email` has a hard dep on custom-domain SMTP being live. `/setup-email` is the prerequisite that unblocks it.
- `/ak-new-project` Step 3 (account creation) deliberately does NOT include Resend per the rationale above; instead, Step 23-equivalent (deferred/post-launch items) gains a pointer: "When you have a custom domain and want branded emails, run `/setup-email`."

**Source:**

- This entry surfaced 2026-05-05 in the lalista cutover conversation. Operator asked "should we add Resend to `/ak-new-project`'s services list?" — recommendation was a separate `/setup-email` skill rather than bundling into new-project, for the reasons above. Filed for v1 per operator direction in same conversation.

---

### Project-side devshop version tracking + upgrade-gap surfacing

**Problem.** Today there's no mechanism for a project (lalista et al.) to know which devshop version it was scaffolded against, nor for `init-devshop.sh` (or any session-start hook) to surface "your project is N versions behind the live devshop; here's what's changed in between." The devshop ships releases (`/ak-release-devshop` cuts tags from `kit/version`); projects pin nothing and discover drift only when a skill behaves unexpectedly or a convention referenced in a doc no longer matches the current devshop. The asymmetry is: devshop knows its own version; projects don't know the devshop version they're built against.

A second problem: there's no ambient pressure to propagate devshop improvements to existing projects. A new convention codified in `/devshop/CLAUDE.md § Foo` only lands in the projects that happen to have a session active when the convention ships — older projects keep operating on stale assumptions until their operator manually re-reads devshop docs (rare). The result: each project's behavior drifts from the current devshop's assumed-shared baseline at a rate that scales with elapsed time, and the only recovery is post-hoc "why is this skill failing on lalista but not abracadabra" debugging.

**Shape of the fix:**

1. **Project records the devshop version it was built against.** `/ak-new-project` writes `<project>/.devshop-version` (or a JSON `<project>/.devshop/state.json` if multiple state fields accumulate) at scaffold time, containing the `kit/version` of the devshop release used. Tracked in git; explicitly NOT a generated artifact.

2. **Session-start hook diff.** The existing `kit/scripts/session-start.sh` (which already injects different context for project vs devshop sessions) reads `.devshop-version` and compares to `/devshop/kit/version`. When the project is behind:
   - One-line at session start: `📦 Project on devshop v0.7.2 → live is v0.9.1 (N releases behind). See /devshop/kit/docs/CHANGELOG.md for what's changed.`
   - Don't block; don't auto-upgrade — surface only.

3. **`/ak-upgrade-devshop` skill (new).** Operator-invoked when they're ready to bring a project's conventions / template files / skill assumptions up to current. The skill:
   - Reads the project's pinned version + devshop's current version.
   - Walks `kit/docs/CHANGELOG.md` entries between them, classifying which entries imply project-side action (e.g., "new convention X in `/devshop/CLAUDE.md` — rewrite project's Y to match") vs project-irrelevant (e.g., "internal devshop refactor").
   - Surfaces the action items as a checklist; operator approves or skips each. Skill applies the approved diffs.
   - On completion, bumps `<project>/.devshop-version` to the new version + commits.

4. **Decoupled from `/ak-merge-devshop`.** Deliberately. Merging a feature on the devshop side does not auto-propagate to projects — projects could be many, and coordinating each devshop release with active project work breaks the user's scaling assumption ("we shouldn't on every devshop release ask about this"). Upgrade is operator-initiated per-project, on the project's schedule.

**Why deferred to v1:** the gap is real but not blocking next-project adoption. The first project (lalista) is on the devshop's working tree directly via the `.devshopkit/` symlink; there's no "version pinning" — every devshop change is immediately visible to lalista. The convention drift problem only emerges when a second project exists AND that second project is decoupled from devshop main (e.g., scaffolded against a tagged release). v0 work doesn't hit this; v1 onboarding of a second project will.

**Implementation surface (when picked up):**

- New file: `/devshop/template/.devshop-version` template (just contains the placeholder `__DEVSHOP_VERSION__` that `/ak-new-project` substitutes).
- Edit `/ak-new-project` Step N (scaffold time): write `.devshop-version` with current `cat /devshop/kit/version`.
- Edit `kit/scripts/session-start.sh` (project session branch): read + diff + emit upgrade-gap line.
- New skill: `/devshop/.claude/skills/ak-upgrade-devshop/SKILL.md`.
- `kit/docs/CHANGELOG.md` discipline: entries that imply project action need a structured marker (e.g., `**Project action:** rewrite X to match Y`) so the upgrade skill can extract them. `/ak-release-devshop` Phase 2 (changelog generation) is the right place to enforce the marker convention.

**Source:**

- Surfaced 2026-05-07 during the `/ak-merge-devshop` design conversation. Operator pushed back on a coordinated-change check at merge time, observing: "in the case we need to do changes on the projectS (plural) side so they support the newest version of the devshop... seems like we should have a way that when we open the project, the init-devshop brings it up to date. Perhaps we'll need some tracking of the devshop version a project has been built with so far. But definitely we shouldn't on every devshop release ask about this, since projects could be many." This entry captures that idea verbatim before it's lost.

---

## v+ (future — when the need is felt)

### Full Finding Router — structured `disposition:` per gate dismissal

**What this is** — an extension of the Dismissal Log (see `.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`). Today every `/ak-pre-ship` gate's report includes a `## Dismissals` section where findings the gate chose not to fix get a free-text `rationale:` field. The Finding Router adds a **structured `disposition:` field next to each rationale**, turning "here's why I dismissed this" into "here's what should happen with this finding" — and then the pipeline does the appropriate thing with each.

**Background — why it's deferred until now**

The 3-PR gstack-guidance-enforcement work (landed in devshop v1.16 as `feat/preship-dismissal-log` + `feat/preship-core-user-story` + `feat/preship-design-conformance`) sized the Finding Router as the fourth and largest piece, intentionally cut out to land the other three first:

- Dismissal Log (the scaffolding) forces every gate to make triage explicit and gives us an adversarial-reviewed `rationale:` field — catches silent dismissals now.
- Core User Story + Gate 9 artifact assertion — catches silent no-ops (the original `add-sheet open+Escape` failure mode).
- Design-conformance gate — catches DESIGN.md drift the visual `/design-review` gate doesn't check.

All three closed the concrete bugs that motivated the work. The Finding Router is the clean-up layer: it takes the `rationale:` data the other three produce and routes it into concrete actions.

**What the router adds**

Five dispositions, each mapped to a pipeline action:

| `disposition:`    | Meaning                                                  | Pipeline action when the gate emits this                                                                                                          |
| ----------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fix-now`         | Real bug, must resolve in this PR                        | Agent fixes inline, commits (atomic per finding), gate re-runs                                                                                    |
| `fix-before-ship` | Must resolve before merge, but not necessarily right now | Appends a must-fix checkbox to the PR body; `/ak-build` Phase 6 verifies these are checked before declaring ready-for-review                      |
| `TODO`            | Valid concern, out of scope for this PR                  | Auto-append to `TODOS.md` with source tag (`[gate-name]`) so the next `/ak-status` surfaces it                                                    |
| `spec-amendment`  | Spec was ambiguous, not a real implementation gap        | Auto-amend `specs/<name>/spec.md` with the clarification + commit; gate re-runs against the clarified spec                                        |
| `ignore`          | Not actionable (false positive, out-of-scope-forever)    | Noted in `review.md` with reasoning — stays searchable but takes no pipeline action. This is the ONLY disposition Phase 3's MVP implements today. |

**How it composes with Phase 3's Dismissal Log**

Today's `rationale:` bullets stay exactly as-is. A Phase 4 dismissal just gains a `disposition:` line adjacent to the `rationale:`:

```markdown
## Dismissals

- polish-tier visual tweak on settings page
  - rationale: nits a designer would fuss over, but off-path for PR 3's core-flows scope
  - disposition: TODO
```

Dismissal-Log entries written before Phase 4 still parse — they just lack `disposition:` and route through the `ignore` path by default (current behavior). Net effect: additive, not migrational.

**Per-gate routing rules — where incremental lands**

This is where "Phase 4 wires gates incrementally" makes sense. Each gate has different severity taxonomies, and the mapping from a gstack finding to a `disposition:` isn't one-size-fits-all:

| Gate                 | Finding source                                          | Mechanical mapping possible?                                                                                   | Suggested landing order                     |
| -------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `/cso`               | JSON with `severity: CRITICAL\|HIGH\|MEDIUM\|TENTATIVE` | Yes — CRITICAL/HIGH → fix-now, MEDIUM → TODO, TENTATIVE already auto-dismisses via the Phase 3 shim            | 5th (mechanical, easy win)                  |
| `/benchmark`         | Metrics + thresholds (LCP, CLS, bundle size)            | Yes — threshold-based routing; above-threshold → fix-now, borderline → TODO, within-threshold already filtered | 6th                                         |
| `/qa`                | Prose findings with Critical/High/Medium/Low severity   | No — needs LLM judgment ("is this High severity blocker for this PR or not?")                                  | **1st (highest subjective-judgment value)** |
| `/design-review`     | Visual issues with impact rating (High/Medium/Polish)   | No — same reason as `/qa`                                                                                      | 2nd                                         |
| `/ak-test-review`    | Prose findings about test quality                       | No — needs judgment                                                                                            | 3rd                                         |
| `/review`            | Inline code-review comments + Greptile triage           | No — needs judgment                                                                                            | 4th                                         |
| `/simplify`          | Duplications / over-abstractions                        | Mostly auto-fixes inline today; router handles the residual                                                    | 7th                                         |
| `design-conformance` | Per-claim `needs_review` entries                        | No — needs judgment against DESIGN.md                                                                          | Bundle with `/design-review` (2nd)          |

Each gate's routing rules live in a small file under `kit/scripts/finding-router-rules/<gate>.sh` or similar — a per-gate mapping function that takes a finding (with severity + description) and returns a disposition.

**Adversarial review expansion**

The existing `dismissalLog` check-type in `kit/scripts/adversarial-review.sh` (landed in Phase 3) judges `rationale:` quality. Phase 4 extends the same check-type — or adds a sibling `dispositionRouting` check-type — that also judges whether the chosen `disposition:` is plausible given the rationale + the spec's `## Core user story` + `## In scope`. E.g., dismissing a core-story-touching finding as `ignore` with a vague rationale should be rejected.

**Concrete implementation sketch**

When Phase 4 lands:

1. **`kit/scripts/finding-router.sh`** — new script with subcommands: `route <gate> <findings.json>` (apply gate-specific rules + emit dispositions), `execute <disposition-plan.json>` (perform the pipeline action per entry), `verify <feature>` (confirm every fix-before-ship entry is actually resolved before declaring gate pass).
2. **`kit/scripts/finding-router-rules/<gate>.sh`** — per-gate mapping functions, starting with `/qa` and `/design-review` as the first wired gates. Other gates route everything through `ignore` by default until their rule file lands.
3. **`.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`** — extended with the `disposition:` field spec + invocation of `finding-router.sh` after each gate's report is produced.
4. **Adversarial review prompt** — rule #11 added alongside rule #10 (dismissalLog) in `kit/scripts/adversarial-review.sh` for routing-plausibility judgment.
5. **Integration tests** — new `kit/tests/finding-router.bats` + per-rule fixtures under `kit/tests/fixtures/finding-router/` exercising each gate's routing.
6. **Docs** — `kit/docs/guide/workflow.md` Phase 3 pre-ship paragraph extended; `kit/docs/guide/hooks.md` § Dismissal Log subsection upgraded to § Finding Router; `CLAUDE.md` Known Footguns entry updated for the new dismissal-log contract.

**Ship size estimate**: ~250 lines for the router core + ~60 lines per wired gate + ~80 lines per bats test file. Landing the first two gates (`/qa` + `/design-review`) is roughly ~500 LOC. Subsequent gates are smaller as patterns emerge.

**Cost breakdown (2026-04-22 estimate)**

- **Phase 4a — router scaffold + first two gates (`/qa` + `/design-review`)**: ~500 LOC across ~5 files. Realistically 2 PRs (scaffolding PR: router core + adversarial-review extension + bats tests; then gate-wiring PR). Several focused sessions, not a single sitting.
- **Phase 4b — remaining 5 gates (`/ak-test-review`, `/review`, `/cso`, `/benchmark`, `/simplify`)**: ~60–100 LOC per gate for the rule file + tests. ~400 LOC total. Can be incremental over weeks as patterns emerge.
- **Full program**: ~900 LOC, 3–5 PRs, spread over multiple working days.
- **Doubled adversarial-review load**: every non-`None` dismissal goes through TWO LLM calls (rationale-quality + disposition-plausibility). Cost per pipeline run doubles for dismissal review specifically; the short-circuit on `None` bodies (Phase 3's scoped parse) keeps default runs at zero cost.

**Risk breakdown (2026-04-22 estimate)**

Medium-to-high overall. Four distinct risk classes:

1. **Automated `fix-now` is a real risk.** The pipeline decides "this is a bug, fix it now" and commits inline. If the routing is wrong (finding is a false positive) or the fix is wrong, bad code lands without human review. The existing `/ak-implement` stuck protocol + tests-must-pass gate help but don't eliminate this — layering "pipeline decides to fix" on top of "pipeline tries to fix" is a new compound failure mode. Mitigation: require `fix-now` to route through `/ak-implement`'s atomic commit pattern; never allow `fix-now` to skip test verification.

2. **Automated `spec-amendment` is worse.** The pipeline decides "the spec was ambiguous, let me amend it" and edits `spec.md` mid-run. That invalidates earlier agent decisions made against the old spec, may contradict things the user already approved at Phase 0 of /ak-build. Safe design: `spec-amendment` PAUSES and asks the user rather than auto-amending. Which reduces the automation value — you've added ceremony without speed. Probably right to require human confirmation on this disposition specifically.

3. **Opacity vs. transparency.** Today the human reads `review.md` and sees findings + rationales. With Phase 4, many findings auto-route and the human sees "pipeline did X with Y finding." Harder to audit retrospectively ("why did it choose TODO over fix-before-ship?"). The project's strength has been human-in-the-loop visibility; heavy automation here works against that. Mitigation: every routing decision writes an audit-trail entry with the chosen disposition + its rationale, not just the outcome.

4. **Secondary risks**:
   - **Per-gate rule drift** — six+ mapping functions (one per wired gate) that can subtly differ over time without shared conventions. Mitigation: a shared `kit/scripts/finding-router-rules/_common.sh` for severity-agnostic logic; per-gate files only hold gate-specific mappings.
   - **Regression surface** — if Phase 4 code has bugs, it can block pipelines Phase 3 handles fine. Mitigation: feature-flag per-gate wiring so each gate's router can be disabled independently; phase-in matches the incremental landing order.
   - **Adversarial-reviewer false-rejection rate** — the disposition plausibility judgment adds a new rejection surface. If the reviewer is too strict, pipelines grind on edge cases. Mitigation: the same `DEVSHOP_SKIP_ADVERSARIAL=1` escape hatch Phase 3 already has.

**Trigger — when to build this**

After v1.16 has been used in anger for a month or two on a real project. The signal to land: a Phase 3 review.md surfaces dismissals with weak rationales that an adversarial reviewer can't cleanly accept or reject because the finding would clearly be `fix-now` / `TODO` / `spec-amendment` if only we had that vocabulary. That's when the current `rationale:`-only vocabulary is hitting its ceiling; Phase 4 unblocks further automation.

**What NOT to do while deferred**

- Don't add ad-hoc `disposition`-like fields to Phase 3's `rationale:` section — that fragments the format before Phase 4 can unify it.
- Don't wire routing for one gate without the reusable `finding-router.sh` substrate — per-gate one-offs are how the devshop would end up with 7 subtly different routing implementations.
- Don't treat deferring this as technical debt. The three landed phases cover the concrete failure modes that motivated the work; Phase 4 is an efficiency / hygiene upgrade for the triage step, not a correctness fix. Current Phase-3 users get adversarial review of rationales; Phase 4 is how routing becomes mechanical after those rationales pile up.

### Git hook symlink recovery (post-checkout / post-merge)

Add husky `post-checkout` and `post-merge` hooks that call
`create-devshop-symlinks.sh` to proactively recreate symlinks after git
operations that can lose them. Currently symlinks are recreated reactively
(at session start and before commits). Proactive recovery would mean
symlinks are restored immediately after `git checkout`, `git merge`, and
`git pull` — no waiting for the next session or commit.

Trigger: after the symlink fragility TODO is resolved (settings.json copy
vs symlink decision), reassess whether proactive recovery is still needed.

### Native/mobile devshop support

Extend the devshop to support React Native (Expo) apps alongside web. Adds `apps/mobile/`,
EAS CLI, Maestro E2E, mobile Sentry/PostHog, App Store/Play Store deployment.
Full build blueprint: `kit/notes/bootstrap/v+-native.md`.

### Fakeowner + Bash bypass hardening

Two known security gaps in the file protection model:

1. **Fakeowner**: Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic — Layer 2 (root ownership) doesn't enforce on these mounts.
2. **Bash bypass**: Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either.

**Current protection (v0):**

1. Deny rules in `settings.json` block Edit/Write tools
2. `init-devshop.sh` chowns files to root on container start (cosmetic on fakeowner)

**Known gap:** Bash commands can modify any file on the fakeowner mount regardless of
displayed ownership. Deny rules only cover Edit/Write tools, not Bash.

**Attempted fix: DCG custom block rules** — added `[overrides] block` patterns in
`.dcg.toml` matching protected filenames. Problem: DCG pattern-matches against the full
command string, so `git add .claude/settings.json` and `git commit` mentioning protected
files in messages trigger false positives. DCG's `allow` override precedence vs pack rules
(e.g., `core.git` blocking `git reset --hard`) is undocumented — blanket git allowlisting
might weaken existing protections. Reverted.

**Option A: DCG with surgical patterns** — instead of filename-only patterns, use
write-verb + filename combos (`> .*settings.json`, `tee .*settings.json`, `python.*settings.json`).
Avoids git false positives but requires enumerating all write verbs — misses novel ones
(`dd`, `perl`, `ruby`, `node -e`, etc.). Weaker net than broad filename matching.

**Option B: Symlink to ext4 volume** — move protected files to `/home/node/.claude/`
(real ext4 Docker named volume where permissions are kernel-enforced), symlink from
workspace. `init-devshop.sh` copies latest from git → volume target, then
`chown root:root` — kernel enforces it. Real protection, not pattern-matching.
Complexity: lifecycle management (git updates must flow through copy step), container
rebuild vs volume persistence timing, Claude Code must follow symlinks for settings
loading (likely works, untested).

**Option C: Custom PreToolUse hook** — a bash script (not DCG) that parses the command
from stdin JSON and checks if it would write to protected paths. More flexible than DCG
patterns, can do path resolution, but same fundamental limitation: pattern matching is
bypassable with sufficient creativity.

**Trigger:** When a Bash bypass is observed in practice (not just theoretical).

### Symlink replacement protection

The `.devshopkit` symlink (and other injected symlinks like `.claude/commands`,
`.claude/skills/*`) are node-owned and have no deny rules. A single `mv` command
(which is in the Bash allow list) could replace `.devshopkit` with a symlink to an
attacker-controlled directory. All guard scripts (`bash kit/scripts/...`)
and PreToolUse hooks would then execute from the new target.

**Current mitigations:**

1. `create-devshop-symlinks.sh` recovers symlinks at pre-commit and session start
2. Detection window is one tool call (the next PreToolUse hook fires from the wrong location)
3. `ln` is not in the Bash allow list — only `mv` could replace a symlink without prompt

**Why not fixed now:** The attack requires `mv` (allowed), has a one-tool-call
detection window, and self-heals at the next checkpoint. Practical risk is low.

**Options when hardening:**

- PreToolUse hook that validates `.devshopkit` symlink target before executing any
  command that references `kit/` paths
- Integrity check in DCG that verifies symlink targets haven't changed
- Root-owned wrapper script at a fixed path (not a symlink) that hooks call
  instead of relying on the `.devshopkit` symlink path

**Trigger:** When a symlink replacement is observed in practice, or when
hardening the Bash bypass gap (above) — both share the same attack surface.

### CI slow job expansion

The `slow` job in `.github/workflows/ci.yml` is commented out at scaffold time. It gets
built incrementally, tied to feature milestones. Each expansion lands in the same PR as the
code it tests — no gap between "tests exist" and "CI runs them."

**Trigger 1: First DB-backed feature** (e.g., auth, data queries):

Uncomment the `slow:` job in `.github/workflows/ci.yml`. The template stub already ships the canonical shape:

- `supabase/setup-cli` step + `supabase start` (GitHub Actions has native Docker — no DinD)
- The lalista-PR-26 `supabase_edge_runtime` health-check retry loop (preserve it; don't strip)
- `scripts/ci-type-drift.sh` — regenerates `packages/core/src/supabase.types.ts` against the local stack and fails on drift (helper ships in `template/scripts/`; copied verbatim into every project)
- `scripts/ci-rollback-explain.sh` — for each migration with `-- ROLLBACK:`, applies the rollback then re-applies forward (round-trip), catching syntax errors before they bite during a real outage (also ships in `template/scripts/`)

Per-project wiring (the only operator-facing work):

- Add `SUPABASE_SERVICE_ROLE_KEY` to CI Variables — value is the local-stack default JWT (published; same value across every Supabase install). Per the security-posture cleanup, prod service-role NEVER goes here.
- Add `ANTHROPIC_API_KEY_QA` to CI Secrets if edge functions call Claude — re-exported as `ANTHROPIC_API_KEY` inside the test step's env block. `ANTHROPIC_API_KEY_PROD` is unrelated to CI; it's pushed to Supabase by `deploy-functions.yml`.
- Update branch protection to require `slow` alongside `fast`.

Full lifecycle convention (when the threshold is crossed, structural enforcement, codified prior art): `kit/docs/guide/conventions.md § Slow-Job Lifecycle`. The `/ak-pre-ship` gate `slow-job-lifecycle` (fires when `*.integration.test.ts` or `apps/web/e2e/*.spec.ts` exists) catches misconfigurations: stub still commented, wrong `if:` predicate, retry pattern stripped, branch protection missing, slow-job runs zero tests.

**Trigger 2: First E2E-testable flow** (e.g., sign-in → core action → verify):

Add to the `slow` job:

- Install browsers: `npx playwright install --with-deps chromium`
- Build and start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging
- Cache Playwright browsers using lockfile hash

**Additional secrets for slow job**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin access) and `ANTHROPIC_API_KEY_QA` (if edge function integration tests call Anthropic — re-exported as `ANTHROPIC_API_KEY` inside the integration-test step's env block; the canonical name stays inside the function process). Add to GitHub Secrets when wiring up the slow job. The corresponding prod-traffic key (`ANTHROPIC_API_KEY_PROD`) is unrelated to slow-job — it's pushed to Supabase by `deploy-functions.yml` for real-user runtime.

**After both expansions**: update branch protection to require `slow` as a required status check alongside `fast`.

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs, Playwright browsers. Cache keys use lockfile hash.

**Expected CI minutes**: ~260 min/month for 10 PRs (20 fast jobs × 4 min + 10 slow jobs × 15 min). GitHub Actions free tier: 2000 min/month.

### Backend alternatives and self-hosting evaluation

Evaluate alternatives to Supabase hosted for cost-conscious multi-project use:

- **Neon + Auth.js + Vercel functions**: free database branching, $0/mo, medium assembly
- **Self-hosted Supabase via Coolify + Hetzner**: ~€15/mo for multiple projects, higher ops burden
- **Backend-agnostic init**: `/ak-init` asks which backend and wires accordingly

Trigger: when monthly Supabase bills exceed ~€15/mo across projects, or when
staging/branching becomes a real bottleneck.

Full research: `kit/notes/backend-alternatives-research.md`

### `/rollback` skill

Dedicated skill that: reverts Vercel deployment (`vercel rollback`), warns about
migration state, walks through manual data recovery. Build when you've had your
first production incident and know what the workflow should actually be.

### Visual regression testing

Playwright screenshot comparison for key screens. Store baseline screenshots in
`tests/screenshots/`. CI step compares current vs baseline, fails if diff exceeds
threshold. Catches unintended visual changes that unit tests miss.

### Test-impact analysis (TIA) — runtime-instrumented test selection

Real TIA platforms (Gradle Enterprise, Datadog Test Optimization, NCrunch, Bazel's `bazel test --runs_per_test`-style pruning) instrument test runs to record which production code each test actually exercises, store the mapping in a coverage database, then on a diff re-run only tests whose recorded coverage intersects the changed lines. The precise version of `/ak-pre-ship`'s `changed-tests-local (ak)` gate's heuristic layers (smoke set + path-pattern map + import-graph match) — a heuristic catches what filename + reference-graph traversal can find; TIA catches what the code actually executed.

The heuristics are an approximation that doesn't require infra. TIA requires:

- A runtime instrumentation hook (Istanbul / V8 coverage / Playwright's coverage API) wired into every test run.
- A coverage database keyed on test ID × file:line (per-commit or per-test-suite).
- A diff-resolver that maps changed lines back to test IDs, with cache invalidation when test files themselves change.
- A "first-run-after-test-change" path that runs the changed test fresh (no recorded coverage yet).

**When to revisit.** Move to TIA only if the heuristic layers' false-negative rate becomes painful — e.g., a project ships a behavior bug that would have been caught by a spec the heuristics missed but TIA would have surfaced. Until that happens, the heuristics are the right cost/benefit point: zero infra, false positives only cost wallclock, false negatives are caught by CI.

**Cost/risk.** Multi-week build (instrumentation + DB + resolver + cache invalidation + project-template wiring + BATS coverage). Risk: instrumentation overhead can be 10–30% per test run depending on the engine; coverage-DB drift if test files refactor without invalidation. Mitigation — TIA platforms run in-process; cost is amortized across the savings on subsequent runs.

Source: queued by abra-kadabra PR #27 (was an "out of scope" bullet on the cheap-test-gates source v1 entry that PR #27 deletes; promoted to v+ here per operator direction — no current need, theoretical upper bound on what cheap-test-gates can become).

### `/ak-migrate-project` skill

Skeleton exists (`.claude/skills/devshop/migrate-project/SKILL.md`). Two tiers:

- **Lightweight (same stack)**: existing Node/Next.js project, just needs devshop
  tooling. Merge configs (`.prettierrc`, `eslint.config.mjs`, `tsconfig.base.json`,
  etc.) instead of replacing, create/adapt `.devcontainer/`, skip N/A steps
  (no Supabase, no PostHog, etc.), don't delete existing `apps/`/`packages/`.
- **Full (different stack)**: migration from another framework (e.g., Swift → React,
  Django → Next.js). Archive old code for reference, port design system, set up
  backend integration, rebuild screens, full test pass.

`/ak-init` assumes a fresh template clone. `/ak-migrate` handles the cases where
that assumption doesn't hold. Reference: Phase 1 execution in
`kit/notes/bootstrap/v0-web.md` as the first data point for parametrization.

Trigger: when a second project needs to adopt the devshop.

### Parallel implementation loops via worktrees

Two `/implement` sessions running simultaneously on different features using
git worktrees (separate working directories, each on its own branch).

**What it would achieve**: True parallel feature development. Two Claude Code
sessions, each with its own worktree, spec, and task list. Merge when both
are done.

**What it would require**: Worktree management tooling, resource budget (two
sessions + potentially two local Supabase instances), merge conflict strategy
for shared files (tokens.ts, shared components), and a way to coordinate
when both features touch the same package.

**When to build**: When single-loop development feels like a bottleneck — likely
when the app has 10+ screens and features can be cleanly isolated.

### Auto-trigger `/go-live` on PR approval

Currently: user approves PR on GitHub, comes back to terminal, says `/go-live`.
Goal: approving the PR on GitHub automatically triggers merge + deploy + canary +
reflection — no manual second step.

Options to explore: GitHub Actions on `pull_request_review` (approved) that calls
Claude Code remotely, or GitHub auto-merge + a webhook/scheduled agent that detects
newly merged PRs and runs the post-merge pipeline. Lightest option may be GitHub
auto-merge (PR merges when CI passes + approved) combined with a deploy workflow
that runs canary checks — but loses Claude's structured reflection step.

### Devshop testing

Test infrastructure for the devshop itself — scripts, hooks, and sync tooling.
Currently the devshop has no automated tests; correctness relies on manual
verification during use.

#### Hook tests (commit guard)

Automated tests for `commit-guard.sh` and other commit hooks. Set up
temp git repos, stage specific file combinations, and assert correct blocking
behavior. Key invariant: **no auto-pass** — checks must never silently pass
because the "right" files happen to be co-staged. Every blocking check must
require an explicit reason, regardless of what else is in the commit.

Test cases: mixed commit detection (project repo only), docs drift with/without
co-staged docs, doc consistency with 1/2/3 docs staged, bypass flag parsing
from stdin JSON, exit code 2 on failure, repo detection.

#### Sync script tests

Tests for `sync-from-devshop.sh` and `sync-to-devshop.sh`. Create two temp
repos, run sync in both directions, verify correct files copied and exclusions
honored.

#### init-devshop.sh tests

Verify symlinks created, security lockdown applied, BUILD-LOG.md created when
missing, skill symlinks resolve.

### Structured logging for edge functions

Sentry catches crashes. PostHog tracks user actions. Gap: application-level
operational logging. When a user reports "my item didn't appear," you need edge
function logs, query timing, auth flow steps. Supabase has logging but it's not
structured or correlated with user-facing issues.

Consider structured console.log in edge functions with a standard format
(timestamp, request ID, user ID, action, duration). Revisit after first
production debugging session reveals what's actually needed.

### ~~Repo layout clarification~~ — RESOLVED

Resolved: created `template/` directory at devshop root containing the project
skeleton. Root simplified to devshop-only needs (no turbo, no pnpm-workspace).
`init-devshop.sh` moved to `kit/scripts/`. `/ak-init` replaced by
`/ak-new-project` (two-phase: create repo + setup) and `/ak-migrate-project`
(skeleton). Init checklist moved from GUIDE.md to per-project `INIT-TRACKER.md`.

### Standalone devcontainer for abra-kadabra

Open the abra-kadabra repo directly in a devcontainer for devshop-only work — no
project repo required. Currently the devcontainer assumes a project repo at
`/workspace`; opening abra-kadabra alone leaves `/workspace` empty and
`init-devshop.sh` fails.

Add a second devcontainer profile (e.g., `.devcontainer/devshop-only/`) that
mounts abra-kadabra as the workspace, skips project injection, and provides a
working Claude Code environment for editing devshop scripts, skills, docs, and
GUIDE.md without needing a sibling project repo.

Trigger: when devshop-only work sessions become frequent enough to justify the
setup.

Related: the devshop's root `CLAUDE.md` contains conventions that span both
devshop and project work (e.g., metrics, responsive, edge function rules). In
devshop-only sessions those project-oriented sections are harmless noise, but
over time consider splitting into universal devshop conventions vs.
project-template conventions — or just accepting the noise as low-cost.

### CODEOWNERS + branch protection

Add `CODEOWNERS` to both repos requiring review approval for changes to
`.devshopkit/`, `.claude/`, `.devcontainer/`, and hook files. Pair with GitHub
branch protection on `main` (require PR reviews, block direct pushes).

Currently all guards are local (hooks, file ownership, deny lists). A force
push to main bypasses everything. CODEOWNERS + branch protection adds
server-side enforcement that survives local bypass.

Not needed for solo development — the local guards handle the actual threat
model (Claude bypassing checks). Becomes relevant when a second contributor
joins or when the devshop is used across multiple projects with different
maintainers.

Trigger: when a second human contributor needs commit access.

### DNS wildcard firewall rules

Current firewall resolves each domain to IPs via `dig` + `ipset`. Every subdomain
needs its own entry (e.g., `sentry.io` and `o123456.ingest.sentry.io` resolve to
different IPs). This works but means more entries to maintain per project.

Alternative: use a DNS-aware proxy (e.g., `squid` or `dnsmasq` with filtering) that
supports wildcards like `*.supabase.co`. Fewer entries, survives subdomain changes.
Trade-off: adds a proxy process and config — more moving parts than the current
plain `iptables` + `ipset` approach.

Trigger: when the firewall domain list grows unwieldy across multiple projects.

### Self-correcting workflow patterns

The 2026-04-18 hook architecture migration (`kit/notes/roadmap/hook-migration-plan.md`) moved
workflow nudges from `PostToolUse Bash` (audience-confused, fires in subagents) to
the husky pre-push layer (agent-agnostic, blocking with adversarial review). That
fix solves the audience problem and strengthens enforcement, but it preserves the
existing pattern: hooks DETECT a problem, AGENT/HUMAN must ACT on it.

The deeper architectural reframe — deferred to v+ — is **self-correcting workflow**:
hooks (or skills) take the action themselves, with the agent/human just confirming
substantive decisions. Examples:

- **Auto-update PR description**: pre-push hook detects staleness, regenerates
  description from commit log via `gh pr edit`, asks user to confirm only if the
  diff is substantive (renames, removals, scope changes). Trivial appends auto-apply.
- **Auto-stage leftover files**: post-commit detects untracked/unstaged files, asks
  "stage these as a follow-up commit?" with one-key confirmation. Cleaner than
  warning + agent-must-remember.
- **Auto-invoke `/ak-release-devshop`**: post-merge to abra-kadabra `main` with
  `feat:`/`fix:` commits → automatically suggest the release skill via skill chain.
- **Auto-stash on dirty session start**: SessionStart detects WIP from prior session,
  offers to stash it under a labeled stash so the new session starts clean. Reversible
  via `git stash pop`.

**Why deferred from the 2026-04-18 migration**: each pattern is its own design
decision (substantive-vs-trivial threshold, confirmation flow, reversal-on-error,
edge cases like concurrent edits). Bundling all of them was multi-PR work that would
have delayed PR 3 of the lalista migration. The current adversarial-review pattern
captures most of B's enforcement value (LLM judges the bypass reason) without the
auto-action complexity.

**Why this is worth doing eventually**: the persistent failure mode of "agent
ignores advisory" remains, even with strong adversarial gates. Auto-action removes
the agent-discipline dependency entirely. Particularly valuable for high-frequency
workflow concerns where reading and acting on each warning is a tax.

**Structural concerns to design through**:

1. **Confirmation UX for auto-actions in git hooks**: husky hooks run during git
   operations. Interactive confirmation requires tty/stdin handling that's clunky
   in some shell contexts. Self-correcting actions are more naturally implemented
   in skills (where confirmation flows are first-class) than in pure git hooks.
   May lead to a hybrid: husky detects, signals to next skill invocation to act.
2. **Reversal**: every auto-action needs a clear undo path (`git restore --staged`,
   `git stash pop`, `gh pr edit` to revert description). Design must surface the
   undo at the moment of action.
3. **Substantive-vs-trivial threshold**: "auto-apply trivial, confirm substantive"
   only works if "substantive" is reliably detectable. Likely needs adversarial
   LLM review as the discriminator (matches existing pattern).
4. **Failure modes**: what if `gh pr edit` fails mid-update? What if auto-staging
   stages files the user didn't want? Each auto-action needs failure-safe defaults.

**Trigger**: when the persistent "agent ignores advisory" failure mode is observed
in practice often enough that adversarial-gate enforcement isn't sufficient. Or when
specific auto-action candidates (PR description sync, post-merge release prompts)
become high-frequency enough to justify per-pattern design work.

**Migration path from current**: each candidate auto-action can be implemented
incrementally — no need to do them all at once. Likely first candidate: auto-update
PR description on push (extends the existing pre-push staleness check from "block
with reason" to "regenerate + confirm if substantive").

Related: `kit/notes/roadmap/hook-migration-plan.md` § "Architectural shift" for the
why-not-now rationale.
