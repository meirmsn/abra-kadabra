<!-- generated-by: /ak-build Phase 0 (skeleton — Phase 1 will expand) -->
<!-- feature: home-os-skill-polish-batch -->
<!-- date: 2026-05-20 -->

# Spec: home-os-skill-polish-batch

**Sources:**

- `kit/ROADMAP.md § Post-home-os onboarding learnings — skill / template / convention polish batch` — primary scope (sub-bundles A + B + E; D deferred)
- `kit/notes/projects/home-os.md § 2026-05-13 session — devshop generalizations to surface` — per-incident narrative for gen #19–#30
- `PLAN.md § Planned § home-os-skill-polish-batch` — tracker row (19 fixes header; A absorbs 5, B absorbs 2, E absorbs 11)
- `/devshop/CLAUDE.md` — destination for B1 (clean-tree-guard stash footgun)
- `/devshop/.claude/skills/ak-new-project/SKILL.md` — primary edit surface (A1–A5 + E1–E11; ~17 of 19 items)

Closes 18 small post-home-os papercuts surfaced when home-os (the second
project) was scaffolded from the devshop template via `/ak-new-project`.
All edits are pre-3rd-project; sub-bundle D (Supabase port registry)
stays deferred until a third project bootstrap forces the collision.

---

## Product update

Both blurbs are the single source-of-truth for downstream surfaces (squash
commit message via `/ak-merge-devshop`, `kit/docs/CHANGELOG.md` line on the
next devshop release).

### Headline (user-facing)

Bootstrapping a new project now skips 18 small papercuts found while
scaffolding the second project — the Vercel CLI examples no longer echo a
token, the Sentry default points at the right framework, and the gstack
helpers resolve on the first try.

### Detail (team-facing)

Closes the post-home-os polish batch — 5 SKILL fixes (A1–A5: vercel
`--token` echo via `export VERCEL_TOKEN`; `install-deps chromium` →
smoke-test-with-fallback; Vercel↔GitHub Login Connection + SSO Protection
sub-bullets at Step 3; gstack-config preamble pre-answer at Step 17;
`~/.claude/skills/gstack` symlink at Step 9), 2 convention tweaks
(B1: CLAUDE.md note that stash-then-commit trips the clean-tree guard;
B3: pre-push reviewer short-circuit PASS when the PR body already
enumerates every commit on the branch), and 11 first-session
generalizations (E1–E11: Sentry platform → Next.js; pre-fill local-stack
`SUPABASE_SERVICE_ROLE_KEY`; Sentry DSN direct-URL form; drop
`SUPABASE_DB_PASSWORD` from `.env` + security matrix update;
`vitest.config.ts` placeholder rewrite; Step 18 → Step 12.6 reorder;
sharp/unrs-resolver build-script reconciliation; partial-scaffold
recovery note; tracker-verification grep at Step 6; `[OPERATOR-ONLY]`
headers on Steps 6/7; firewall smoke-test sub-step). Sub-bundle D
(Supabase port registry) stays deferred to the third-project trigger.

---

## Decisions (resolved at spec time)

7 `/ak-spec`-time decisions resolved in Phase 0. Recorded below verbatim
so Phase 1's expansion preserves them and a crashed Phase 1 resumes
without re-asking.

### D1: Bundle structure — A + B + E as one branch / one squash

**Decision:** Single branch (`fix/home-os-skill-polish-batch`), all 18
fix items + 1 tracker-closure commit = 19 commits, landed as one squash
via `/ak-merge-devshop`. Sub-bundle D (Supabase port registry) stays
deferred to the third-project trigger.

**Rationale:** `PLAN.md § Bundling cheatsheet` already absorbed A + B + E
internally; splitting now would double the ceremony cost. ROADMAP's
earlier framing offered "sub-bundle A as one PR, B as 1–3 PRs, E bundled
into A" — superseded by PLAN.md's absorb-all decision after we counted
the ceremony cost. `/ak-merge-devshop` squashes regardless, so the
per-commit atomic-fix discipline survives in the squash body's
`## Squashed commits` section without inflating `git log` on main.

