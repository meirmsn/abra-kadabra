# Notes

Research notes, insights, and reference docs captured during devshop development.

## How to use

- Add a file in the relevant subdirectory (or create a new one if no fit)
- Ask Claude: "check my notes on X" to have it read the relevant file

## Directories

### `bootstrap/` — Build blueprints (historical)

- [`v0-web.md`](bootstrap/v0-web.md) — web devshop construction plan (Phase 0)
- [`v0-gaps.md`](bootstrap/v0-gaps.md) — structural gaps identified in v0 plan review
- [`v1.2-reorganization.md`](bootstrap/v1.2-reorganization.md) — template separation: what changed, why, file-by-file details
- [`v1.2-comparison-to-before-split.md`](bootstrap/v1.2-comparison-to-before-split.md) — pre/post split comparison
- [`v+-native.md`](bootstrap/v+-native.md) — native/mobile capability plan (deferred)

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
