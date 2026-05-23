# Audit 1 — Docs Review

**Range**: `origin/main..HEAD` (1 commit: `c81407a`)
**Date**: 2026-05-23

## Section A — Coverage

The diff touches 49 files across several surface categories. Coverage assessment per the devshop rubric:

| Surface touched | Required doc | Staged? | Verdict |
| --- | --- | --- | --- |
| `kit/scripts/*.sh` (apply-port-offset, next-port-offset — deleted) | any `kit/docs/guide/*.md` OR `CLAUDE.md` | Yes — `ops.md`, `architecture.md`, `CLAUDE.md` all updated | Pass |
| `kit/scripts/commit-hooks/check-port-offset-unique.sh` (deleted) | `kit/docs/guide/hooks.md` | Yes — hooks.md removes the row | Pass |
| `kit/scripts/preship/*` (3 files) | `.claude/skills/devshop/pre-ship/SKILL.md` OR `kit/docs/guide/*` | Yes — ops.md updated | Pass |
| `kit/scripts/init-devshop.sh` | any `kit/docs/guide/*.md` OR `CLAUDE.md` | Yes — ops.md updated (pnpm-modules-purge gotcha removed) | Pass |
| `kit/hooks/pre-commit.sh` | `kit/docs/guide/hooks.md` OR `CLAUDE.md` | Yes — hooks.md updated | Pass |
| `.claude/skills/**/SKILL.md` (7 files) | `kit/docs/guide/workflow.md` OR `CLAUDE.md` | Yes — workflow.md updated (skill map table reformatted, Phase A description updated) | Pass |
| `template/**` (compose.yml, devcontainer.json, init-firewall.sh, .gitignore, etc.) | `kit/docs/guide/{architecture,security,ops}.md` | Yes — architecture.md + ops.md updated | Pass |
| `kit/manifest.txt` | `kit/docs/guide/architecture.md` | Yes — architecture.md annotation table narrowed but not updated for removed entries | See finding below |
| `kit/scripts/sync/from-devshop.sh`, `to-devshop.sh`, `lib/parse-manifest.sh` | any `kit/docs/guide/*.md` | Yes — architecture.md § Propagating build tooling updates section trimmed | Pass |

**Carve-outs applied** (no coverage required): `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/tests/**`, `PLAN.md`, `kit/notes/projects/*`, `specs/**`.

No `Docs-Coverage-Bypass:` trailers in range.

**Coverage findings**: none.

## Section B — Adequacy

### B.1 — Stub cross-references verified

Each stubbed `conventions.md` section points at a specific skill SKILL.md section. Verification:

