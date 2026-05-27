# Tasks: claude-md-hygiene

## Task 1: Hook script + check-type + trailer + bats tests
**Status:** done
**Commit:** 2c9311a
**Files:** `kit/scripts/commit-hooks/check-claude-md-classification.sh` (create), `kit/scripts/adversarial-review.sh` (modify), `kit/scripts/commit-hooks/append-bypass-trailers.sh` (modify), `kit/tests/guard-claude-md-classification.bats` (create)
**Tests:** 10/10 pass

## Task 2: Wire into pre-commit.sh
**Status:** done
**Commit:** 267fff6
**Files:** `kit/hooks/pre-commit.sh` (modify)
**Notes:** Added to all three dispatch paths (devshop-self, /workspace, /devshop)

## Task 3: Audit sweep of devshop CLAUDE.md
**Status:** done
**Commit:** 07ed9d6
**Files:** `CLAUDE.md` (modify)
**Changes:**
- Deleted stale `docsReviewed` footgun entry (check-type removed in PR-C)
- Deleted `/ak-pre-ship` Dismissals convention entry (already in hooks.md + SKILL.md)
- Condensed adversarial Layer 2 entry to one-liner with pointer
- Condensed `localTestSkipReason` entry to one-liner with pointer

## Task 4: Convention doc update
**Status:** done
**Commit:** 8956e75
**Files:** `kit/docs/guide/claude-md.md` (modify), `kit/docs/guide/hooks.md` (modify)
**Changes:**
- claude-md.md: rewrote Enforcement from two-layer to three-layer; added Layer B section; updated Q6 rationale; updated bypass mechanism section
- hooks.md: added guard table row, commit-flow diagram entry, bypass-flag inventory, model-routing table, prepare-commit-msg trailer list

## Additional: Router test fix
**Commit:** 924948d
**Files:** `kit/tests/pre-commit-router.bats` (modify)
**Notes:** Added mock stub + assertions for the new script in all routing tests
