#!/usr/bin/env bats
# Content-validation tests for .claude/skills/devshop/build/devshop-mode.md —
# the sub-file that carries devshop-specific phases for /ak-build.
#
# These tests pin structural invariants of the devshop-mode sub-file so
# future edits don't silently break the orchestrator's devshop-mode dispatch.
# Pattern follows util-ak-build-skill.bats (grep distinctive phrases).

setup() {
  load helpers/setup
  DEVSHOP_MODE_FILE="$TESTS_DIR/../../.claude/skills/devshop/build/devshop-mode.md"
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/build/SKILL.md"
  PRESHIP_SKILL="$TESTS_DIR/../../.claude/skills/devshop/pre-ship/SKILL.md"
}

# === File presence ===

@test "devshop-mode.md exists at the expected path" {
  [ -f "$DEVSHOP_MODE_FILE" ]
}

# === Mode detection in SKILL.md ===

@test "SKILL.md contains mode detection block with GIT_ROOT check" {
  grep -q 'GIT_ROOT=\$(git rev-parse --show-toplevel)' "$SKILL_FILE"
}

@test "SKILL.md sets MODE=devshop when GIT_ROOT is /devshop" {
  grep -q 'MODE="devshop"' "$SKILL_FILE"
}

@test "SKILL.md sets MODE=project as the default" {
  grep -q 'MODE="project"' "$SKILL_FILE"
}

@test "SKILL.md mode detection is worktree-aware via --git-common-dir" {
  # A linked worktree of /devshop has its own --show-toplevel (the worktree
  # path), so the bare GIT_ROOT check alone would mis-detect it as project
  # mode. The fix ORs in a --git-common-dir == /devshop/.git check. Assert
  # both the common-dir read AND the /devshop/.git comparison are present.
  grep -q 'git rev-parse --git-common-dir' "$SKILL_FILE"
  grep -q '/devshop/.git' "$SKILL_FILE"
}

@test "SKILL.md mode detection absolutizes a relative common-dir" {
  # From the main worktree, --git-common-dir returns the relative ".git";
  # the fix must absolutize it (prefix GIT_ROOT) before comparing, or the
  # main-checkout case silently falls through to project mode.
  grep -q 'GIT_COMMON="\$GIT_ROOT/\$GIT_COMMON"' "$SKILL_FILE"
}

@test "SKILL.md references devshop-mode.md at Phase 3 routing" {
  grep -q 'devshop-mode.md.*Phase 3' "$SKILL_FILE"
}

@test "SKILL.md references devshop-mode.md at Phase 4 mode fork" {
  grep -q 'devshop-mode.md.*Phase 4\.5' "$SKILL_FILE"
}

# === Gate applicability matrix ===

@test "devshop-mode.md contains gate applicability matrix" {
  grep -q '### Gate applicability matrix' "$DEVSHOP_MODE_FILE"
}

@test "gate applicability matrix has 19 gate rows" {
  count=$(awk '/### Gate applicability matrix/{f=1; next} f && /^## /{exit} f' \
    "$DEVSHOP_MODE_FILE" | grep -cE '^\| [0-9]' || echo 0)
  [ "$count" -eq 19 ]
}

@test "gate matrix dispatches exactly 6 gates" {
  count=$(grep -c '\*\*dispatch' "$DEVSHOP_MODE_FILE")
  [ "$count" -eq 6 ]
}

@test "gate matrix summary line says 6 dispatched and 13 carve-outs" {
  grep -q '6 gates dispatched.*13 gates pre-composed carve-outs' "$DEVSHOP_MODE_FILE"
}

@test "LLM-mediated gate 7 (/cso) uses blocked not bare n/a" {
  grep -E '^\| 7 ' "$DEVSHOP_MODE_FILE" | grep -q 'blocked'
}

@test "LLM-mediated gate 8 (/design-review) uses blocked not bare n/a" {
  grep -E '^\| 8 ' "$DEVSHOP_MODE_FILE" | head -1 | grep -q 'blocked'
}

@test "LLM-mediated gate 9 (/qa) uses blocked not bare n/a" {
  grep -E '^\| 9 ' "$DEVSHOP_MODE_FILE" | grep -q 'blocked'
}

@test "LLM-mediated gate 10 (/benchmark) uses blocked not bare n/a" {
  grep -E '^\| 10 ' "$DEVSHOP_MODE_FILE" | head -1 | grep -q 'blocked'
}

@test "pre-composed carve-out sinks include all 4 LLM-mediated blocked templates" {
  count=$(grep -c 'blocked (n/a per scope: devshop-self-mode' "$DEVSHOP_MODE_FILE")
  # 4 actual sink templates + 1 prose reference in the advance-log section
  [ "$count" -ge 4 ]
}

# === Gate names match pre-ship canonical table ===

