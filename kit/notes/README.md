# Notes

Research notes, insights, and reference docs captured during devshop development.

Two kinds of notes live here:

- **Topic notes** — under `<topic>/` subdirectories. Persistent reference material, organized by domain (e.g., `bootstrap/`, `roadmap/`, `security/`, `design/`). Add new topics when none fit.
- **Handoff notes** — at the root level (no subdirectory). Self-contained current-state handoffs for active workstreams. One file per active workstream. Self-contained means: a fresh reader (or fresh Claude session) can pick up the work from this single doc without needing to read its predecessor docs. Delete when the workstream completes — git history preserves the original.

## When a handoff completes

Delete the root-level handoff file. Don't archive into `old/` or `superseded/` subfolders — those accumulate dead weight while still cluttering directory listings. Git is the right place for "preserved but not active":

```bash
git log --all --diff-filter=D --name-only -- 'kit/notes/*.md'   # find deleted handoffs
git show <commit>:<path>                                         # retrieve a deleted handoff
```

Same convention applies to topic notes that get superseded by a newer doc — delete the old one, let git history hold it.

## How to use

- Add a topic file in the relevant subdirectory (or create a new subdirectory if no topic fits)
- For an active workstream, place the handoff at the root level (and add an entry under "Active handoffs" below)
- Ask Claude: "check my notes on X" to have it read the relevant file

## Active handoffs (root-level)

- [`lalista-migration-resume.md`](lalista-migration-resume.md) — self-contained handoff for the Swift→Next.js lalista migration. Covers PR 2 close-out, Fixes A-D pre-ship reliability plan, PR 3 (core flows), PR 4 (CI slow job). Delete when migration completes.

## Directories

### `bootstrap/` — Build blueprints (historical)

- [`v0-web.md`](bootstrap/v0-web.md) — web devshop construction plan (Phase 0)
- [`v0-gaps.md`](bootstrap/v0-gaps.md) — structural gaps identified in v0 plan review
- [`v1.2-reorganization.md`](bootstrap/v1.2-reorganization.md) — template separation: what changed, why, file-by-file details
- [`v1.2-comparison-to-before-split.md`](bootstrap/v1.2-comparison-to-before-split.md) — pre/post split comparison
- [`v+-native.md`](bootstrap/v+-native.md) — native/mobile capability plan (deferred)

### `roadmap/` — Implementation plans for ROADMAP entries

Plans that take a specific `kit/ROADMAP.md` entry from "we should do this eventually" to "here's exactly how."

- [`hook-migration-plan.md`](roadmap/hook-migration-plan.md) — git-layer migration: PostToolUse Bash workflow hooks → husky pre-push + skill ownership. Resolves the subagent-hooks audience problem; closes TODOs 76/77/78.

### `security/` — Security model and hardening

- [`security-model.md`](security/security-model.md) — 6-layer permissions model: root ownership, sticky bits, deny rules, DCG, git hooks, PreToolUse hooks
- [`sudo-hardening.md`](security/sudo-hardening.md) — analysis of node user sudo access security risks

### `design/` — Devshop design decisions

- [`ak-commit-design.md`](design/ak-commit-design.md) — commit guard architecture and adversarial review design
- [`devshop-split.md`](design/devshop-split.md) — audit of the devshop separation (what changed, known issues)

### `research/` — Research and external reviews

- [`backend-alternatives-research.md`](research/backend-alternatives-research.md) — backend deployment alternatives to Supabase
- [`integration-test-local-alternatives.md`](research/integration-test-local-alternatives.md) — testing strategies for constrained hardware
- [`acfs-review.md`](research/acfs-review.md) — insights from external "Agentic Coding Flywheel" framework review

### `setup/` — Service setup guides

- [`setup-supabase.md`](setup/setup-supabase.md) — environment strategy, migrations, CLI setup, firewall config
- [`sign-in-with-apple.md`](setup/sign-in-with-apple.md) — notes on how to dev with Sign in with Apple
