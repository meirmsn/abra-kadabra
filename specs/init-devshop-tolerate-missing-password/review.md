# Review — init-devshop-tolerate-missing-password

## Audit 1: manual (2026-05-13)

<!-- audited-at: a008e35e2fe4ef6cbc905c9c4c63bb5995e0024e -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=3

### Docs findings

- [low] kit/docs/guide/ops.md:370 — new troubleshooting entry references `v1.29+` as the version that ships the non-fatal behavior, but `kit/version` is currently at `1.28.0`. Forward reference will be true at next release; not a fix-required nit.

### Tests findings

- [low] kit/scripts/init-devshop.sh — DEVCONTAINER_ROOT_PASSWORD non-fatal tolerance (a83f0ac) has no `.bats` pair. Captured by ops.md troubleshooting + inline yellow advisory. Direct test would require simulating postStartCommand sudo invocation with `.env` present but missing the key.
- [low] kit/scripts/init-devshop.sh — pnpm storeDir cwd swap (921b644) has no `.bats` pair. Captured by 6-line WHY comment above the patched line. Direct test would require simulating a devshop-self container rebuild and inspecting `node_modules/.modules.yaml`.

### Bypass trailer audit

- a008e35 Docs-Coverage-Bypass: ".devcontainer/devcontainer-lock.json [...] passive build state [...]" — VERIFIED. Lockfile pins existing-already-used feature version; neither security.md nor ops.md routing target shifted at HEAD.
- 921b644 Docs-Coverage-Bypass: "Internal cwd swap in init-devshop.sh devshop-self pnpm install [...]" — VERIFIED. Internal fix with WHY captured in-script; no user-facing surface change.
- a07ac4c Docs-Coverage-Bypass: "Both changes ARE docs (SKILL.md prose) [...] 'distribute operational copy into the skills that fire'" — VERIFIED. Named distinctive phrases (`gh run view --json conclusion`, `supabase-js maintains one WebSocket per RealtimeClient`) verifiable in staged diff at the named SKILL.md sections.
- 0d795f5 Docs-Coverage-Bypass: "kit/scripts/sync/lib/detect-mode.sh is a new infrastructure surface; doc update lives in commit 2 of this 3-commit split [...]" — VERIFIED (deferral honored). The follow-up commit `e77eda8` landed the hooks.md § 3 update naming the lib by path + DEVSHOP_FORCE_MODE override.