### D2: A5 implementation — symlink during Step 9, not gstack-side rewrite

**Decision:** Add a symlink step at `/ak-new-project § Step 9` that links
`~/.claude/skills/gstack` → `/workspace/.claude/skills/gstack` after the
clone, so SKILL.md preambles that hardcode `~/.claude/skills/gstack/bin/*`
resolve correctly.

**Rationale:** ROADMAP listed three candidates (symlink / change gstack's
default install dir / edit gstack SKILL.md preambles to resolve
`$_ROOT/.claude/skills/gstack/...` with `~/...` fallback). Only the
symlink path stays outside `.claude/skills/gstack/**` — which CLAUDE.md
designates as upstream-owned ("Never edit `.claude/skills/gstack/**`").
The other two candidates would either touch gstack source (gone on next
`/gstack-upgrade § Step 4` clobber) or require an upstream PR + wait
cycle. Verified at Phase 0.2.5: `~/.claude/skills/` does not exist in
the current container; `/devshop/.claude/skills/gstack/` does. The same
pattern is already in production for `~/.gstack/projects →
/workspace/.gstack/projects` (shipped 2026-05-20 in
`gstack-artifact-symlink-redirect`).

### D3: E6 implementation — reorder Step 18 → Step 12.6, not drop

**Decision:** Move the docs-fill step from Step 18 to a new Step 12.6
(after `apps/web` scaffold lands, before Sentry/PostHog at Step 13).
Renumber subsequent steps and unwind every cross-reference.

**Rationale:** ROADMAP explicitly preferred reorder over drop. Reorder
front-loads the docs-fill so the docs-coverage hook stops firing on
every Step 12+ apps/web-modifying commit (the home-os pattern). Drop
would re-route to "fill docs as features ship" (lalista's pattern),
which is the alternative but loses the design-review-fed front-loading
benefit home-os got. ~30 min vs ~15 min — extra cost is the renumber
sweep, but mechanical (`sed -i` over cross-refs + a final grep audit).

### D4: B3 implementation — short-circuit PASS before LLM call in pre-push.sh

**Decision:** Add a fast path-(a) check at the top of
`kit/hooks/pre-push.sh § Check 2: PR description staleness` that
compares the PR body's commit-SHA enumerations against
`origin/main..HEAD` SHAs. When every commit on the branch is named in
the PR body, short-circuit PASS without invoking
`adversarial-review.sh prDescStaleReason`. The reviewer prompt
stays unchanged (other check-types still use it; minimal blast radius).

**Rationale:** ROADMAP offered two candidates — (i) hook short-circuit
PASS, (ii) reviewer prompt edit to "score path-(a) FIRST". (i) wins
because the reviewer prompt edit changes behavior for every other
check-type's path-(a) scoring (higher blast radius), while the hook
short-circuit only affects the prDescStaleReason check-type. Also (i)
saves an LLM call per push when the PR body is current — net cost
saving on every clean re-push.

### D5: Commit granularity — one commit per fix item

**Decision:** 18 fix commits (one per A/B/E item) + 1 tracker-closure
commit = 19 commits on the branch. `/ak-merge-devshop` squashes to one
main-commit; the squash body's `## Squashed commits` section preserves
per-item visibility.

**Rationale:** ROADMAP "Sub-bundle A acceptance" + "Sub-bundle E
acceptance" both specified "one PR with N commits, one per item".
Atomic commits make any regression bisectable to a single line of skill
text. `/ak-merge-devshop`'s squash-with-bullet-led-body convention
preserves the per-task narrative without inflating `git log` on main.

### D6: E2 implementation — pre-fill in the skill's emitted `.env` body, not in a template file

**Decision:** Edit `/ak-new-project § Step 4`'s `.env` body (rendered
inline in the skill as a heredoc-shaped instruction) to pre-fill
`SUPABASE_SERVICE_ROLE_KEY=<published-local-stack-default-JWT>` with the
"NOT the prod admin key" inline comment. No new template file.

