# Review — compose-isolation-manifest-locked

## Audit 1: manual (2026-05-20)

<!-- audited-at: 87e645673b87eedd852dd2c090f6ddb72709ce7d -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=2 low=3

### Docs findings

- [medium] kit/docs/guide/security.md:41 — § Security-Critical Files enumerates `.devcontainer/*` but omits the four compose-isolation siblings this PR moves into `[locked]`; reader looking up "what is security-critical" no longer matches the manifest invariant.
- [medium] kit/docs/guide/security.md:26 — § Core Principle blanket-states "security-critical files are `root:root 644`" which contradicts the new per-file mode (755 for `init-host-env.sh` + `cmd-relay.mjs`), the architecture.md row updated in this PR, and the existing § Authoring locked files recipe.
- [low] kit/ROADMAP.md:747 — § Sub-bundle E acceptance still says "The B + C bundles touch different surfaces and should stay separate" after this PR removed the C bundle (stale cross-reference per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`).

### Tests findings

- [low] kit/tests/manifest-lifecycle.bats — no test directly asserts `.devcontainer/supabase-runner` appears in `manifest_paths_by locked-dir`; a future commit could silently drop the `[locked-dir]` annotation and lose the sticky-bit lock.
- [low] kit/tests/manifest-lifecycle.bats — the `[ -f "$src" ]` skip-on-absent-source guard in `init-devshop.sh` is newly load-bearing (host-supabase / skip projects don't carry compose-isolation files) but no static grep pins the guard pattern.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: e0030ac64f41f4255737e63392275e2e54a212b3 -->
<!-- range: 3cc73ca..HEAD -->

findings: high=0 medium=0 low=0

Audit 2: clean — all Audit 1 findings closed by commit `e0030ac`:

- Docs:
  - security.md:26 — Core Principle bullet 1 rewritten to per-file mode (closes the "root:root 644" blanket).
  - security.md:41 — enumeration extended with the four compose-isolation siblings + their modes (closes the missing-files finding).
  - ROADMAP.md:747 — trailing sentence trimmed to "B bundle ... A + E" (closes the stale "B + C bundles" cross-reference).
- Tests:
  - manifest-lifecycle.bats new test `regression: .devcontainer/supabase-runner is [locked-dir] in manifest` (closes the missing [locked-dir] assertion).
  - manifest-lifecycle.bats third grep `if [ -f "$src" ]; then` inside the install-pattern test (closes the missing absent-source guard pin).

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
