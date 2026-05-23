# Docs Review — Audit 1

<!-- audited-at: 6c80d31 -->

**Range**: `origin/main..HEAD` (15 commits)
**Mode**: devshop self-mode (`/devshop`)
**Reference docs touched**: `kit/docs/guide/architecture.md`, `kit/docs/guide/conventions.md`, `kit/docs/guide/hooks.md`, `kit/docs/guide/ops.md`, `kit/docs/guide/workflow.md`
**Skill touched**: `.claude/skills/devshop/new-project/SKILL.md`

---

## Section A — Coverage

All six surface-to-doc mappings from the devshop rubric are satisfied:

| Surface path                                           | Required doc                                    | Staged doc                                | Result |
| ------------------------------------------------------ | ----------------------------------------------- | ----------------------------------------- | ------ |
| `kit/scripts/**` (9 files)                             | any `kit/docs/guide/*.md` OR `CLAUDE.md`        | architecture.md, ops.md, conventions.md   | PASS   |
| `kit/scripts/commit-hooks/check-port-offset-unique.sh` | `kit/docs/guide/hooks.md`                       | hooks.md (lines 59, 160)                  | PASS   |
| `kit/hooks/pre-commit.sh`                              | `kit/docs/guide/hooks.md` OR `CLAUDE.md`        | hooks.md (line 59)                        | PASS   |
| `.claude/skills/devshop/new-project/SKILL.md`          | `kit/docs/guide/workflow.md` OR `CLAUDE.md`     | workflow.md (Phase A description updated) | PASS   |
| `template/**` (9 files)                                | `kit/docs/guide/{architecture,security,ops}.md` | architecture.md, ops.md                   | PASS   |
| `kit/manifest.txt`                                     | `kit/docs/guide/architecture.md`                | architecture.md (lines 89, 99)            | PASS   |

Carve-outs applied (no coverage required): `kit/notes/projects/*.md`, `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/tests/**`, `PLAN.md`.

**Coverage findings**: 0.

---

## Section B — Adequacy

All touched reference docs contain substantive updates — no stubs, no whitespace-only edits.

**Verified claims (empirical):**

- `ops.md § Port rebinding`: claims `derive-ports-from-config.sh` reads 5 sections (`[api]`, `[db]`, `[studio]`, `[inbucket]`, `[analytics]`). Verified — script uses `extract_port` with all 5 section names.
- `ops.md § Downstream consumers`: lists 7 consumers of `.env` port keys. All 7 verified by grep against source:
  - `init-firewall.sh`: 22 references to port vars. PASS.
  - `compose.yml`: uses `${SUPABASE_API_PORT:?...}` / `${SUPABASE_DB_PORT:?...}`. PASS.
  - `supabase-bootstrap.sh`: resolves API+DB ports at lines 47-48. PASS.
  - `advisor-clean.sh`: resolves DB port at line 96-99. PASS.
  - `migration-rollback-roundtrip.sh`: resolves DB port at line 84-87. PASS.
  - `advisor-probe.mjs`: asserts `SUPABASE_DB_PORT` at startup. PASS.
  - `inbucket.ts`: reads `SUPABASE_MAILPIT_PORT` at line 33. PASS.
- `ops.md § Port offset registry`: claims lalista offset 0, home-os offset 100. Verified in `kit/notes/projects/*.md` frontmatter. PASS.
- `ops.md § Duplicate-offset guard`: claims `check-port-offset-unique.sh`. File exists, hook wired in both `pre-commit.sh` code paths. PASS.
- `architecture.md § File lifecycle`: claims `.devcontainer/.env.example` is `[scaffold-once]`. Verified in `kit/manifest.txt`. PASS.
- `hooks.md § check-port-offset-unique.sh`: guard table entry matches the script's behavior (deterministic, devshop-only, no bypass). PASS.
- `workflow.md § Starting a New Project`: Phase A description updated to include port-offset auto-assignment, 5-port sed pass, `additional_redirect_urls` fix, `.env` derivation. PASS.

**Named-mechanism empirical verification:**

- `ops.md § pnpm modules-purge prompt` claims `su node -c` invocations at "devshop-self at line 61, project-mode at line 127". Actual lines post-edit: comment at 62/133, command at 67/136. The cited line numbers are ~6-9 lines off due to edits in this branch shifting the code down. The correct code blocks are referenced — the reader would find the right code by searching for the `su node -c` pattern near the cited lines.

### [domain: docs] [section: B] [severity: low]

**File**: `kit/docs/guide/ops.md:414`
**What**: Line-number citations for `su node -c` invocations in `init-devshop.sh` are stale (claims line 61/127; actual 67/136).
**Why**: Line numbers shifted by 6-9 lines due to other edits in this branch. Inherently fragile citation.
**Fix**: Update to "devshop-self at line ~67, project-mode at line ~136" or remove line-number citations in favor of search-friendly descriptors like "the `su node -c` block under the `# Devshop-self pnpm install` comment".

---

## Section C — Cross-doc coherence

- No renamed or deleted files in this range (`git diff --name-status --diff-filter=DR -M` returned empty). No stale-path sweep needed.
- Port-related claims are consistent across all 5 touched guide docs + CLAUDE.md + OVERVIEW.md + README.md. No contradictions found.
- `OVERVIEW.md` makes no port-specific claims — no coherence concern.
- `README.md` makes no port-specific claims — no coherence concern.
- `architecture.md § File lifecycle` and `ops.md § Port rebinding` are complementary, not contradictory: architecture.md describes the `.env` file's hybrid lifecycle and the derive script's role; ops.md documents the full port-rebinding workflow and downstream consumers. Cross-references are accurate.

**Coherence findings**: 0.

---

## Section D — Bypass trailer audit

**Trailers found**: 1.

| Commit    | Trailer                                                                                                                                                                                                                                                         | Verdict      |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ |
| `172aa2b` | `Docs-Coverage-Bypass: init-devshop.sh quoting fix is cosmetic — changes variable assignment style from quoted to unquoted to avoid manifest double-source test false positive. No behavioral change, no doc impact. All docs updated in prior commit 50fd37f.` | **VERIFIED** |

Verification: commit `172aa2b` touches only `kit/scripts/init-devshop.sh` (single-line quoting change: `DERIVE_SCRIPT="..."` → `DERIVE_SCRIPT=...`). Commit `50fd37f` (immediately prior) updated `kit/docs/guide/architecture.md` + `kit/docs/guide/ops.md` with the full derive-ports-from-config documentation. The bypass is valid — the quoting change is genuinely cosmetic with no behavioral or doc impact.

---

## Section E — CLAUDE.md hygiene

Skipped — devshop self-mode. Section E fires in project mode only.

---

## Summary

| Section               | Findings       | High  | Medium | Low   |
| --------------------- | -------------- | ----- | ------ | ----- |
| A — Coverage          | 0              | 0     | 0      | 0     |
| B — Adequacy          | 1              | 0     | 0      | 1     |
| C — Coherence         | 0              | 0     | 0      | 0     |
| D — Bypass trailers   | 0 (1 VERIFIED) | 0     | 0      | 0     |
| E — CLAUDE.md hygiene | skipped        | —     | —      | —     |
| **Total**             | **1**          | **0** | **0**  | **1** |

Docs look solid. One low-severity line-number staleness finding; no high or medium findings.
