<!-- tasks for feature: bats-drift-guards -->

# Tasks: bats-drift-guards

- [x] **Task 1 — wiring-test-skill-autodetect** (D1 + D2): added SKILL.md-basename
      autodetect branch to the wiring `@test`; pruned `reconcile-task-commits.sh` +
      `virtiofs-rebase.sh` from `infra_scripts`; kept `vendor-bats-libs.sh`; updated
      the comment block. bats structural-invariants green. Committed `ee0383b`.
- [x] **Task 2 — grep-test-drift-guard** (D3 + D4 + D5): appended the `# pins:`-scanning
      `@test`; seeded 3 live annotations; documented the convention in conventions.md.
      bats structural-invariants green. Committed `c96f480`.
- [x] **Task 3 — sudo-scoping-node tracker closure** (D6): deleted PLAN row + 3 TODOS
      entries; rewrote sudo-hardening.md to solved; unwound cross-refs; deleted 2
      FRICTION-LOG entries; added Historical-backfill BUILD-LOG entry. Committed `82da6b6`.

Full suite: `kit/tests/lib/bats-core/bin/bats kit/tests/` → 1646 ok, 0 not ok, exit 0.

## Decisions

### Skills-dir resolution for the wiring test (D1)

Followed the file's existing `$DEVSHOP` (`/devshop`) idiom for the wiring test's
skills-dir read (`$DEVSHOP/.claude/skills`), not `git rev-parse --show-toplevel`.
Verified in this worktree: the autodetect branch + `infra_scripts` prune run green.
The `.claude/skills/` content is identical between `/devshop` and the worktree, and
the rest of the wiring test already reads `$DEVSHOP`, so consistency wins. The
NEW grep-drift guard (D3), by contrast, resolves target paths via
`git rev-parse --show-toplevel` to match the scaffold/convention tests at ~l.805+
(it must validate the source shipping in this worktree).

### grep-drift guard parsing hardening (D3)

- Splits on the FIRST `::` only (literal may contain colons).
- Anchors the annotation scan to comment lines starting with `# pins: ` (after
  optional indentation) via `grep -rHnE '^[[:space:]]*# pins: '` so the guard's own
  documentation/code lines that merely mention `# pins:` (and the echoed failure
  message) are NOT scanned as annotations.
- Skips placeholder forms whose path contains `<`/`>` (belt-and-suspenders for the
  convention's own `# pins: <path> :: <literal>` example).
- Verified the guard goes RED when a seed literal is corrupted and GREEN when restored.

### Seed selection (D4) — 3 clean seeds across 2 files

1. `util-build-phase58-audit-parser.bats` → pins `/ak-check-docs-and-tests` in
   `.claude/skills/devshop/build/SKILL.md` (stable command name).
2. `firewall-extras-overlay.bats` → pins `One bare hostname per line` in
   `template/.devcontainer/firewall-extra-domains` (stable header literal).
3. `firewall-extras-overlay.bats` → pins `.devcontainer/firewall-extra-domains
[scaffold-once]` in `kit/manifest.txt` (stable structural token).

Each literal was confirmed present (`grep -qF`) in its target at HEAD before seeding.

**Rejected candidate:** `util-adversarial-review-narrowing.bats` — its grep
assertions target `$CAPTURED_PROMPT`, a runtime-captured temp file, NOT a stable
repo source/doc file. The `# pins:` convention pins a literal in a repo-relative
file, so this test is not a clean fit; skipped it and used the two firewall-extras
seeds (which the friction log also named) plus the build-phase58 seed. 3 clean
seeds total — exceeds the 2-3 target.