**Rationale:** Verified at Phase 0.2.5 that `template/.devcontainer/.env`
does NOT exist in the template (it's gitignored at runtime + emitted by
the skill). ROADMAP entry E2 framed the fix as "pre-fill into
template/.devcontainer/.env (or rename `.env.example` if that's the
template pattern — verify against current template shape)". Verification
showed no example file either; the skill's Step 4 emits the .env content
via prose. Fix is therefore a skill-text edit, not a template-file
addition. Same blast radius (every new scaffold) without introducing a
new tracked file.

### D7: New METRICS events — none

**Decision:** No new METRICS events. Pure devshop hygiene.

**Rationale:** Devshop has no METRICS.md (project-side artifact). All
fixes are skill text, convention text, or template-resource text edits.
No user-visible product feature is added or removed; no observability
surface needs new event definitions.

---

## In scope

- 5 SKILL text fixes — `/devshop/.claude/skills/ak-new-project/SKILL.md` Steps 3 / 9 / 13 / 14 / 17 (A1–A5).
- 2 convention/hook tweaks — `/devshop/CLAUDE.md` § Two repos, two commit flows (B1); `/devshop/kit/hooks/pre-push.sh` Check 2 short-circuit + bats coverage (B3).
- 11 first-session generalizations (E1–E11) — mostly more SKILL.md text edits at Steps 3 / 4 / 6 / 7 / 10 / 12 / 18 (renumber → 12.5), plus two template touches (`template/packages/core/vitest.config.ts` comment rewrite, `template/package.json` pnpm build-script policy).
- 1 tracker closure — delete `home-os-skill-polish-batch` row from `PLAN.md § Planned` + cheatsheet mention; delete `Post-home-os onboarding learnings` section from `kit/ROADMAP.md`.

## Out of scope

- **Sub-bundle D** (`devshop-side Supabase port registry`) — deferred to the 3rd-project trigger. ROADMAP keeps the design v0; D's section in `kit/ROADMAP.md` is NOT deleted by this branch.
- **Sub-bundle B2 / B4** — already shipped (proxy.ts rename 2026-05-19; `allowedDevOrigins` template default 2026-05-19). The ROADMAP entries for B2 + B4 carry "shipped" inline notes and stay in `kit/ROADMAP.md` until next housekeeping sweep.
- **`gstack-symptom-wrappers` row** (Sub-A populate-playwright-cache + Sub-B capture-screenshot wrapper) — separate row in `PLAN.md`; out of scope here.
- **Renaming `.claude/skills/ak-new-project/SKILL.md` sections** beyond what each fix requires. No structural rewrite, no section renumber except where E6 demands it.

## Files to create / modify

Per-item; full per-fix surface from ROADMAP § A / § B / § E. Path-prefix all to `/devshop/` (the devshop repo root inside the worktree).

