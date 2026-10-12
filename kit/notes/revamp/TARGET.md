# Target picture

What the devshop should be when the revamp is done, agreed **top-down** with the
owner in the plan review session (LOG #5): each level is agreed before the next one
down is discussed. Decisions in [DECISIONS.md](DECISIONS.md) are settled at the level
where they belong (mostly L3). Every milestone review checks progress against this
page and whether the page itself is still right
([PROCESS.md § 5](PROCESS.md#milestone-review-each-m-exit--the-whole-picture-check)).

| Level | Form                     | Status                                        |
| ----- | ------------------------ | --------------------------------------------- |
| L0    | One sentence (ish)       | **agreed** 2026-10-08                         |
| L1    | One paragraph            | **agreed** 2026-10-08                         |
| L2    | One line per pillar      | **agreed** 2026-10-09                         |
| L3    | A few bullets per pillar | in progress — all but Shape agreed 2026-10-12 |
| L4    | Milestones + tasks       | re-derived from L0–L3 (PLAN.md)               |

## L0 — where we're going

You say what you want — from a whole app to a one-line fix — and Claude helps you
sharpen it, specs it, and builds it, iterating against adversarial review until what's
built is verified against your intent (tested, documented, security-checked); then you
review the PR and its preview and steer until you approve. Claude works inside walls
it can't move — cloud by default, a scoped local Mac when the cloud can't do the job.

## L1 — the end state

You bring an idea of any size; Claude, using gstack, sharpens it with you into
product, design and a spec faithful to what you agreed. One agent builds it, following
the devshop's guidelines for the disciplines involved and the project's own; it tests
as it goes and iterates against adversarial review until the change is verified
against your intent, documented, and security-checked. You review a clear PR —
hierarchical description, visuals, preview — and steer until you approve; then it
deploys, is watched in production, and what was learned is recorded. Claude works
under its own limited identity inside walls it can't move; the cloud is the default
and a scoped local Mac covers what the cloud can't (native builds, simulators and
devices, or plain cloud limits). Outputs span web, mobile, desktop and backend.
Projects stay clean of the devshop, each pins its own devshop version, and upgrading
is one guided step.

## L2 — pillars

1. **Intent** — every change starts as a conversation in which Claude helps you shape the idea at the depth it deserves (gstack's thinking skills for apps and features), ending in a written spec you'd recognise as exactly what you meant; for bigger changes you glance at a one-screen summary and say "go" (agreed 2026-10-09).
2. **Build** — one agent builds the change, updating code, tests and docs together, following the devshop's guidelines for each discipline involved plus the project's own, and runs the new and affected tests where it works (cloud or Mac) as it goes (agreed 2026-10-09).
3. **Verify** — before you see a PR, an adversarial reviewer running independently of the builder checks the finished change against the product intent and the spec, then through the other lenses that apply (code, security, design, QA, docs, tests). Anything skipped, trimmed or weakened is a failure Claude must fix; after three unresolved rounds, or when something can't be done as agreed, Claude stops and asks you — so a PR arrives complete, or with your decisions already in it. PR CI stays plain: tests and deterministic checks only, no agentic jobs (agreed 2026-10-09).
   - Direction for L3: reviewer = a small script running locked-down `claude -p` with read-only tools inside the repo, invoked by the "done"/open-PR check itself so the builder never relays the verdict; no "skip with a reason" bypasses anywhere — today's 11 bypass-justification review types are deleted, the dismissed-findings and quality-lens reviews fold into this reviewer.
4. **Review** — you get a PR you can judge quickly: it always opens with a one-line summary of the change, then goes level by level down to engineering detail, with the user-facing announcement in its own section when there is one; screenshots/video and a preview link. You comment, Claude revises through the same verify loop, and your approval ships it — merge on green CI, deploy follows (agreed 2026-10-09).
   - Your approval is only a real gate if the agent has its own GitHub identity (D-13) — in place since 2026-10-11: machine user `meirmsn-agent` + `main` branch protection + CODEOWNERS (a GitHub App isn't usable from hosted cloud sessions; LOG #9–#10).
5. **Ship** — your approval ships it: web app and backend deploy to production automatically; native changes accumulate on `main` until you cut a version (Claude can propose one), which goes to the testing tracks and then the stores, each step your call. Claude watches production (canary, errors, the change's metrics), alerts you if something looks wrong, and records what shipped and what was learned in the project's log and plan. Rollback is your call, with a revert ready (agreed 2026-10-09).
   - For L3: native PRs need a preview substitute (simulator screenshots/video from the Mac attached to the PR).
6. **Safety** — Claude is treated as untrusted: it works under its own limited identity, holds no production secrets, can't change its own guardrails or merge around the checks, and reaches nothing beyond its session and the services/machines scoped to it. The rules that matter are enforced where Claude can't reach them (GitHub rules, CI, credentials, protected deploys); anything inside the session is helpful feedback, not the defence. Production access is read-only observability (errors, logs, analytics); read access to production data only when you explicitly grant it, time-limited and enforced outside Claude's reach (agreed 2026-10-09; settles D-04).
   - For L3: the grant mechanism (e.g. you mint a short-lived read-only DB role/credential that expires on its own); never a standing credential Claude can reuse.
7. **Environments** — work runs in cloud sessions by default, so you can drive it from a computer, phone or tablet. A dedicated Mac handles native builds, simulators and devices, and is the fallback when the cloud falls short; on it, Claude can touch only what's scoped to it. Local services (databases etc.) run in their own walled-off containers in either place (agreed 2026-10-09).
   - The Mac is dedicated to this work (no personal accounts/files) → Claude runs as a non-admin user with only the developer accounts it needs; a macOS VM only if that proves insufficient. Settles D-02 direction: cloud-first, local = the Mac (plus any existing devcontainer only until projects migrate).
8. **Reach** — the devshop can build web apps (responsive, installable as PWAs), marketing sites, backends (Cloudflare, Supabase, AWS), and native, cross-platform and desktop apps (Apple, Android, React Native, Electron). Each stack is added when a real project needs it; each stack has one home in the devshop for its setup, guidelines and lessons learned, which grows with every project that uses it and is loaded only when a task touches that stack (agreed 2026-10-09).
   - Context (not target): lalista is active (Next.js + Supabase + Vercel) with iOS next (voice input) → iOS is the second stack and the Mac is near-term. home-os is frozen — lessons source only. Today's Supabase lessons are scattered over ≥6 guide files; per-stack homes fix that.
9. **Shape** — the devshop is lean, not minimal: every part earns its place, each fact lives in one home, and reliability wins over line count. Projects carry almost none of it, so anyone can clone and contribute without it. Each project pins a devshop version, several versions can run side by side, and upgrading is one guided step including any migration. gstack is used as an upstream toolbox rather than rebuilt. The devshop grows only from lessons that proved themselves (agreed 2026-10-09; settles D-14 + D-12 direction).
   - Size: one hard budget (always-loaded context stays tight); everything else is a warning signal, not a target.
   - Built as a rewrite **in this repo** (revisited 2026-10-10): tag `v1-final`, the first v2 PR removes v1 from `main`, v1 stays readable from the tag; a lessons harvest (v1 guides, footguns, friction log, home-os) comes first; explicit go/no-go at the walking skeleton. Private for now; may go public once the history scan is clean and hits are rotated.

### Inputs parked for L3 (from the owner, 2026-10-08)

- ~~**Intent:**~~ folded into [L3 Intent](#intent) (2026-10-11).
- ~~**Build:**~~ folded into [L3 Build](#build) (2026-10-11).
- ~~**Verify:**~~ folded into [L3 Verify](#verify) (2026-10-11).
- ~~**Review:**~~ folded into [L3 Review](#review) (2026-10-11).
- ~~**Safety:**~~ folded into [L3 Safety](#safety) (2026-10-11).
- ~~**Reach:**~~ folded into [L3 Environments](#environments) and [L3 Reach](#reach) (2026-10-12).
- **Shape:** an outside collaborator can clone and contribute without the devshop; several projects on different devshop versions at once; moving to the latest version may involve a project migration.

## L3 — a few bullets per pillar

Agreed pillar by pillar with the owner (W10.2.1). **Across all pillars:** the chat is where
Claude raises things and the owner answers; it is never the record. Once the owner decides,
the decision is written where it belongs (spec, PR, decision log) and that is the source of
truth.

### Intent

_Agreed 2026-10-11 (LOG #19)._

1. **Kind of request, said up front** (Claude states which kind; the owner can correct it — L-02):
   - **No change** (analysis, status, questions, investigation) → Claude just does it. No spec, no "go".
   - **Bug fix** → Claude restates the problem and expected behaviour; the failing test is the spec. No "go". A "bug" whose fix involves a real choice (changes behaviour people rely on, or has several reasonable fixes) is treated as a change.
   - **Any other change** → upstream gstack `/spec` interview + the gstack planning reviews that fit, then the owner's "go". Small changes get a short spec, so the "go" is quick. An analysis that ends in "we should change X" becomes a change at that point.
   - `/office-hours` first whenever the why / who / problem isn't settled (a new product, or a big or fuzzy feature) — Claude proposes it; the owner can ask any time.
2. **One spec file per change** in the project's `specs/`, kept after merge (future agents use it as context): **intent** (owner's words), **decisions** (each with its reason, and the rejected alternative where it matters), **acceptance items** (numbered, pass/fail), **out of scope**. Upstream `/spec` drafts it (file-only, no agent spawn); Claude writes the approved result to the file — any GitHub issue is optional, never the source of truth.
   - **For UI changes** the spec also carries the core flow as 2–4 steps (L-20) and a state table for anything that shows or hides by state (L-73). Decisions that depend on how a tool or version behaves are proven with a quick experiment before the "go" (L-03).
3. **Decisions are captured when the owner makes them** (after any back and forth), not turn by turn.
4. **Acceptance items say what must be true;** how each is tested can't narrow it. Untestable or impossible → back to the owner, never reworded (L-19).
5. **Adversarial spec review** before the owner sees the summary, by the same independent reviewer as Verify: spec vs recorded intent and decisions; ambiguity; untestable items; missing edge cases and failure modes; scope added beyond the ask; literal code in the spec checked against the codebase (L-76). Claude fixes what it can; what needs the owner comes with the summary. Replaces `/spec`'s Codex quality gate. Not for bug fixes.
6. **The "go"** is given on a one-screen summary (intent, decisions, acceptance items, out of scope, rough size) and recorded in the spec.
7. **Spec changes after the "go":** Claude raises them, the owner decides, the spec is updated. The final review fails on any change to decisions or acceptance items that isn't recorded as the owner's.
8. **Too big?** Claude proposes splitting it into several changes, each with its own spec.

- _Dropped:_ v1's "stop and ask" category list (`CLAUDE.md` § Confidence Calibration at `v1-final`) — every change now needs a "go", and anything new mid-build is a spec change (bullet 7). Kept as the starting point if spec review ever gets tedious and specs become auto-approved except in listed cases ([lessons.md § Considered, not carried](lessons.md#considered-not-carried)).

### Build

_Agreed 2026-10-11 (LOG #19)._

1. **One central agent** writes the whole change from the approved spec, loading the knowledge it needs; helpers only do read-only side work (e.g. searching a large codebase), never write code. Parallel builders for a large change that splits cleanly stay a later option, not the default.
2. **Guidelines load only when relevant:** the devshop's guideline for each discipline the change touches (frontend, backend, data, UI/UX, security…), the stack's home, and the project's own rules. On conflict the project wins and Claude says so.
3. **Code, tests and docs change together.** The builder reviews the existing tests **and docs** around what it touches: edits those whose described behaviour changed, removes those for behaviour the spec removed, adds what's new — the end state of the suite and of the docs describes the new behaviour. A bug fix starts with the failing test; each acceptance item ends up referenced by its test.
   - **Finding what's related** uses things that can't drift, not a hand-kept index: a fixed layout (tests mirror the source tree; docs form a hierarchy under one docs map, `docs/README.md`); tool lookups (the test runner's related-tests mode such as `vitest related`, coverage of the changed lines, and a search for changed names and paths in the docs); and spec→test links via acceptance-item references. The docs map is the one hand-kept piece, held honest by a CI check (every doc linked from it, no broken links).
4. **New and affected tests plus the fast checks run in the session as it goes;** the full suite runs once, in CI (L-08).
5. **Root cause over band-aid;** a mitigation is labelled as one, with the root cause named beside it (L-04).
6. **Mechanical steps live in tested scripts,** never as shell snippets in prose for the model to retype (L-05).
7. **Fix loops are evidence-first and bounded:** real logs and artifacts before a second attempt, each retry fresh with a "tried" list, then ask the owner (L-06).
8. **Guidelines start from the harvest's engineering lessons:** validate outside responses at one wrapper (L-07), the server enforces every client limit (L-74), one rule one implementation (L-75), errors reported to monitoring before any fallback (L-66), event-stream wrappers pass errors and status through (L-65). A **cross-platform UI guideline** carries responsive layout and light/dark for web and native alike; each stack home says how (screen sizes and themes on web; size classes, Dynamic Type and dark mode on iOS).
9. **Instrumentation** is built as the spec and Ship's rules call for (product and observability metrics are decided under Ship).
10. **Commits are small and logical,** subjects describe the observable change.

- _v1 non-negotiables re-decided:_ responsive + light/dark → cross-platform UI guideline (bullet 8); TypeScript-source packages and "Prettier owns formatting" → stack-home conventions; 3-line `What/Why/Does NOT` file headers → dropped (no recorded bite); "metrics per feature" → Ship.

### Verify

_Agreed 2026-10-11 (LOG #19)._

1. **Spec review** (before the "go"): an adversarial check of the spec against the owner's intent and recorded decisions. Claude fixes what it is confident about; only the questions it can't settle confidently reach the owner, if any.
2. **Final review** before the owner sees the PR: the PR stays a draft until it passes (A-23).
3. **The reviewer** is a small script that starts a fresh, locked-down `claude -p` with none of the builder's context (L-18). It can read and run (tests, the app in a browser), never edit, commit or push. A hook starts it from the "done" / open-PR step, so the builder never chooses whether to run it or relays its verdict.
4. **Diff vs spec and intent first:** every acceptance item has evidence (a test, or a demonstrated step for UI flows); decisions are followed; nothing trimmed, nothing added beyond the ask (L-19, L-20). Then the lenses that apply: code, security, design and QA for UI, and two that get the same adversarial depth as the code:
   - **Tests** — the end state of the suite describes the new behaviour: every behaviour in the spec is covered; for each test, "would this fail if the code were wrong?" (a test that passes against broken code is a finding); tests assert behaviour, not text, and tests that run nothing fail (L-16, L-17); every **deleted or loosened** test must be justified by the spec (the behaviour it guarded was intentionally changed or removed), anything else is a finding, and they are listed under "what you should know" in the PR.
   - **Docs** — same depth as tests: would a future agent reading only the docs do the right thing? Every behaviour change reflected; nothing stale; renamed or removed things swept (L-23); literal code in docs checked against the codebase (L-76); every deleted doc justified by the spec. Future agents rely on docs, so a wrong doc is a bug.
5. **Three outcomes — pass, fail, could-not-run;** could-not-run never passes and goes to the owner (L-09). The verdict is structured and fails closed (L-12); pass/fail comes from machine signals, not the model reading logs (L-13).
6. **Findings at medium or above are fixed or go to the owner;** no "proceed but record" (L-21). Unsure whether medium or low → treated as medium and fixed. Low findings are listed in the PR, not blocking. Three rounds without resolving the same thing → Claude asks the owner.
7. **Same checks, two places.** In the session for speed: tests, deterministic checks and the reviewer run where Claude works (no waiting on GitHub). On GitHub, plain CI repeats the deterministic part as the required check: full suite, deterministic checks, and **every acceptance item referenced by a test or marked "verified by review"** (the reviewer checks those marks are honest) — run against the tree being merged (L-14, L-15). No LLM jobs in CI (D-06). The reviewer's verdict is recorded on the PR per lens, tied to the commit it reviewed (L-25).
8. **Every check is proven to fail** with a known-bad input (L-11); the reviewer's hit rate on planted spec violations is measured at the walking skeleton (A-12).

- _What this protects against:_ the in-session reviewer enforces the standards consistently against an agent that cuts corners. A deliberately misbehaving (rogue or prompt-injected) agent controls its own session and could disable it; the walls against that are GitHub's rules, plain CI and the owner's approval, with a missing or stale verdict on the PR as the tripwire. An air-gapped reviewer that would also be a wall is planned [after the revamp](PLAN.md#after-the-revamp).

### Review

_Agreed 2026-10-11 (LOG #19)._

1. **Title** describes the observable change (≤ 72 chars, no internal jargon), in today's style (L-31).
2. **Body, top-down so the owner can stop at any level:** (1) one-line summary; (2) **announcement** — a short blurb for non-technical readers, only when user-facing; (3) **what you should know** — behaviour change in plain words, decisions (spec link), anything changed after the "go" with the owner's recorded answer; (4) **evidence** — screenshots/video of the core flow steps and the spec's state-table states, reviewer verdict per lens, CI status, low findings; (5) **engineering details**, collapsed.
3. **Preview link:** the deploy platform's own PR comment, which updates itself on every push (Vercel's bot does this out of the box) — no hand-maintained link. Native changes get simulator screenshots/video instead (Ship).
4. **Visuals pinned** to the exact commit or uploaded, never linked to a moving branch (L-30).
5. **No unverified claims:** "CI green", "preview up" etc. are read from the real signal when written (L-28); before the PR goes ready, the reviewer checks title, body and screenshots match the final commit (L-29).
6. **Claude tells the owner in chat when a PR is ready** — link + one-line summary; the top of the PR stays short enough to judge on a phone.
7. **Steering:** the owner comments on the PR or in chat (chat input is recorded on the PR); Claude revises through the same verify loop and answers each comment; a comment that changes the spec follows Intent bullet 7.
8. **Approval ships by default:** once the owner approves and CI is green, Claude merges and deploy follows (Ship). Not when the approval message or the chat says to wait, or when Claude has a concrete reason to hold (then it says so and asks). Any push after approval needs approval again.

### Ship

_Agreed 2026-10-12 (LOG #19)._

1. **Merge only through the GitHub PR,** required checks green on the exact commit being merged, branch up to date with `main` (L-32); squash merge. By default Claude merges once the owner approves and checks pass; it waits for the owner to merge only when there's a reason ([Review](#review) bullet 8).
2. **Production health is checked before merging,** so a deploy can't hide an existing failure (L-33).
3. **Web and backend deploy automatically from `main`;** deploy secrets only in the `production` environment (Safety); database migrations run in the deploy pipeline, never from Claude's session.
   - **Migrations are reversible in practice:** backward-compatible by default (expand / contract — the previous app version keeps working), so a code rollback never needs a database rollback. Destructive steps (dropping a column or table, rewriting data) go in a later, separate change, with either a reverse migration tested in CI (apply → reverse → apply on the local database) or, when data can't be restored that way, a confirmed backup / restore point taken just before deploy using the platform's own feature (Supabase backups/PITR, Cloudflare D1 Time Travel); the PR says which. The revert PR includes the reverse migration whenever one exists.
4. **Manual steps listed in the PR** — anything the merge doesn't carry (dashboard settings, auth config, DNS, email templates) as a checklist for the owner, derived from the real deploy config (L-34).
5. **Claude watches after deploy:** an immediate canary of the live app (gstack `/canary`) + error monitoring + the change's metrics in the session, and **one follow-up check the next day** (scheduled routine) for errors and metrics. "Can't reach" from Claude's side is could-not-run, not "down" (L-33). The first production use of a critical flow (sign-in, invite, payment) gets a real-account smoke test, or Claude asks the owner to do it (L-67).
6. **If something looks wrong,** Claude alerts the owner in chat with the evidence and **both rollback paths prepared and checked:** a revert PR pushed with CI green on the reverted tree, and the platform's one-click rollback with the previous deployment confirmed available and healthy (its immutable per-deploy URL loads). The owner picks; rollback is the owner's call.
7. **Metrics in the context of what exists:** observability (errors, performance) is always on, set up per stack. Product metrics are added only when the existing ones don't cover the new functionality — the spec says which existing signals cover it, or names the new ones needed. Claude checks them after deploy.
8. **Native apps:** changes accumulate on `main`; Claude proposes a version when there's enough to ship; the owner cuts it, and each step (testing track, then stores) is the owner's call. Native PRs show simulator screenshots/video instead of a preview link.
9. **Recording:** each ship updates the project's log and plan (what shipped, what was learned) and asks "what generalises beyond this project?" — answers go into one counted devshop ledger (L-35), format decided under Shape.

### Environments

_Agreed 2026-10-12 (LOG #19)._

1. **Cloud sessions by default** — drive work from a computer, phone or tablet. **One cloud environment per project** (D-01 revisited): each holds only that project's tokens and network allowlist, and runs the same tiny shared setup script (read-only devshop token + one bootstrap line), so everything project-specific lives in the project's environment and the shared part stays trivial to change. The project's devshop version is `.devshop-version`; a stale local copy shows in the `DEVSHOP:` line.
2. **One task, one branch, cut from a freshly fetched `main`** (L-42); sessions never share a branch; parallel work = parallel sessions.
3. **Work survives only in GitHub:** the container is temporary, so Claude pushes the branch at every stopping point; a session resumes from the PR, the spec and the branch, never from a chat transcript.
4. **Setup runs without prompts, fails loudly, and can't block its own repair** (L-43).
5. **One pinned version of every tool everywhere** (Node, pnpm, CLIs, Playwright — same in CI, cloud and the Mac); CI actions pinned by SHA; upgrades on purpose with a smoke check (L-45).
6. **Local services in their own containers** (databases etc., via Docker in the cloud), never connected to production; Supabase start-up speed in a cloud session is still untested (A-11) — tested at the walking skeleton.
7. **The Mac** (set up at M3): dedicated, no personal accounts or files; Claude runs as a non-admin user with only the developer accounts it needs; native builds, simulators and devices, and the fallback when the cloud falls short (Claude says why); a macOS VM only if that proves insufficient. Apple builds in CI can use GitHub's hosted macOS runners.
8. **Network: least-privilege allowlist** per project environment — package registries, GitHub, the project's sandbox services; additions are deliberate. It also limits what a prompt-injected agent could send anywhere.

### Safety

_Agreed 2026-10-11 (LOG #19)._

1. **Walls sit outside Claude's reach** (L-36): GitHub protection on `main` (PR only, owner approval, no force-push/delete, no bypass), plain CI as a required check, credential scopes, deploys only from `main`. Everything in the session (hooks, the reviewer) is feedback and never documented as a boundary; an air-gapped reviewer is planned [after the revamp](PLAN.md#after-the-revamp).
2. **Identity:** Claude acts as `meirmsn-agent` — Write collaborator, not admin, can't approve its own PRs (D-13 trial until 2026-10-25).
3. **Guardrail files are called out:** changes to `.github/`, `.claude/`, `.devshop-version` and migrations are listed under "what you should know" in the PR, and CODEOWNERS marks them (L-37).
4. **No production secrets in Claude's reach** (L-38, L-39): no repo-level secrets; deploy secrets in a `production` environment only `main` can use; CI and local runs talk only to local/sandbox backends; test clients refuse non-local hosts (allowlist); pointing anything at production is an explicit, visible opt-in. The session holds only GitHub-as-the-agent (via the proxy), the read-only devshop token (D-01), sandbox keys and the read-only observability tokens below.
5. **Secret scanning is a required CI check,** its config tested against planted fake secrets, covering PR refs (L-40).
6. **Production observability is read-only** (errors, logs, analytics) via standing tokens in the cloud environment — each set up with **least privilege**: read-only, scoped to one project, no user data, expiry where the service supports it.
7. **Production data only by the owner's explicit grant:** a short-lived read-only credential that the service expires on its own, never a standing one. Principle now; mechanism built at M4. Checked for red flags (none blocking): Postgres `VALID UNTIL` stops new logins but doesn't drop open connections (pair it with a session timeout); a credential pasted into chat stays in the transcript (short expiry makes it moot); Cloudflare API tokens support expiry and narrow scopes — confirm D1 read-only scope when that stack home is built.
8. **Never touch work Claude didn't author** — no resetting, stashing or overwriting the owner's WIP (L-41).
9. **Everything read from outside is data, not instructions** (web pages, issues, PR comments, tool output); the walls bound what an injected instruction could do.
10. **The walls are tested:** the north-star scenario includes attempts GitHub must reject (direct push to `main`, force push, merge without approval, a workflow edit that tries to read a deploy secret).
11. **Prefer the platform's own controls.** When a service we integrate offers a safety control (token scopes and expiry, branch-limited secrets, preview/promote/rollback, deployment protection), v2 uses it rather than building one, and each stack home records which ones are on and how they're configured. On today's GitHub plan with private repos, GitHub can't hold a deploy for approval, so the owner's PR approval + "only `main` deploys" is the deploy gate (approval ships). Vercel and Cloudflare both offer a manual promote-to-production step if a second click is ever wanted. Cloudflare is the likely default platform for new projects, so its stack home models these controls first.

### Reach

_Agreed 2026-10-12 (LOG #19)._

1. **One home per stack** in the devshop (e.g. `stacks/web`, `stacks/nextjs`, `stacks/supabase`, `stacks/vercel`, `stacks/cloudflare`, `stacks/ios`): setup/template, guidelines, the platform safety controls in use ([Safety](#safety) bullet 11) and lessons. Cross-platform material (e.g. the UI guideline) lives in discipline guidelines, not stacks.
2. **Loaded only when a task touches that stack.**
3. **Stacks combine** (e.g. web + Next.js + Supabase + Vercel). **Which stacks a project uses is detected** from its own files (`package.json` dependencies, `wrangler.toml`, `supabase/`, an Xcode project), with an optional one-line override — nothing to drift. For a brand-new project the stacks come from the agreed plan (gstack eng review), recorded in its first spec, until the files exist.
4. **Added when a real project needs it:** web + Next.js + Supabase + Vercel for the M2 pilot (lalista); **Cloudflare** with the owner's personal website, started in parallel once lalista begins moving to v2; iOS at M3 (lalista's voice app). The rest of the L2 list is capability to add, not built up front.
5. **Every stack home is proven:** the devshop's CI scaffolds a fresh project from it and requires that project's CI to be green (L-46).
6. **Stack homes grow from what ships:** a project's fix to tooling its stack home owns goes back to the stack home in the same work (L-51); lessons are promoted from the devshop ledger ([Ship](#ship) bullet 9).
7. **Generic:** no project identifiers ever (L-01); project config lives in the project.

## North-star scenario (re-run at every milestone review)

_To be revised at L3 so it exercises every pillar; current version kept as the baseline._

On the fixture project, in a fresh cloud session:

1. Start from a two-line idea: "add a page that lists X with filter Y".
2. Spec with 2 decisions + 3 acceptance items; owner approves (lock recorded).
3. Implementation lands as a PR from the agent; CI runs the gate runner and the
   acceptance→test check; one acceptance item deliberately left untested on a first
   pass must **fail CI**.
4. Fix, re-run, green; advisory conformance comment present.
5. Attempts to bypass (`--no-verify`, direct push to `main`, editing a locked spec
   section, reading a deploy secret from a PR workflow) are **rejected**.
6. Owner merges; deploy waits for owner approval in the environment.
7. Record: wall-clock, owner touchpoints, tokens/CI minutes, anything manual.

At M0 most steps fail or are manual — that's the baseline. Each milestone should
turn more steps green; the walking skeleton (W3.5) makes the whole path exist early,
however crude.
