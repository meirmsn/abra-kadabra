#!/usr/bin/env bats
# Structural invariant tests — verify the devshop's configuration is self-consistent.
# These don't test script behavior (that's what guard-*.bats does). They test that
# the devshop's wiring, file structure, and cross-references haven't silently broken.
#
# Run on every commit to catch: stale hook paths, broken symlinks, manifest drift,
# template corruption, version/tag misalignment.

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
}

# =============================================================================
# Hook wiring — every script path in settings.json exists
# =============================================================================

@test "wiring: settings.json hook scripts exist" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"

  # Extract all "bash /devshop/kit/scripts/*.sh" references from hook commands
  local scripts
  scripts=$(grep -oP 'bash /devshop/kit/scripts/\K[a-z/-]+\.sh' "$settings" | sort -u)

  local missing=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    if [ ! -f "$DEVSHOP/kit/scripts/$script" ]; then
      missing+="  $script\n"
    fi
  done <<< "$scripts"

  if [ -n "$missing" ]; then
    echo "settings.json references scripts that don't exist:"
    echo -e "$missing"
    false
  fi
}

@test "wiring: settings.json hook scripts are executable" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"

  local scripts
  scripts=$(grep -oP 'bash /devshop/kit/scripts/\K[a-z/-]+\.sh' "$settings" | sort -u)

  local failures=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    local path="$DEVSHOP/kit/scripts/$script"
    if [ -f "$path" ] && [ ! -x "$path" ]; then
      failures+="  $script (not executable)\n"
    fi
  done <<< "$scripts"

  # Shell scripts run via `bash script.sh` don't need +x, but check anyway
  # for consistency with direct execution
  [ -z "$failures" ] || { echo -e "Non-executable hook scripts:\n$failures"; true; }
}

@test "wiring: statusline script exists" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"

  local statusline_script
  statusline_script=$(grep -oP '"command":\s*"bash \K[^"]+' "$settings" | head -1)
  [ -f "$statusline_script" ]
}

# =============================================================================
# Symlink integrity — all skill symlinks resolve
# =============================================================================