| Task | File | Touch shape |
|------|------|-------------|
| A1 | `.claude/skills/ak-new-project/SKILL.md` § Step 13 | Replace `--token $VERCEL_TOKEN` on per-line vercel CLI invocations with one `export VERCEL_TOKEN=…` at the top of the Step 13 example loop. |
| A2 | `.claude/skills/ak-new-project/SKILL.md` § Step 14 | Change "run `sudo npx playwright install-deps chromium`" to "verify `chromium.launch()` succeeds via a one-liner smoke test; if it fails, run `install-deps` as fallback". |
| A3 | `.claude/skills/ak-new-project/SKILL.md` § Step 3 | Add two sub-bullets (Vercel Login Connection + SSO Protection check). |
| A4 | `.claude/skills/ak-new-project/SKILL.md` § Step 17 | Prepend an idempotent `gstack-config set` batch (touch marker files + set 5 configs) before invoking `/setup-deploy`. |
| A5 | `.claude/skills/ak-new-project/SKILL.md` § Step 9 | Add `mkdir -p ~/.claude/skills && ln -sfn $PWD/.claude/skills/gstack ~/.claude/skills/gstack` after the gstack clone. |
| B1 | `CLAUDE.md` § Two repos, two commit flows | One sub-bullet documenting that stash-then-commit trips the clean-tree guard; cite the `devshop.dirtyTreeReason` opt-out. |
| B3 | `kit/hooks/pre-push.sh` (Check 2) + `kit/tests/<new>.bats` | Add fast path-(a) check: if every commit SHA in `origin/main..HEAD` appears in the PR body, short-circuit PASS before invoking `adversarial-review.sh prDescStaleReason`. Bats coverage: 1 fresh-PR-body case + 1 stale case. |
| E1 | `.claude/skills/ak-new-project/SKILL.md` § Step 3 | `platform: React` → `platform: Next.js` (Sentry SDK choice). |
| E2 | `.claude/skills/ak-new-project/SKILL.md` § Step 4 (`.env` body) | Pre-fill `SUPABASE_SERVICE_ROLE_KEY=<published-local-stack-JWT>` with "NOT the prod admin key" inline comment. |
| E3 | `.claude/skills/ak-new-project/SKILL.md` § Step 4 (Sentry DSN sub-bullet) | Replace "Project Settings → Client Keys" navigation prose with direct URL `https://sentry.io/settings/{org-slug}/projects/{project-slug}/keys/`. |
| E4 | `.claude/skills/ak-new-project/SKILL.md` § Step 4 (`.env` body + § Security Posture surface matrix) | Remove `SUPABASE_DB_PASSWORD=` from emitted `.env`; update matrix to ❌ NEVER for `.devcontainer/.env` column with "paste from PW manager for ad-hoc" note. |
| E5 | `template/packages/core/vitest.config.ts` | Rewrite comment header from `// @PROJECT_NAME_PLACEHOLDER/core` to `// Vitest config for packages/core` (placeholder-free). |
| E6 | `.claude/skills/ak-new-project/SKILL.md` | Renumber Step 18 → Step 12.6; renumber Steps 13–17 → 13–17 (no shift; 12.5 is a "half-step" so following steps keep their numbers — verify cross-refs unaffected). Unwind cross-refs via `grep -n "Step 18"` audit. |
| E7 | `template/package.json` + `.claude/skills/ak-new-project/SKILL.md` § Step 12 | Move `sharp` + `unrs-resolver` from `pnpm.onlyBuiltDependencies` → `pnpm.ignoredBuiltDependencies`; add Step 12 sub-step "rm `apps/web/pnpm-workspace.yaml` after `pnpm create next-app` — root owns build-script policy". |
| E8 | `.claude/skills/ak-new-project/SKILL.md` § Step 12 | Sub-step note: interrupted-`pnpm create next-app` recovery rule. |
| E9 | `.claude/skills/ak-new-project/SKILL.md` § Step 6 | Append a verification grep before [x] is marked: `grep -E "supabase\.co\|ingest\.sentry\|posthog\.com" .devcontainer/firewall-extra-domains`. |
| E10 | `.claude/skills/ak-new-project/SKILL.md` § Step 6 + § Step 7 headers | Prefix `**[OPERATOR-ONLY]**`; reframe body to "STOP and ask the operator to apply the following diff" rather than implying Claude can patch. |
| E11 | `.claude/skills/ak-new-project/SKILL.md` § Step 6 | Append a smoke-test sub-step that curls 5 project-specific external endpoints to surface firewall gaps before Steps 14/15/17b. |
| Tracker closure | `PLAN.md` + `kit/ROADMAP.md` + grep audit | Delete row from `## Planned` + cheatsheet bullet + the full `### Post-home-os onboarding learnings` section in ROADMAP; rewrite any "Without this …" / "verify X before assuming blocked" cross-refs to imperative present tense; grep `home-os-skill-polish-batch` across `/devshop/kit/docs/` + `/devshop/CLAUDE.md` and unwind. |

