# Notes

Research notes, insights, and reference docs captured during devshop development.

## How to use

- Add a file per topic (e.g. `setup-supabase.md`, `sudo-hardening.md`)
- Ask Claude: "check my notes on X" to have it read the relevant file
- Promote anything cross-session useful to `.claude/projects/-workspace/memory/` if you want Claude to act on it automatically

## Contents

- [`setup-supabase.md`](setup-supabase.md) — environment strategy (remote vs local vs staging), applying migrations, CLI setup in dev container, firewall config
- [`sign-in-with-apple.md`](sign-in-with-apple.md) — notes on how to dev with Sign in with Apple
- [`sudo-hardening.md`](sudo-hardening.md) — analysis of node user sudo access security risks
- [`acfs-review.md`](acfs-review.md) — insights from external "Agentic Coding Flywheel" framework review
- [`backend-alternatives-research.md`](backend-alternatives-research.md) — research on backend deployment alternatives to Supabase
- [`integration-test-local-alternatives.md`](integration-test-local-alternatives.md) — testing strategies for constrained hardware

## Bootstrap (historical)

Build blueprints for the devshop construction:

- [`bootstrap/v0-web.md`](bootstrap/v0-web.md) — web devshop construction plan (Phase 0)
- [`bootstrap/v0-gaps.md`](bootstrap/v0-gaps.md) — structural gaps identified in v0 plan review
- [`bootstrap/v1-native.md`](bootstrap/v1-native.md) — native/mobile capability plan (deferred)
