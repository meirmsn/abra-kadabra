# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (1 commit: `9f8217e`)
**Date**: 2026-05-26

## Section A — Coverage of new behavior

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/sync-package-json-merge.bats` (missing test)
**What**: The file header (line 7) claims "Missing jq falls back to raw copy (no crash)" is validated, but no test exercises the `! command -v jq` fallback branch in `merge_package_json()` (`kit/scripts/sync/from-devshop.sh:72`). The function falls back to `cp "$template" "$output"` when jq is unavailable — this path is untested.
**Why**: If the fallback branch regresses (e.g., someone adds jq-dependent logic before the guard), projects without jq installed would get a crash on sync instead of a graceful raw-copy fallback. The header's claim creates false confidence that this path is covered.
**Fix**: Add a test that temporarily hides jq from `$PATH` (e.g., `PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(which jq)")" | tr '\n' ':')`) before invoking the sync, then asserts the project gets the template's package.json verbatim (name = `"project-name"`). Alternatively, remove the claim from the header if the path is intentionally untested.

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-ci-yml-shape.bats:405`
**What**: The regression guard regex `\-\-filter[= ]apps/web[^/]` requires a trailing non-`/` character after `apps/web`. If the bare form `--filter=apps/web` appears at end of line (no trailing character), `[^/]` has nothing to match and the guard silently passes.
**Why**: The companion test at line 389-399 already catches this case (it asserts zero matches of bare `--filter[= ]apps/web`), so actual coverage is not lost. But the regression guard's comment says it "forbids the bare form" — the regex is weaker than the intent, which could mislead a future editor into relying on this test alone.
**Fix**: Change the regex to `\-\-filter[= ]apps/web($|[^/])` to also match end-of-line, or simplify to `\-\-filter[= ]apps/web[[:space:]]` since in practice the bare form would be followed by whitespace or EOL.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the range. Nothing to audit.

## Summary

- **high**: 0
- **medium**: 1 (missing jq-fallback test despite header claim)
- **low**: 1 (regression guard regex gap, mitigated by companion test)