## Tests

The fix surface is mostly skill prose + template static text. Tests cluster around B3 + the structural-invariant grep'ables.

- **B3 short-circuit** — new bats spec under `kit/tests/` (proposed name: `pre-push-prdesc-shortcircuit.bats`):
  - Case 1: PR body enumerates every commit SHA → short-circuit PASS, no adversarial-review call.
  - Case 2: PR body missing one commit SHA → fall through to the adversarial reviewer (unchanged behavior).
  - Case 3: empty PR body → fall through (covers the worst case explicitly).
- **A5 symlink shape** — extend an existing bats test that asserts `/ak-new-project § Step 9` mentions the symlink invariant (grep-based; full integration test deferred to a fresh scaffold).
- **E5 placeholder rewrite** — `kit/tests/structural-invariants.bats` (or equivalent) gets an assertion that `grep -r PROJECT_NAME_PLACEHOLDER template/packages/core/` returns zero hits after the rewrite.
- **E10 `[OPERATOR-ONLY]` markers** — grep assertion that Step 6 + Step 7 headers carry the marker.

Existing test suites (devshop bats, project-side vitest/playwright) are NOT exercised by this branch — no code path that runs in those suites is touched.

## Dependencies

- **Predecessor `home-os-onboarding-template-patches`**: shipped 2026-05-19 (sed sentinel + WebSocket stub + `@/` alias + vercel preview env-add). Unblocked this row per `kit/ROADMAP.md § Ordering` paragraph.
- **No project-side dependency** — every file touched lives in `/devshop`.
- **No upstream gstack edit** — A5 + A4 both intercept symptoms via devshop-side wrappers (symlink at Step 9, preamble at Step 17), per `CLAUDE.md § gstack`.

## Task order

Numbered to match the tracker (Phase 2 / Task N). Inside each: read current file → edit → spot-verify → commit. Independent — order is chosen for cognitive coherence (group same-file edits), not technical dependency.

1. **A1** — Step 13 `export VERCEL_TOKEN` (security; clean diff first to anchor the SKILL.md edits).
2. **A2** — Step 14 chromium smoke-test fallback.
3. **A3** — Step 3 Vercel/GitHub Login Connection + SSO sub-bullets.
4. **E1** — Step 3 Sentry platform → Next.js (same step as A3; bundle the same-region reads).
5. **E3** — Step 4 Sentry DSN direct-URL form (same step as E2/E4; bundle).
6. **E2** — Step 4 pre-fill local-stack JWT.
7. **E4** — Step 4 drop `SUPABASE_DB_PASSWORD` + § Security Posture surface matrix.
8. **A4** — Step 17 gstack-config preamble.
9. **A5** — Step 9 `~/.claude/skills/gstack` symlink.
10. **E6** — Step 18 → Step 12.6 renumber + cross-ref sweep.
11. **E7** — Step 12 build-script reconciliation + `template/package.json`.
12. **E8** — Step 12 partial-scaffold recovery note.
13. **E9** — Step 6 verification grep.
14. **E10** — Step 6 + Step 7 `[OPERATOR-ONLY]` markers.
15. **E11** — Step 6 firewall smoke-test sub-step.
16. **E5** — `template/packages/core/vitest.config.ts` comment rewrite (template-side; leave for after all SKILL.md edits land).
17. **B1** — `/devshop/CLAUDE.md` stash footgun bullet.
18. **B3** — `/devshop/kit/hooks/pre-push.sh` short-circuit + bats.
19. **Tracker closure** — delete `PLAN.md` row + ROADMAP section + cross-ref sweep.

