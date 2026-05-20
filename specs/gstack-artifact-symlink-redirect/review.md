# Review — gstack-artifact-symlink-redirect

## Audit 1: manual (2026-05-20)

<!-- audited-at: a20c2002441663fb94a6156fbb80afaa2b8f1443 -->
<!-- range: d3a690670525ce336c3d9c95002c8e7e7bb256ee..a20c2002441663fb94a6156fbb80afaa2b8f1443 -->

findings: high=0 medium=0 low=2

### Docs findings

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/ops.md:299
**What**: Backfill recipe lede says "If a project's `init-devshop.sh` predates the symlink block" — but the file the operator edits (and the recipe shows being edited with `sudo nano /devshop/kit/scripts/init-devshop.sh`) is the devshop-canonical script, not the project's thin forwarder at `.devcontainer/init-devshop.sh`.
**Why**: A reader following the lede looks for the symlink block in `<workspace>/.devcontainer/init-devshop.sh` (a thin forwarder per `architecture.md § Thin forwarder mechanism`), doesn't find it, and may try to edit the forwarder. The lede should name the canonical script to avoid the misdirection.
**Fix**: Reword the lede to "If the devshop's `kit/scripts/init-devshop.sh` on this host predates the symlink block (no `GSTACK_PROJECTS_LINK` declaration), add it manually so the next container start picks it up" — matches the `sudo nano` path that follows.

### [domain: docs] [section: C] [severity: low]
**File**: kit/notes/migration-info-loss-audit.md:86
**What**: Historical migration-audit row describes the post-trim CLAUDE.md § gstack as containing "`.gstack/projects/**/*.md` tracking rule" — but the just-shipped CLAUDE.md § gstack now tracks four extensions (`.md` / `.html` / `.png` / `.json`), not just `.md`.
**Why**: Future audit runs that consult this notes/ entry to understand "what's in CLAUDE.md § gstack" get a stale single-extension picture. The audit note is descriptive (records what was condensed at audit time) — once the condensed entry's content changes shape, the description drifts. The same condensation row is now describing prior state, not current.
**Fix**: Either annotate the row inline ("`.gstack/projects/**/*.md` tracking rule (later widened to 4 extensions in `feat(gstack-artifacts)` 2026-05-20)") OR refresh the description to "`.gstack/projects/**` four-extension tracking rule (md/html/png/json) + `GSTACK_HOME` / `GSTACK_STATE_DIR` split-brain note + symlink-redirect for hardcoded-path holdouts". Low-priority hygiene — the notes file isn't load-bearing.

No Docs-Coverage-Bypass trailers in range.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
