# Target picture

What the devshop should be when the revamp is done, agreed **top-down** with the
owner in the plan review session (LOG #5): each level is agreed before the next one
down is discussed. Decisions in [DECISIONS.md](DECISIONS.md) are settled at the level
where they belong (mostly L3). Every milestone review checks progress against this
page and whether the page itself is still right
([PROCESS.md § 5](PROCESS.md#milestone-review-each-m-exit--the-whole-picture-check)).

| Level | Form                     | Status                                 |
| ----- | ------------------------ | -------------------------------------- |
| L0    | One sentence (ish)       | **agreed** 2026-10-08                  |
| L1    | One paragraph            | **agreed** 2026-10-08                  |
| L2    | One line per pillar      | draft — refined pillar by pillar next  |
| L3    | A few bullets per pillar | not started — where decisions are made |
| L4    | Milestones + tasks       | re-derived from L0–L3 (PLAN.md)        |

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

## L2 — pillars (draft)

1. **Intent** — every change starts as a conversation in which Claude helps you shape the idea at the depth it deserves (gstack's thinking skills for apps and features), ending in a written spec you'd recognise as exactly what you meant; for bigger changes you glance at a one-screen summary and say "go" (agreed 2026-10-09).
2. **Build** — one agent builds the change, updating code, tests and docs together, following the devshop's guidelines for each discipline involved plus the project's own, and runs the new and affected tests where it works (cloud or Mac) as it goes (agreed 2026-10-09).
3. **Verify** — before you see a PR, an adversarial reviewer running independently of the builder checks the finished change against the product intent and the spec, then through the other lenses that apply (code, security, design, QA, docs, tests). Anything skipped, trimmed or weakened is a failure Claude must fix; after three unresolved rounds, or when something can't be done as agreed, Claude stops and asks you — so a PR arrives complete, or with your decisions already in it. PR CI stays plain: tests and deterministic checks only, no agentic jobs (agreed 2026-10-09).
   - Direction for L3: reviewer = a small script running locked-down `claude -p` with read-only tools inside the repo, invoked by the "done"/open-PR check itself so the builder never relays the verdict; no "skip with a reason" bypasses anywhere — today's 11 bypass-justification review types are deleted, the dismissed-findings and quality-lens reviews fold into this reviewer.
4. **Review** — you get a PR you can judge quickly: it always opens with a one-line summary of the change, then goes level by level down to engineering detail, with the user-facing announcement in its own section when there is one; screenshots/video and a preview link. You comment, Claude revises through the same verify loop, and your approval ships it — merge on green CI, deploy follows (agreed 2026-10-09).
   - Your approval is only a real gate if the agent has its own GitHub identity (D-13); owner proposes a GitHub App — spike A-05 (can a cloud session push/open PRs as an App?) early in M0; fallbacks: machine user, or same identity + no-bypass rulesets (stated honestly).
5. **Ship** — your approval ships it: web app and backend deploy to production automatically; native changes accumulate on `main` until you cut a version (Claude can propose one), which goes to the testing tracks and then the stores, each step your call. Claude watches production (canary, errors, the change's metrics), alerts you if something looks wrong, and records what shipped and what was learned in the project's log and plan. Rollback is your call, with a revert ready (agreed 2026-10-09).
   - For L3: native PRs need a preview substitute (simulator screenshots/video from the Mac attached to the PR).
6. **Safety** — Claude is treated as untrusted: it works under its own limited identity, holds no production secrets, can't change its own guardrails or merge around the checks, and reaches nothing beyond its session and the services/machines scoped to it. The rules that matter are enforced where Claude can't reach them (GitHub rules, CI, credentials, protected deploys); anything inside the session is helpful feedback, not the defence. Production access is read-only observability (errors, logs, analytics); read access to production data only when you explicitly grant it, time-limited and enforced outside Claude's reach (agreed 2026-10-09; settles D-04).
   - For L3: the grant mechanism (e.g. you mint a short-lived read-only DB role/credential that expires on its own); never a standing credential Claude can reuse.
7. **Environments** — cloud sessions by default from any device; a scoped local Mac for native builds/simulators/devices and as fallback when the cloud falls short.
8. **Reach** — web apps (responsive, PWA), marketing sites, backends (Cloudflare, Supabase, AWS), native Apple, Android, React Native, Electron — each added when a real project needs it.
9. **Shape** — projects free of the devshop; pinned versions with guided upgrades/migrations; new + adopted projects; gstack as the toolbox; small, grows only from proven lessons.

### Inputs parked for L3 (from the owner, 2026-10-08)

- **Intent:** gstack thinking skills before the spec, deep for apps/features, light for fixes. The spec must satisfy the agreed intent first; how it's tested comes after and must not trim it.
- **Build:** one agent pulls the relevant guidelines (frontend, backend, data, UI, UX, security…) + project guidelines; no persona-per-agent requirement. Run the tests relevant to the change in the session (cloud or Mac) rather than waiting on CI; CI is for the full suite once ready for review (today the template runs CI on every PR push).
- **Verify:** an adversarial review at the end against intent is required; earlier checkpoints (spec ↔ discussion, slice ↔ spec) are candidates — recommendation: spec ↔ discussion standard, slice ↔ spec tested on the walking skeleton. Docs are part of the check (future agents use them as context).
- **Review:** title style as the devshop does today; description hierarchical; announcement blurb for non-technical readers on top when applicable; screenshots/video; preview link.
- **Safety:** prevent a rogue or prompt-injected agent from taking over; keep Claude away from sensitive data/code and from the owner's machines except scoped, walled-off environments (e.g. Supabase in its own container; a separate Mac for Apple work). "No vulnerabilities" is pursued by layered checks, not promised.
- **Reach:** Apple builds can also use GitHub-hosted macOS runners in CI; the Mac is for interactive work.
- **Shape:** an outside collaborator can clone and contribute without the devshop; several projects on different devshop versions at once; moving to the latest version may involve a project migration.

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
