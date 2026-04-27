#!/usr/bin/env bash
# What: Regenerate supabase.types.ts against the local Supabase stack and
#       fail if the committed file has drifted. Runs in the CI slow-job.
# Why: Keeps the hand-written `Database` type in lockstep with the actual DB
#       schema. Catches the drift class where a migration changes table
#       columns / FKs / RPC signatures without a paired regen of the types.
# Does NOT: Write to `packages/core/src/supabase.types.ts`; writes to a tmp
#       file + diffs. Run `supabase gen types typescript --local >
#       packages/core/src/supabase.types.ts` manually if drift is detected
#       and the new schema is correct.
#
# Requires: `supabase start` already executed (local stack up on 127.0.0.1).
# Reads env: none (Supabase CLI reads its own local state from .supabase/).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKED_IN="${REPO_ROOT}/packages/core/src/supabase.types.ts"
TMP_RAW="$(mktemp -t supabase-types-raw-XXXXXX.ts)"
TMP_OUT="$(mktemp -t supabase-types-fmt-XXXXXX.ts)"
trap 'rm -f "$TMP_RAW" "$TMP_OUT"' EXIT

if [ ! -f "$CHECKED_IN" ]; then
  echo "ERROR: $CHECKED_IN is missing — cannot diff." >&2
  exit 1
fi

echo "Regenerating supabase.types.ts from the local Supabase stack..."
supabase gen types typescript --local >"$TMP_RAW"

# Prettier-normalize the regenerated output so the diff only catches
# SEMANTIC drift (new/removed tables, columns, FKs, RPC signatures) and
# not cosmetic differences between `supabase gen`'s raw output (double
# quotes, no trailing semicolons) and the committed file (which the
# pre-commit hook prettier-formats to the repo style).
cd "$REPO_ROOT"
# Pass --config explicitly: the tmp file lives in /tmp, so prettier's
# auto-resolution (which searches up from the formatted file's dir) can
# NOT find $REPO_ROOT/.prettierrc on its own. Without this, the tmp
# file gets prettier's default settings (double quotes), while the
# committed file carries repo style (single quotes) — producing a
# cosmetic-only diff that looks like drift.
pnpm exec prettier --config "$REPO_ROOT/.prettierrc" --parser typescript "$TMP_RAW" >"$TMP_OUT"

if ! diff -u "$CHECKED_IN" "$TMP_OUT"; then
  # Print the regenerated file verbatim so it can be recovered from CI
  # logs when the local devcontainer can't run `supabase start` (DiD
  # inert). Delimiters make log-extraction mechanical.
  echo ""
  echo "===CI_TYPE_DRIFT_REGENERATED_BEGIN==="
  cat "$TMP_OUT"
  echo "===CI_TYPE_DRIFT_REGENERATED_END==="
  echo ""
  cat >&2 <<'DRIFT_EOF'

ERROR: packages/core/src/supabase.types.ts has drifted from the DB schema.

The committed types no longer match what `supabase gen types typescript
--local` produces. A migration likely changed table columns, FKs, or
RPC signatures without regenerating the types.

Fix:

  supabase gen types typescript --local > packages/core/src/supabase.types.ts

Then re-run the failing CI. (Alternatively, extract the regenerated
content from this log between the ===CI_TYPE_DRIFT_REGENERATED_BEGIN===
and ===CI_TYPE_DRIFT_REGENERATED_END=== markers above, write to the
tracked path, commit, and push.)
DRIFT_EOF
  exit 1
fi

echo "OK: supabase.types.ts matches the local DB schema."