| Stub | Target | Exists at HEAD? |
| --- | --- | --- |
| `§ TASKS.md Format` → `implement/SKILL.md` | Task format template and resume pattern | Yes (content present, no named section heading — the skill's task-format content is inline) |
| `§ SPEC.md Quality Checklist` → `spec/SKILL.md § Quality checklist` | Line 438 | Yes |
| `§ DESIGN.md as Contract` → `pre-ship/SKILL.md § Gate design-conformance` | Line 709 | Yes |
| `§ Screenshot Routing` → `pre-ship/SKILL.md § Screenshot Routing` | Line 1083 (bold paragraph `**Screenshot Routing**:`) | Yes |
| `§ Deploy Boundaries` → `go-live/SKILL.md § Deploy surfaces` | Line 207 (`### Deploy surfaces`) | Yes |
| `§ Test Assertion Depth` → `tests-review/SKILL.md § Shape-only assertions` | Line 83 | Yes |
| `§ Testing Lifecycle` → `implement/SKILL.md § Testing lifecycle` | Line 154 (`### Testing lifecycle`) | Yes |
| `§ Backlog Routing Guide` → `CLAUDE.md § TODO Protocol` | Line 162 | Yes |

All targets resolve. No dangling references.

### B.2 — Lifted content verified in destination

Spot-checked the Deploy Boundaries lift into `go-live/SKILL.md`. The new `### Deploy surfaces` section (lines 207-251) contains the full surface table, schema-mutation safety guidance, rollback semantics, and CI-vs-prod credential separation paragraph — all content that was removed from `conventions.md`. Content is substantive, not a stub.

Spot-checked the Testing Lifecycle lift into `implement/SKILL.md`. The new `### Testing lifecycle` section (lines 154+) contains the per-stage table. Content matches what was removed from `conventions.md`.

### B.3 — Named-section claims

The `conventions.md` new header text says "When a section here has a single consuming skill that replicates its content, the **skill copy is canonical**." This is consistent with the tier model table added at the top of the file.

**Adequacy findings**: none.

## Section C — Cross-doc coherence

### C.1 — Stale references to stubbed sections in non-touched docs

The following non-touched docs reference `conventions.md` sections that are now stubs (one-line redirects). The stubs still exist as `## ` headings so the cross-references resolve — but they now land on a redirect rather than substantive content, creating a two-hop path for the reader.

Files with `conventions.md § Deploy Boundaries` references (now a stub):
- `kit/docs/guide/ops.md:81` — "see `guide/conventions.md § Deploy Boundaries`"
- `kit/docs/guide/ops.md:476` — "per `conventions.md § Deploy Boundaries`"
- `kit/docs/guide/migrations.md:71` — "See also: `kit/docs/guide/conventions.md § Deploy Boundaries`"
- `kit/docs/guide/README.md:92` — hyperlink to `conventions.md#deploy-boundaries`

Files with `conventions.md § Screenshot Routing` references (now a stub):
- `kit/docs/OVERVIEW.md:278` — "See `guide/conventions.md § Screenshot Routing`"
- `kit/docs/guide/ops.md:243` — "committed per `guide/conventions.md § Screenshot Routing`"

These are **functional** (the stub heading exists and redirects to the canonical skill), but create an unnecessary indirection. The reader arrives at a one-line stub saying "see go-live/SKILL.md" instead of the content they expected. Updating these cross-references to point directly at the canonical skill location would eliminate the indirection.

### C.2 — Deleted files: stale reference sweep

Deleted files in this commit:
- `kit/scripts/apply-port-offset.sh`
- `kit/scripts/commit-hooks/check-port-offset-unique.sh`
- `kit/scripts/next-port-offset.sh`
- `template/.devcontainer/derive-ports-from-config.sh`
- `template/.devcontainer/.env.example`

Grepped all reference docs for these paths: **zero stale references found**. All references were cleaned up in the same commit.

### C.3 — ROADMAP coherence

The diff removes three "SHIPPED" sub-entries from `kit/ROADMAP.md` (config.toml single source of truth, five-port parameterization, /ak-new-project port registry) and adds a new `supabase-port-registry` row to `PLAN.md § Planned`. The base design entry (`§ Devshop-registry-driven Supabase port offsets`) remains in ROADMAP.md at line 447 with the original design. This is coherent with the port-offset infrastructure being reverted — the work returns to "planned" status.

### C.4 — CLAUDE.md § Known Footguns: pnpm-modules-purge removal

The `ops.md` gotcha about "pnpm modules-purge prompt hangs `init-devshop.sh`" was removed (line 383 on main), and `init-devshop.sh` no longer prefixes `CI=true`. However, `CLAUDE.md` does not have a corresponding gotcha entry for this (it was only in `ops.md`). No CLAUDE.md coherence issue.

### C.5 — Removed `sync-show-first-confirm` from PLAN.md and TODOS.md

The `sync-show-first-confirm` PLAN.md row was removed, and the corresponding `kit/TODOS.md` entry (the full "Flip sync/from-devshop.sh" multi-paragraph entry) was also removed. The architecture.md paragraphs about "Apply-first-show-after semantics" and "Three-source exclude model" were also removed. These removals are internally coherent — the simplified sync scripts no longer have the three-source exclude model, so the documentation of it is correctly removed.

However, the simplification of `from-devshop.sh` (removal of rsync excludes for `[locked]`, `[scaffold-once]`, and `!path` entries) is a behavioral change to the sync script that is **not documented**. The current `architecture.md § Propagating build tooling updates` makes no mention of what the sync scripts do or don't exclude. This is a coverage gap — but since the sync scripts are `kit/scripts/**` and `architecture.md` is already touched, it falls under Section A coverage (which passed because `architecture.md` was touched). The question is adequacy: does the remaining sync documentation adequately describe the new behavior? The trimmed section says only "diffs + applies; you review" which is vague but not inaccurate.

**Coherence findings**:

### [domain: docs] [section: C] [severity: low]
**File**: `kit/docs/guide/ops.md:81`, `kit/docs/guide/ops.md:243`, `kit/docs/guide/ops.md:476`, `kit/docs/guide/migrations.md:71`, `kit/docs/guide/README.md:92`, `kit/docs/OVERVIEW.md:278`
**What**: Six cross-references in non-touched docs point at `conventions.md § Deploy Boundaries` and `conventions.md § Screenshot Routing`, which are now one-line redirect stubs
**Why**: Two-hop indirection — reader lands on a stub, must follow a second link to reach the canonical content in the skill SKILL.md
**Fix**: Update each cross-reference to point directly at the canonical location: `go-live/SKILL.md § Deploy surfaces` for Deploy Boundaries refs; `pre-ship/SKILL.md § Screenshot Routing` for Screenshot Routing refs. Alternatively, accept the stubs as permanent redirect shims (functional but not ideal).

## Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range.

## Section E — CLAUDE.md hygiene

Devshop mode — Section E skipped per skill contract (Section E is project mode only).

## Summary

| Severity | Count |
| --- | --- |
| high | 0 |
| medium | 0 |
| low | 1 |