@test "wiring: all skill symlinks resolve to existing targets" {
  local skills_dir="$DEVSHOP/.claude/skills"
  [ -d "$skills_dir" ] || skip "skills directory not found"

  local broken=""
  for link in "$skills_dir"/*; do
    [ -L "$link" ] || continue
    if [ ! -e "$link" ]; then
      broken+="  $(basename "$link") → $(readlink "$link")\n"
    fi
  done

  if [ -n "$broken" ]; then
    echo "Broken skill symlinks:"
    echo -e "$broken"
    false
  fi
}

@test "wiring: .hooks/pre-commit symlink chain resolves" {
  # The chain: .husky/pre-commit (script) → calls .hooks/pre-commit → symlink to kit/hooks/pre-commit.sh
  [ -f "$DEVSHOP/.husky/pre-commit" ] || skip ".husky/pre-commit not found"
  [ -L "$DEVSHOP/.hooks/pre-commit" ] || skip ".hooks/pre-commit not a symlink"
  # Verify the symlink target exists
  [ -e "$DEVSHOP/.hooks/pre-commit" ]
}

@test "wiring: template/.husky/pre-push exists and is executable" {
  # New projects inherit pre-push from the template via rsync at /ak-new-project time.
  # Project pre-push is the load-bearing layer for: no-direct-push-to-main + PR-desc + dirty-push.
  local hook="$DEVSHOP/template/.husky/pre-push"
  [ -f "$hook" ]
  [ -x "$hook" ]
  # Sanity: the no-bypass main-block lives in the project hook, not devshop's.
  grep -q "BLOCKED: direct push to" "$hook"
  grep -q "No bypass available" "$hook"
}

@test "wiring: devshop /.husky/pre-push does NOT contain PR-desc check (devshop has no PRs)" {
  # Devshop releases push direct to main with tags — no PRs exist for the
  # PR-desc check to fire on. The check moved to template/.husky/pre-push.
  local hook="$DEVSHOP/.husky/pre-push"
  [ -f "$hook" ]
  ! grep -q "prDescStaleReason" "$hook"
  ! grep -q "PR description staleness" "$hook"
}

# =============================================================================
# Manifest consistency — entries correspond to real template files
# =============================================================================

@test "wiring: all manifest entries exist in template/" {
  local manifest="$DEVSHOP/kit/manifest.txt"
  [ -f "$manifest" ] || skip "manifest.txt not found"

  local entries
  entries=$(grep -v '^\s*#' "$manifest" | grep -v '^\s*$' | grep -v '^!' | sed 's/\[[^]]*\]//g; s/[[:space:]]*$//')

  local missing=""
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [ ! -e "$DEVSHOP/template/$entry" ]; then
      missing+="  $entry\n"
    fi
  done <<< "$entries"

  if [ -n "$missing" ]; then
    echo "Manifest entries not found in template/:"
    echo -e "$missing"
    false
  fi
}

# =============================================================================
# Exempt list freshness — every exempt script actually exists
# =============================================================================

@test "wiring: check-test-coverage exempt scripts all exist" {
  local coverage_script="$DEVSHOP/kit/scripts/commit-hooks/check-test-coverage.sh"
  [ -f "$coverage_script" ] || skip "check-test-coverage.sh not found"

  # Extract script names from the EXEMPT_SCRIPTS array
  local exempts
  exempts=$(grep -oP '^\s+"[a-z-]+\.sh"' "$coverage_script" | tr -d '" ')

  # Exempt entries are basenames (check-test-coverage.sh matches via basename).
  # Scripts may live at root or in a subfolder (preship/, commit-hooks/, sync/,
  # notify/) — find the basename anywhere under kit/scripts/.
  local missing=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    if [ -z "$(find "$DEVSHOP/kit/scripts/" -type f -name "$script" -print -quit 2>/dev/null)" ]; then
      missing+="  $script (exempt but doesn't exist)\n"
    fi
  done <<< "$exempts"

  if [ -n "$missing" ]; then
    echo "Exempt scripts that don't exist:"
    echo -e "$missing"
    false
  fi
}

# =============================================================================
# Guard registration — every non-exempt script is wired into a hook or chain
# =============================================================================

@test "wiring: every non-exempt kit script is wired into a hook or pre-commit" {
  local coverage_script="$DEVSHOP/kit/scripts/commit-hooks/check-test-coverage.sh"
  local settings="$DEVSHOP/.claude/settings.json"
  local precommit="$DEVSHOP/kit/hooks/pre-commit.sh"

  [ -f "$coverage_script" ] || skip "check-test-coverage.sh not found"
  [ -f "$settings" ] || skip "settings.json not found"

  # Get all scripts (recursive — covers root + preship/, commit-hooks/, sync/)
  local all_scripts
  all_scripts=$(find "$DEVSHOP/kit/scripts/" -type f -name '*.sh' -print0 2>/dev/null | xargs -0 -I{} basename {})

  # Get exempt scripts
  local exempts
  exempts=$(grep -oP '^\s+"[a-z-]+\.sh"' "$coverage_script" | tr -d '" ')

  # Scripts called by other scripts or skills (not directly by hooks/pre-commit)
  local infra_scripts="create-devshop-symlinks.sh normalize-devshop-paths.sh changelog-entry.sh check-file-headers.sh supabase-bootstrap.sh router-shim.sh verify-story.sh design-conformance.sh rls-coverage-check.sh slow-job-lifecycle-check.sh rebuild-browse.sh populate-playwright-cache.sh parse-manifest.sh"

  # Combine hook references and pre-commit references (match paths-with-slashes)
  local wired=""
  wired+=$(grep -oP '[a-z/-]+\.sh' "$settings" | xargs -I{} basename {} | sort -u)
  wired+=$'\n'
  wired+=$(grep -oP '[a-z/-]+\.sh' "$precommit" | xargs -I{} basename {} | sort -u)

  local unwired=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    # Skip exempt scripts
    echo "$exempts" | grep -q "^${script}$" && continue
    # Skip infrastructure scripts (called by other scripts)
    echo "$infra_scripts" | grep -q "$script" && continue
    # Check if wired
    if ! echo "$wired" | grep -q "^${script}$"; then
      unwired+="  $script\n"
    fi
  done <<< "$all_scripts"

  if [ -n "$unwired" ]; then
    echo "Scripts not wired into any hook or pre-commit chain:"
    echo -e "$unwired"
    echo "Either wire them in, add to exempt list, or add to infra_scripts in this test."
    false
  fi
}

# =============================================================================
# Version / tag alignment
# =============================================================================

@test "wiring: kit/version matches latest git tag" {
  local version_file="$DEVSHOP/kit/version"
  [ -f "$version_file" ] || skip "version file not found"

  # During a release commit, version is bumped before the tag is created.
  # Skip if kit/version is staged (release in progress).
  git -C "$DEVSHOP" diff --cached --name-only | grep -q '^kit/version$' && skip "version bump in progress (release commit)"

  local file_version
  file_version=$(cat "$version_file" | tr -d '[:space:]')

  local latest_tag
  latest_tag=$(git -C "$DEVSHOP" tag -l 'v*' --sort=-v:refname | head -1 | sed 's/^v//')

  [ -n "$latest_tag" ] || skip "no version tags found"
  assert_equal "$file_version" "$latest_tag"
}

# =============================================================================
# Template file validity — config files are parseable
# =============================================================================

@test "wiring: template package.json is valid JSON" {
  local pkg="$DEVSHOP/template/package.json"
  [ -f "$pkg" ] || skip "template package.json not found"
  run jq empty "$pkg"
  assert_success
}

@test "wiring: template turbo.json is valid JSON" {
  local turbo="$DEVSHOP/template/turbo.json"
  [ -f "$turbo" ] || skip "template turbo.json not found"
  run jq empty "$turbo"
  assert_success
}

@test "wiring: template tsconfig.base.json is valid JSON" {
  local tsconfig="$DEVSHOP/template/tsconfig.base.json"
  [ -f "$tsconfig" ] || skip "template tsconfig.base.json not found"
  run jq empty "$tsconfig"
  assert_success
}

@test "wiring: template devcontainer.json is valid JSON" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  # devcontainer.json often has comments (JSONC) — strip them before parsing
  run bash -c "sed 's|//.*||' '$dc' | jq empty"
  assert_success
}

@test "wiring: devshop settings.json is valid JSON" {
  run jq empty "$DEVSHOP/.claude/settings.json"
  assert_success
}

# =============================================================================
# Pre-commit chain scripts exist
# =============================================================================

@test "wiring: all scripts called by pre-commit.sh exist" {
  local precommit="$DEVSHOP/kit/hooks/pre-commit.sh"
  [ -f "$precommit" ] || skip "pre-commit.sh not found"

  # Extract script names from bash "$SCRIPTS_DIR/xxx.sh" calls
  local scripts
  scripts=$(grep -oP 'bash "\$SCRIPTS_DIR/\K[^"]+' "$precommit")

  local missing=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    if [ ! -f "$DEVSHOP/kit/scripts/$script" ]; then
      missing+="  $script\n"
    fi
  done <<< "$scripts"

  if [ -n "$missing" ]; then
    echo "Pre-commit chain references missing scripts:"
    echo -e "$missing"
    false
  fi
}

# =============================================================================
# Husky pre-commit consistency — devshop and template match
# =============================================================================

# =============================================================================
# Template contracts — project template contains devshop requirements
# =============================================================================

@test "wiring: template .gitignore includes devshop-injected paths" {
  local gitignore="$DEVSHOP/template/.gitignore"
  [ -f "$gitignore" ] || skip "template .gitignore not found"

  # These paths are injected by init-devshop.sh / create-devshop-symlinks.sh.
  # If missing from .gitignore, they leak into project git history.
  local required=(
    ".devshopkit"
    ".claude/*"
    ".dcg.toml"
    ".hooks/"
  )

  local missing=""
  for pattern in "${required[@]}"; do
    if ! grep -qF "$pattern" "$gitignore"; then
      missing+="  $pattern\n"
    fi
  done

  if [ -n "$missing" ]; then
    echo "template/.gitignore is missing devshop-injected paths:"
    echo -e "$missing"
    echo "These will leak into project git history without gitignore entries."
    false
  fi
}

@test "wiring: template .gitignore preserves .claude/memory/ from ignore" {
  local gitignore="$DEVSHOP/template/.gitignore"
  [ -f "$gitignore" ] || skip "template .gitignore not found"

  # .claude/* ignores everything, but memory files must be tracked.
  # !.claude/memory/ re-includes them.
  grep -qF '!.claude/memory/' "$gitignore"
}

@test "wiring: template package.json has husky in devDependencies" {
  local pkg="$DEVSHOP/template/package.json"
  [ -f "$pkg" ] || skip "template package.json not found"
  run jq -e '.devDependencies.husky' "$pkg"
  assert_success
}

@test "wiring: template package.json has lint-staged in devDependencies" {
  local pkg="$DEVSHOP/template/package.json"
  [ -f "$pkg" ] || skip "template package.json not found"
  run jq -e '.devDependencies["lint-staged"]' "$pkg"
  assert_success
}

@test "wiring: template package.json has prepare script for husky" {
  local pkg="$DEVSHOP/template/package.json"
  [ -f "$pkg" ] || skip "template package.json not found"
  local prepare
  prepare=$(jq -r '.scripts.prepare' "$pkg")
  assert_equal "$prepare" "husky"
}

@test "wiring: template package.json has lint-staged config" {
  local pkg="$DEVSHOP/template/package.json"
  [ -f "$pkg" ] || skip "template package.json not found"
  run jq -e '.["lint-staged"]' "$pkg"
  assert_success
}

# =============================================================================
# Normalization pipeline — settings.json survives the copy transform
# =============================================================================

@test "wiring: normalized settings.json is valid JSON" {
  local src="$DEVSHOP/.claude/settings.json"
  [ -f "$src" ] || skip "source settings.json not found"
  run bash -c "bash '$DEVSHOP/kit/scripts/sync/normalize-devshop-paths.sh' < '$src' | jq empty"
  assert_success
}

@test "wiring: normalized settings.json hook paths all resolve" {
  local src="$DEVSHOP/.claude/settings.json"
  [ -f "$src" ] || skip "source settings.json not found"

  local paths
  paths=$(bash "$DEVSHOP/kit/scripts/sync/normalize-devshop-paths.sh" < "$src" | grep -oP 'bash \K[^ "]+\.sh')

  local missing=""
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ ! -f "$path" ]; then
      missing+="  $path\n"
    fi
  done <<< "$paths"

  if [ -n "$missing" ]; then
    echo "Normalized settings.json references scripts that don't exist:"
    echo -e "$missing"
    false
  fi
}

# =============================================================================
# DCG configuration
# =============================================================================

@test "wiring: .dcg.toml exists and is parseable" {
  local dcg="$DEVSHOP/.dcg.toml"
  [ -f "$dcg" ] || skip ".dcg.toml not found"
  # Basic TOML validation: no syntax errors on section headers and key-value pairs
  # Full TOML parser not available, but we can check structure
  run bash -c "grep -cE '^\[|^[a-z]' '$dcg'"
  assert_success
  # Must have at least a [packs] section
  run grep -q '^\[packs\]' "$dcg"
  assert_success
}

# =============================================================================
# Container wiring — devcontainer.json calls init-devshop.sh
# =============================================================================

@test "wiring: template devcontainer.json calls init-devshop.sh on start" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q 'init-devshop.sh' "$dc"
  assert_success
}

@test "wiring: template devcontainer.json calls init-firewall.sh on start" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q 'init-firewall.sh' "$dc"
  assert_success
}

@test "wiring: template devcontainer.json mounts devshop at /devshop" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q 'target=/devshop' "$dc"
  assert_success
}

@test "wiring: template devcontainer.json sets workspace to /workspace" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q '"workspaceFolder": "/workspace"' "$dc"
  assert_success
}

@test "wiring: template devcontainer.json runs pnpm install in postCreateCommand" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q '"postCreateCommand":.*pnpm install' "$dc"
  assert_success
}

@test "wiring: devshop devcontainer.json runs pnpm install in postCreateCommand" {
  local dc="$DEVSHOP/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "devshop devcontainer.json not found"
  run grep -q '"postCreateCommand":.*pnpm install' "$dc"
  assert_success
}

@test "wiring: template init-firewall.sh allows ntfy.sh" {
  local f="$DEVSHOP/template/.devcontainer/init-firewall.sh"
  [ -f "$f" ] || skip "template init-firewall.sh not found"
  run grep -qE '^\s*"ntfy\.sh"\s*\\' "$f"
  assert_success
}

@test "wiring: devshop init-firewall.sh allows ntfy.sh" {
  local f="$DEVSHOP/.devcontainer/init-firewall.sh"
  [ -f "$f" ] || skip "devshop init-firewall.sh not found"
  run grep -qE '^\s*"ntfy\.sh"\s*\\' "$f"
  assert_success
}

# =============================================================================
# Telemetry opt-outs — env vars in containerEnv for rebuild resilience
# (the state files live under ~/.config/ which is not volume-mounted, so
# one-time CLI disable commands don't survive devcontainer rebuilds)
# =============================================================================

@test "wiring: template devcontainer.json disables turbo telemetry" {
  local dc="$DEVSHOP/template/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "template devcontainer.json not found"
  run grep -q '"TURBO_TELEMETRY_DISABLED": "1"' "$dc"
  assert_success
}

@test "wiring: devshop devcontainer.json disables turbo telemetry" {
  local dc="$DEVSHOP/.devcontainer/devcontainer.json"
  [ -f "$dc" ] || skip "devshop devcontainer.json not found"
  run grep -q '"TURBO_TELEMETRY_DISABLED": "1"' "$dc"
  assert_success
}

# =============================================================================
# CI workflow validity
# =============================================================================

@test "wiring: template CI workflow is valid YAML" {
  local ci="$DEVSHOP/template/.github/workflows/ci.yml"
  [ -f "$ci" ] || skip "CI workflow not found"
  # yq or python yaml not guaranteed — validate structure with grep
  # Must have 'on:' trigger and 'jobs:' section
  run grep -q '^on:' "$ci"
  assert_success
  run grep -q '^jobs:' "$ci"
  assert_success
}

@test "wiring: template deploy-migrations workflow is valid YAML" {
  local mig="$DEVSHOP/template/.github/workflows/deploy-migrations.yml"
  [ -f "$mig" ] || skip "deploy-migrations workflow not found"
  run grep -q '^on:' "$mig"
  assert_success
  run grep -q '^jobs:' "$mig"
  assert_success
}

@test "wiring: template deploy-functions workflow is valid YAML" {
  local fns="$DEVSHOP/template/.github/workflows/deploy-functions.yml"
  [ -f "$fns" ] || skip "deploy-functions workflow not found"
  run grep -q '^on:' "$fns"
  assert_success
  run grep -q '^jobs:' "$fns"
  assert_success
}

# =============================================================================
# additionalDirectories — Claude can access devshop files
# =============================================================================

@test "wiring: settings.json has additionalDirectories for /devshop" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"
  local dirs
  dirs=$(jq -r '.permissions.additionalDirectories[]?' "$settings")
  echo "$dirs" | grep -qF '/devshop'
}

# =============================================================================
# Script mode consistency — all kit/scripts tracked as 644
# =============================================================================

@test "wiring: all kit/scripts/*.sh tracked as 644 (not 755)" {
  local wrong_mode=""
  while IFS= read -r line; do
    local mode file
    mode=$(echo "$line" | awk '{print $1}')
    file=$(echo "$line" | awk '{print $4}')
    if [ "$mode" != "100644" ]; then
      wrong_mode+="  $file (tracked as $mode, should be 100644)\n"
    fi
  done < <(git -C "$DEVSHOP" ls-files -s 'kit/scripts/**/*.sh' 'kit/scripts/*.sh')

  if [ -n "$wrong_mode" ]; then
    echo "Scripts tracked with wrong mode (init-devshop.sh locks all to 644):"
    echo -e "$wrong_mode"
    echo "Fix: git add --chmod=-x <file>"
    false
  fi
}

# =============================================================================
# BATS submodules initialized
# =============================================================================

@test "wiring: BATS submodules are initialized" {
  [ -x "$DEVSHOP/kit/tests/lib/bats-core/bin/bats" ] || {
    echo "BATS not initialized. Run: git submodule update --init --recursive"
    false
  }
}

# =============================================================================
# Security deny rules — symmetric coverage across both repos
# (settings.json is cwd-relative for globs, so absolute-path denies are needed
# to protect the OTHER repo's files when working from this repo's cwd)
# =============================================================================

@test "wiring: settings.json denies reads of both repos' .env files" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"
  local denies
  denies=$(jq -r '.permissions.deny[]?' "$settings")
  echo "$denies" | grep -qF 'Read(/devshop/.devcontainer/.env)' || {
    echo "Missing: Read(/devshop/.devcontainer/.env)"
    false
  }
  echo "$denies" | grep -qF 'Read(/workspace/.devcontainer/.env)' || {
    echo "Missing: Read(/workspace/.devcontainer/.env)"
    false
  }
}

# =============================================================================
# Filesystem hardening — init-devshop.sh applies sticky bits to security dirs
# (sticky bit is what keeps chown root:root effective against node's ability
# to unlink files from a node-owned directory and recreate them node-owned)
# =============================================================================

@test "wiring: init-devshop.sh applies sticky bits to all security dirs" {
  local script="$DEVSHOP/kit/scripts/init-devshop.sh"
  local manifest="$DEVSHOP/kit/manifest.txt"
  [ -f "$script" ] || skip "init-devshop.sh not found"
  [ -f "$manifest" ] || skip "manifest.txt not found"

  # Workspace sticky-bit dirs split into two sources:
  #   1. Manifest-driven [locked-dir] entries (project-workspace lifecycle):
  #      currently .devcontainer and .husky.
  #   2. Hardcoded fallback in init-devshop.sh (project-special + devshop-self):
  #      .claude (workspace, contains symlinks not in template/), plus all
  #      $DEVSHOP/... and $DEVSHOP/template/... dirs (devshop-bootstrap).
  local manifest_dirs hardcoded_dirs missing=""

  # Source the parser and read [locked-dir] entries
  source "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"
  parse_manifest "$manifest"
  manifest_dirs=$(manifest_paths_by locked-dir)
  for d in $manifest_dirs; do
    case "$d" in
      .devcontainer|.husky) ;;
      *)
        echo "Unexpected [locked-dir] entry: $d (test asserts known set)"
        false ;;
    esac
  done
  for required in .devcontainer .husky; do
    echo "$manifest_dirs" | grep -qx "$required" || missing+="  $required (manifest [locked-dir])\n"
  done

  # Hardcoded dirs still expected as literal strings in init-devshop.sh
  for d in \
    '$WS/.claude' \
    '$DEVSHOP/.claude' \
    '$DEVSHOP/.devcontainer' \
    '$DEVSHOP/.husky' \
    '$DEVSHOP/template/.devcontainer' \
    '$DEVSHOP/template/.husky' \
    ; do
    grep -qF "\"$d\"" "$script" || missing+="  $d (hardcoded literal)\n"
  done

  if [ -n "$missing" ]; then
    echo "init-devshop.sh missing sticky-bit coverage for:"
    echo -e "$missing"
    echo "Expected: [locked-dir] entries in manifest for workspace dirs +"
    echo "          chmod 1755 loop covering devshop-self and project-special dirs"
    false
  fi
  # Verify the chmod 1755 call actually appears in the script
  run grep -q 'chmod 1755' "$script"
  assert_success
}
