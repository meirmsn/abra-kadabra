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
3. **Verify** — adversarial review against intent + security checks; CI runs the full suite at review time (not as the inner loop).
4. **Review** — PR with a plain title, hierarchical description (announcement line on top when applicable), visuals, preview; you approve.
5. **Ship** — deploy after your approval, canary, observability/metrics, logs + plan updated; rollback is your call.
6. **Safety** — own limited identity; boundary on GitHub + credentials; no production secrets; scoped machine access.
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
