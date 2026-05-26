### [domain: docs] [section: A] [severity: medium]
**File**: kit/docs/guide/architecture.md:181
**What**: `from-devshop.sh` now does a jq merge for `package.json` (preserving project name/version/packageManager while syncing scripts/devDeps/pnpm from template), but no guide doc was updated to document this new merge-not-clobber exception.
**Why**: architecture.md:181 states "`from-devshop.sh` does plain `cp` for `[sync]` files (no merge)" — this is now factually incorrect for `package.json`. A future operator reading the architecture guide will assume all `[sync]` files are clobbered, then be surprised when `package.json` is merged. The new behavior is a meaningful sync-model change that belongs in the architecture doc's File Lifecycle section.
**Fix**: Add a paragraph after the `.gitignore` clobber-not-merge paragraph (architecture.md:181) documenting the `package.json` merge exception: jq-based merge preserves project identity fields (`name`, `version`, `packageManager`) while syncing structural fields (`scripts`, `devDependencies`, `pnpm`, `lint-staged`) from template. Note the jq-missing fallback (raw copy).

### [domain: docs] [section: A] [severity: medium]
**File**: kit/docs/guide/ops.md:71
**What**: `template/.github/workflows/ci.yml` changed to read API port dynamically from `supabase/config.toml` and to use `./apps/web` directory-based filter paths, but `ops.md` was not updated.
**Why**: ops.md:71 lists "Five battle-earned fixes baked into the canonical shape" for the slow-job. The dynamic-port derivation and directory-based `--filter` are two new battle-earned fixes of the same class (both prevent silent CI breakage after sync into port-offset or scoped-name projects). Missing from the list, a future refactor could strip them without realizing they are load-bearing.
**Fix**: Add two bullets to the "battle-earned fixes" list at ops.md:71: (1) dynamic API port from `config.toml` instead of hardcoded 54321 (port-offset projects); (2) `./apps/web` directory-based filter instead of bare `apps/web` (turbo rejects bare paths as package names).

### [domain: docs] [section: C] [severity: low]
**File**: kit/docs/guide/conventions.md:159
**What**: Stale filter path form `pnpm --filter apps/web test:e2e` — the template now uses `pnpm --filter ./apps/web` consistently.
**Why**: The template ci.yml was updated to use `./apps/web` for turbo compatibility. conventions.md:159 still references the bare `apps/web` form. For pnpm specifically the bare form still works (pnpm resolves directory paths), so this is an inconsistency rather than an error. A future reader may copy the bare form from the guide into a turbo context where it fails.
**Fix**: Update conventions.md:159 to `pnpm --filter ./apps/web test:e2e` to match the template's canonical shape.
