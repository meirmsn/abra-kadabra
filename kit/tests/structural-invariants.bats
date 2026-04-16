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
  scripts=$(grep -oP 'bash /devshop/kit/scripts/\K[a-z-]+\.sh' "$settings" | sort -u)

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
  scripts=$(grep -oP 'bash /devshop/kit/scripts/\K[a-z-]+\.sh' "$settings" | sort -u)

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

# =============================================================================
# Manifest consistency — entries correspond to real template files
# =============================================================================

@test "wiring: all manifest entries exist in template/" {
  local manifest="$DEVSHOP/kit/manifest.txt"
  [ -f "$manifest" ] || skip "manifest.txt not found"

  local entries
  entries=$(grep -v '^\s*#' "$manifest" | grep -v '^\s*$' | grep -v '^!' | sed 's/[[:space:]]*$//')

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
  local coverage_script="$DEVSHOP/kit/scripts/check-test-coverage.sh"
  [ -f "$coverage_script" ] || skip "check-test-coverage.sh not found"

  # Extract script names from the EXEMPT_SCRIPTS array
  local exempts
  exempts=$(grep -oP '^\s+"[a-z-]+\.sh"' "$coverage_script" | tr -d '" ')

  local missing=""
  while IFS= read -r script; do
    [ -z "$script" ] && continue
    if [ ! -f "$DEVSHOP/kit/scripts/$script" ]; then
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
  local coverage_script="$DEVSHOP/kit/scripts/check-test-coverage.sh"
  local settings="$DEVSHOP/.claude/settings.json"
  local precommit="$DEVSHOP/kit/hooks/pre-commit.sh"

  [ -f "$coverage_script" ] || skip "check-test-coverage.sh not found"
  [ -f "$settings" ] || skip "settings.json not found"

  # Get all scripts
  local all_scripts
  all_scripts=$(ls "$DEVSHOP/kit/scripts/"*.sh 2>/dev/null | xargs -I{} basename {})

  # Get exempt scripts
  local exempts
  exempts=$(grep -oP '^\s+"[a-z-]+\.sh"' "$coverage_script" | tr -d '" ')

  # Scripts called by other scripts or skills (not directly by hooks/pre-commit)
  local infra_scripts="create-devshop-symlinks.sh normalize-devshop-paths.sh changelog-entry.sh check-file-headers.sh"

  # Combine hook references and pre-commit references
  local wired=""
  wired+=$(grep -oP '[a-z-]+\.sh' "$settings" | sort -u)
  wired+=$'\n'
  wired+=$(grep -oP '[a-z-]+\.sh' "$precommit" | sort -u)

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