@test "every dispatched gate name in devshop-mode.md exists in pre-ship § Gates table" {
  CANONICAL=$(awk '
    /^\| --- /     { in_table=1; next }
    in_table && /^\|/ {
      n=split($0, f, "|"); if (n < 4) next
      name=f[3]; gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/`/, "", name)
      print name
    }
    in_table && /^[^|]/ { in_table=0 }
  ' "$PRESHIP_SKILL")

  DISPATCHED=$(awk '/### Gate applicability matrix/,/^### Pre-composed/' "$DEVSHOP_MODE_FILE" \
    | grep '\*\*dispatch' \
    | awk -F'|' '{gsub(/`/,"",$3); gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')

  [ -n "$DISPATCHED" ]

  ORPHANS=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    clean=$(echo "$name" | sed 's|^/||')
    if ! echo "$CANONICAL" | grep -qFx "$clean"; then
      ORPHANS="$ORPHANS $clean"
    fi
  done <<< "$DISPATCHED"

  if [ -n "$ORPHANS" ]; then
    echo "Orphan gate names in devshop-mode.md not found in pre-ship § Gates:"
    echo "  $ORPHANS"
    return 1
  fi
}

@test "every carve-out gate name in devshop-mode.md exists in pre-ship § Gates table" {
  CANONICAL=$(awk '
    /^\| --- /     { in_table=1; next }
    in_table && /^\|/ {
      n=split($0, f, "|"); if (n < 4) next
      name=f[3]; gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/`/, "", name)
      print name
    }
    in_table && /^[^|]/ { in_table=0 }
  ' "$PRESHIP_SKILL")

  CARVEOUTS=$(awk '/### Gate applicability matrix/,/^### Pre-composed/' "$DEVSHOP_MODE_FILE" \
    | grep -E '`n/a`|`blocked' \
    | awk -F'|' '{gsub(/`/,"",$3); gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')

  [ -n "$CARVEOUTS" ]

  ORPHANS=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    clean=$(echo "$name" | sed 's|^/||')
    if ! echo "$CANONICAL" | grep -qFx "$clean"; then
      ORPHANS="$ORPHANS $clean"
    fi
  done <<< "$CARVEOUTS"

  if [ -n "$ORPHANS" ]; then
    echo "Orphan carve-out gate names in devshop-mode.md not found in pre-ship § Gates:"
    echo "  $ORPHANS"
    return 1
  fi
}

# === Phase structure ===

@test "devshop-mode.md contains Phase 4.5 section" {
  grep -q '## Phase 4\.5: /ak-merge-devshop' "$DEVSHOP_MODE_FILE"
}

@test "devshop-mode.md contains terminal handoff section" {
  grep -q '## Terminal handoff' "$DEVSHOP_MODE_FILE"
}

@test "devshop-mode.md contains staleness check section" {
  grep -q '## Phase 0\.6: Staleness check' "$DEVSHOP_MODE_FILE"
}

@test "devshop-mode.md contains resume check adaptations" {
  grep -q '## Resume check adaptations' "$DEVSHOP_MODE_FILE"
}

# === Tracker hierarchy ===

@test "devshop tracker hierarchy includes Phase 4.0 and Phase 4.5" {
  grep -q 'Phase 4\.0: BUILD-LOG' "$DEVSHOP_MODE_FILE"
  grep -q 'Phase 4\.5: /ak-merge-devshop' "$DEVSHOP_MODE_FILE"
}

@test "devshop tracker hierarchy does NOT include Phase 5, 6, or 7" {
  TRACKER=$(awk '/### Tracker hierarchy/,/^##[^#]/' "$DEVSHOP_MODE_FILE")
  ! echo "$TRACKER" | grep -qE 'Phase [567]:'
}

# === Structural carve-out handling ===

@test "structural carve-outs bypass AskUserQuestion via STRUCTURAL stamp" {
  grep -q 'blockedGateOverride STRUCTURAL' "$DEVSHOP_MODE_FILE"
}

@test "advance condition excludes structural blocked from halt count" {
  grep -q 'real_blocked == 0' "$DEVSHOP_MODE_FILE"
}

# === Test checkpoints use bats ===

@test "devshop-mode test checkpoints reference bats" {
  grep -q 'bats kit/tests/' "$DEVSHOP_MODE_FILE"
}

# === Cross-reference consistency ===

@test "SKILL.md staleness check number matches devshop-mode.md" {
  SKILL_NUM=$(grep -oE '0\.[0-9]+: Staleness check' "$SKILL_FILE" | grep -oE '0\.[0-9]+')
  DEVSHOP_NUM=$(grep -oE 'Phase 0\.[0-9]+: Staleness check' "$DEVSHOP_MODE_FILE" | grep -oE '0\.[0-9]+')
  [ "$SKILL_NUM" = "$DEVSHOP_NUM" ]
}