## Gotchas

- **`Step 18 → 12.5` renumber is the only multi-file cross-ref sweep.** Old `Step 18` references in the same SKILL.md (preamble / step preview / footer summary) + any external skill that points at "see `/ak-new-project § Step 18`" need to flip to `Step 12.6`. Run `grep -rn "Step 18" /devshop/.claude/skills/ /devshop/kit/ /devshop/CLAUDE.md` after the edit and triage every hit.
- **Step 6 / Step 7 are `[OPERATOR-ONLY]`-prefixed by E10.** The smoke-test sub-step E11 adds is operator-runnable (curl from inside the container), so the `[OPERATOR-ONLY]` marker still fits — clarify in E11's text that the smoke test runs from the container, not from the host.
- **B3's path-(a) detection is exact-SHA-match.** Don't try to be clever about partial SHAs or commit-subject overlap — the adversarial reviewer already handles those judgment cases. The hook short-circuit fires only when every commit SHA in `origin/main..HEAD` literally appears as a string in the PR body.
- **A4's `gstack-config set` batch must be idempotent.** A re-run during a partial-scaffold recovery (E8 territory) must not error if the marker files already exist.
- **E2 pre-fill must match the published local-stack default JWT exactly** — value is stable since supabase-cli 1.x; copy the canonical string from `kit/scripts/preship/supabase-bootstrap.sh` (where it's already referenced) rather than hand-typing.
- **E4 + E7 both touch matrices/policies that affect security posture.** Both are skill-text edits, but the `/cso` gate at Phase 3 will re-read both surfaces; expect at least a no-op pass with the security matrix re-asserted.
- **Tracker closure must be the LAST commit on the branch.** Doing it earlier leaves a window where the tracker says "shipped" but the fixes are still uncommitted on the branch — the squash-merge ordering is what makes the closure honest.

## Acceptance / verification

- All 18 fix items implemented as separate commits + 1 tracker-closure commit = 19 commits on `fix/home-os-skill-polish-batch`.
- `/ak-pre-ship` gauntlet runs to green: docs-check / fast-job-local / changed-tests-local / Audit 1 / `/simplify` / `/review` / `/cso` / preflight-final / convention check all `pass` or `n/a (per scope)`. UI gates (`responsive-theme`, `/design-review`, `/qa`, `/benchmark`) and database gates (`rls-coverage`, `migration-rollback-roundtrip`, `slow-job-lifecycle`) emit `n/a` per scope — no UI, no DB, no slow job touched by this branch.
- B3 bats spec green: 3 cases pass.
- `grep -rn "Step 18" /devshop/.claude/skills/ /devshop/kit/ /devshop/CLAUDE.md` returns zero unwanted hits (all converted to `Step 12.6` or removed).
- `grep -rn "home-os-skill-polish-batch" /devshop/` after tracker-closure returns only the spec-dir / hook stamps / git-internal hits (no remaining `PLAN.md` / `kit/ROADMAP.md` / `kit/docs/` / `CLAUDE.md` hits).
- `/ak-merge-devshop` lands the squash on `main` with a bullet-led `## Squashed commits` section preserving per-item visibility.

## Rollout / rollback

- **Rollout**: lands via `/ak-merge-devshop` squash; immediate effect on next `/ak-new-project` invocation. No project-side migration; no operator action.
- **Rollback**: single `git revert <squash-SHA>` on `main` reverses every fix atomically. Since the squash carries the bullet-led body, the revert commit message can name the specific items being undone if a partial rollback is wanted — but a partial rollback would mean cherry-picking individual SHAs from the squash's `## Squashed commits` reflog, not editing the revert.
- **Per-item rollback** (rare): each fix is one commit on the feature branch. `git log --oneline` on the branch (before merge) shows 19 atomic SHAs; the squash body's `## Squashed commits` enumeration carries them as a recoverable trail.

