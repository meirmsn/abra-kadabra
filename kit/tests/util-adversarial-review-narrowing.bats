#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh narrowing (PR-C of the audit-time
# docs+tests migration — see kit/ROADMAP.md § PR-C § F).
#
# After PR-C, the case statement carries only bypass-reason check-types:
#   prTextHygieneReason, dirtyTreeReason, dirtyPushReason, manifestReviewed,
#   hookBypass, exemptAddition, dismissalLog
# Coverage-judging check-types moved to audit-time `/ak-check-docs-and-tests`:
#   docsReviewed, testCoverage, testCoverageProject, docsFreshnessProject
# Calling the script with one of those should fail with "unknown check type"
# rather than firing the old code path.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"

  # Mock `claude` to capture stdin and return PASS so any case that reaches
  # the LLM step does so cleanly (we don't want network calls in the test).
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
cat > "$CAPTURED_PROMPT"
echo "PASS - mocked"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  # Make the test repo look devshop-self by adding a real kit/ dir.
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"
}

# === Removed check-types: must fail with "unknown check type" ===

@test "removed: docsReviewed → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsReviewed "any reason"
  assert_failure
  assert_output --partial "unknown check type"
  assert_output --partial "docsReviewed"
}

@test "removed: testCoverage → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" testCoverage "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: testCoverageProject → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" testCoverageProject "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: docsFreshnessProject → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsFreshnessProject "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: bare 'unknown' / nonsense → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" madeUpCheck "x"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "fail message names the audit-time replacement" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsReviewed "x"
  assert_failure
  assert_output --partial "/ak-check-docs-and-tests"
}

# === Surviving check-types: still construct prompts and invoke claude ===
#
# These tests assert the script reaches the LLM step (mocked) and exits PASS,
# proving the case statement still recognizes the check-type. Detailed
# context-construction / prompt content is covered by the per-guard bats files
# that own each check-type's caller.

@test "surviving: dirtyTreeReason reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dirtyTreeReason "untracked debug.log from local testing"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dirtyTreeReason" "$CAPTURED_PROMPT"
}

@test "surviving: dirtyPushReason reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dirtyPushReason "stashed branch X to push hotfix Y"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dirtyPushReason" "$CAPTURED_PROMPT"
}

@test "surviving: manifestReviewed reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" manifestReviewed "added .husky/prepare-commit-msg as [locked] per template/.husky lifecycle"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: manifestReviewed" "$CAPTURED_PROMPT"
}

@test "surviving: hookBypass reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" hookBypass "binary lockfile breaks lint-staged; verified gitleaks pass via standalone scan"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: hookBypass" "$CAPTURED_PROMPT"
}

@test "surviving: exemptAddition reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" exemptAddition "apps/web/lib/util.ts  # transitively covered by api.test.ts"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: exemptAddition" "$CAPTURED_PROMPT"
}

@test "surviving: dismissalLog reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dismissalLog "- finding: xyz; rationale: deferred per spec § In scope" qa "$BATS_TEST_TMPDIR/missing-review.md"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dismissalLog" "$CAPTURED_PROMPT"
}

@test "surviving: prTextHygieneReason prompt carries all three dimensions (accuracy + title-readability + body-shape)" {
  # Pins the three-dimensional rule. Title-readability + body-shape were folded
  # into the check 2026-05-19 (kit/ROADMAP.md § Fold PR-title readability
  # check), at which point the flag was renamed from `prDescStaleReason` to
  # `prTextHygieneReason` to honestly reflect that the check covers accuracy
  # (description sync), title readability, AND body shape (Product update +
  # Engineering details). This test guards against accidental rule deletion.
  cd "$TEST_REPO"
  create_stub gh "" 0
  git -C "$TEST_REPO" checkout -b feature/test-pr-text -q 2>/dev/null || true
  run bash "$REVIEW" prTextHygieneReason "PR title + body genuinely match commits"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: prTextHygieneReason" "$CAPTURED_PROMPT"
  # (a) Description accuracy
  grep -q "Description accuracy" "$CAPTURED_PROMPT"
  # (b) Title readability
  grep -q "Title readability" "$CAPTURED_PROMPT"
  grep -q "observable change" "$CAPTURED_PROMPT"
  grep -q "72 chars" "$CAPTURED_PROMPT"
  # (c) Body structure
  grep -q "Body structure" "$CAPTURED_PROMPT"
  grep -q "## Product update" "$CAPTURED_PROMPT"
  grep -q "## Engineering details" "$CAPTURED_PROMPT"
}

@test "prTextHygieneReason squash-surface: reads from DEVSHOP_HYGIENE_MESSAGE_FILE + reaches claude" {
  # Verifies the squash surface short-circuits the gh pr view path and reads
  # subject (line 1) + body (lines 2+) from the tempfile. Drives the
  # /ak-merge-devshop Phase 0.4.5 integration — same reviewer engine, different
  # data source, selected via DEVSHOP_HYGIENE_SURFACE=squash.
  cd "$TEST_REPO"
  create_stub gh "" 0  # gh must not be reached on the squash path; stub it anyway
  git -C "$TEST_REPO" checkout -b feat/squash-surface-test -q 2>/dev/null || true

  MSG_FILE="$BATS_TEST_TMPDIR/squash-message.txt"
  cat > "$MSG_FILE" <<'EOF'
feat(squash): make commit subjects describe the observable change

**Adds:** a squash-time hygiene reviewer so subjects don't read like internal jargon.

Key details:
- reuses the same prTextHygieneReason engine as project pre-push
- skips rule (c) body structure because devshop squashes use bullets, not H2s

---

## Squashed commits

- `abc1234` test subject
  - test sub-bullet
EOF

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="$MSG_FILE" \
    DEVSHOP_HYGIENE_BRANCH="feat/squash-surface-test" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: prTextHygieneReason" "$CAPTURED_PROMPT"
  # CONTEXT identifies the surface
  grep -q "Devshop squash commit" "$CAPTURED_PROMPT"
  grep -q "feat/squash-surface-test" "$CAPTURED_PROMPT"
  # Subject + body both carried
  grep -q "feat(squash): make commit subjects describe the observable change" "$CAPTURED_PROMPT"
  grep -q "Adds:" "$CAPTURED_PROMPT"
  # NOTE 2 telling reviewer to skip rule (c) is inlined
  grep -q "SKIP rule (c) Body" "$CAPTURED_PROMPT"
  grep -q "bold-led-bullet" "$CAPTURED_PROMPT"
  # NOTE 1 telling reviewer this is a primary judgment, NOT a bypass review,
  # is inlined. Without this, the reviewer's default-REJECT-generic-reason
  # rule would FAIL clean titles whenever the caller (Phase 0.4.5) passes a
  # procedural marker like "auto-check at compose time" as the reason arg.
  grep -q "Primary judgment" "$CAPTURED_PROMPT"
  grep -q "operator has NOT supplied a bypass" "$CAPTURED_PROMPT"
  grep -q "procedural marker" "$CAPTURED_PROMPT"
  grep -q "Do NOT apply the generic" "$CAPTURED_PROMPT"
  # Rules (a) accuracy and (b) readability still apply
  grep -q "Description accuracy" "$CAPTURED_PROMPT"
  grep -q "Title readability" "$CAPTURED_PROMPT"
}

@test "prTextHygieneReason squash-surface: surfaces missing Existing-projects block when diff touches kit/scripts (dimension d)" {
  # When the squash diff touches a propagation surface (template/**, kit/scripts/**,
  # kit/hooks/**, .devcontainer/**, manifest.txt) the body MUST carry an
  # **Existing projects:** block, else release.sh's propagation-entry.sh silently
  # drops the change from PROPAGATION.md. The reviewer is handed the touched
  # surfaces + block-presence as data, plus NOTE 3 to judge dimension (d).
  cd "$TEST_REPO"
  create_stub gh "" 0
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD   # origin/main = initial commit
  git -C "$TEST_REPO" checkout -b feat/prop-surface -q 2>/dev/null || true
  mkdir -p "$TEST_REPO/kit/scripts"
  echo "echo hi" > "$TEST_REPO/kit/scripts/foo.sh"
  git -C "$TEST_REPO" add kit/scripts/foo.sh
  git -C "$TEST_REPO" commit -q -m "feat(scripts): add foo helper"

  MSG_FILE="$BATS_TEST_TMPDIR/squash-noblock.txt"
  cat > "$MSG_FILE" <<'EOF'
feat(scripts): add foo helper

**Adds:** a helper script. No Existing-projects block on purpose.
EOF

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="$MSG_FILE" \
    DEVSHOP_HYGIENE_BRANCH="feat/prop-surface" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  # The touched propagation surface is injected as data:
  grep -qF "kit/scripts/foo.sh" "$CAPTURED_PROMPT"
  # Block-presence computed + reported as 'no':
  grep -qF "contains an **Existing projects:** block: no" "$CAPTURED_PROMPT"
  # NOTE 3 (dimension d) directive is inlined:
  grep -qF "NOTE 3" "$CAPTURED_PROMPT"
  grep -qiF "Existing-projects propagation block" "$CAPTURED_PROMPT"
}

@test "prTextHygieneReason squash-surface: dimension d is N/A when diff touches no propagation surface" {
  cd "$TEST_REPO"
  create_stub gh "" 0
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD
  git -C "$TEST_REPO" checkout -b docs/no-surface -q 2>/dev/null || true
  echo "doc" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -q -m "docs: tweak readme"

  MSG_FILE="$BATS_TEST_TMPDIR/squash-docs.txt"
  printf 'docs: tweak readme\n\n**Doc updates:** readme wording.\n' > "$MSG_FILE"

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="$MSG_FILE" \
    DEVSHOP_HYGIENE_BRANCH="docs/no-surface" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_success
  # NOTE 3 still present, with the N/A guidance so an absent block on a
  # non-propagation squash does NOT affect the verdict.
  grep -qF "NOTE 3" "$CAPTURED_PROMPT"
  grep -qiF "If the list is EMPTY" "$CAPTURED_PROMPT"
}

@test "prTextHygieneReason squash-surface: dimension d reports block: yes when surface touched AND block present" {
  # Pins the HAS_PROP_BLOCK=yes branch — proves the marker regex
  # (^**Existing projects:**) matches a real block on the squash precompute
  # path. A regression that broke the marker would mis-report 'no' on a squash
  # that carries a block and steer NOTE 3 toward a false FAIL.
  cd "$TEST_REPO"
  create_stub gh "" 0
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD
  git -C "$TEST_REPO" checkout -b feat/prop-surface-blocked -q 2>/dev/null || true
  mkdir -p "$TEST_REPO/kit/scripts"
  echo "echo hi" > "$TEST_REPO/kit/scripts/foo.sh"
  git -C "$TEST_REPO" add kit/scripts/foo.sh
  git -C "$TEST_REPO" commit -q -m "feat(scripts): add foo helper"

  MSG_FILE="$BATS_TEST_TMPDIR/squash-withblock.txt"
  cat > "$MSG_FILE" <<'EOF'
feat(scripts): add foo helper

**Adds:** a helper script.

**Existing projects:** none — devshop-side script, consumed via the .devshopkit symlink.
EOF

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="$MSG_FILE" \
    DEVSHOP_HYGIENE_BRANCH="feat/prop-surface-blocked" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_success
  # Surface touched AND a real block present → reported 'yes' (NOTE 3 won't FAIL):
  grep -qF "contains an **Existing projects:** block: yes" "$CAPTURED_PROMPT"
  grep -qF "kit/scripts/foo.sh" "$CAPTURED_PROMPT"
}

@test "prTextHygieneReason squash-surface: dimension d uses three-dot diff — no phantom surface on base-diverged branch" {
  # Regression: dimension (d)'s surface precompute must diff the branch's OWN
  # delta (merge-base..branch, three-dot), NOT a raw two-dot tree comparison
  # against origin/main. On a branch whose base fell behind origin/main, a
  # two-dot diff reports every propagation-surface file origin/main changed
  # since the fork point as a phantom "touched" path — false-FAILing dimension
  # (d) for a branch that never touched a propagation surface. Worked incident:
  # docs/csp-img-src merge (2026-05-28) phantom-FAILed on template/.gitignore.
  cd "$TEST_REPO"
  create_stub gh "" 0

  BASE=$(git -C "$TEST_REPO" rev-parse HEAD)   # fork point = merge-base

  # origin/main moves AHEAD with a propagation-surface change the branch lacks.
  mkdir -p "$TEST_REPO/template"
  echo "node_modules" > "$TEST_REPO/template/.gitignore"
  git -C "$TEST_REPO" add template/.gitignore
  git -C "$TEST_REPO" commit -q -m "feat(template): add gitignore"
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD

  # Feature branch forks from BASE (behind origin/main) and touches NO
  # propagation surface — just a doc.
  git -C "$TEST_REPO" checkout -b docs/base-diverged "$BASE" -q
  echo "doc" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -q -m "docs: tweak readme"

  MSG_FILE="$BATS_TEST_TMPDIR/squash-diverged.txt"
  printf 'docs: tweak readme\n\n**Doc updates:** readme wording.\n' > "$MSG_FILE"

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="$MSG_FILE" \
    DEVSHOP_HYGIENE_BRANCH="docs/base-diverged" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  # The phantom origin/main-only file must NOT be reported as a touched surface.
  # Pre-fix (two-dot) it appeared in PROP_SURFACES → grep would succeed here.
  run grep -qF "template/.gitignore" "$CAPTURED_PROMPT"
  assert_failure
  # NOTE 3 still present so the reviewer treats the absent block as N/A (the
  # branch's real delta is README only — no propagation surface touched).
  grep -qF "NOTE 3" "$CAPTURED_PROMPT"
  # Positively assert dimension (d) is genuinely N/A: the rendered $PROP_SURFACES
  # region is EMPTY, not merely that the one known phantom filename is absent. A
  # differently-broken three-dot could emit a DIFFERENT phantom path the
  # filename-absence grep above would miss — an empty rendered region catches all.
  # Do NOT substitute grep "If the list is EMPTY": that literal is static NOTE 3
  # boilerplate (adversarial-review.sh:427), emitted unconditionally regardless of
  # the surface list, so it has zero discriminating power. Extract the region
  # between the surface-list header and the next prompt line, assert whitespace-only.
  SURFACE_REGION=$(awk '/empty means none:/{f=1;next} /^Squash body contains an/{f=0} f' "$CAPTURED_PROMPT")
  [ -z "$(printf '%s' "$SURFACE_REGION" | tr -d '[:space:]')" ]
}

@test "prTextHygieneReason squash-surface: FAIL fast when MESSAGE_FILE missing (no LLM call)" {
  # The squash surface depends on a tempfile composed by /ak-merge-devshop Phase
  # 0.3. If the env var points at a non-existent path (operator deleted the
  # tempfile mid-flight; tempfile cleanup from a prior crash), the engine must
  # FAIL fast — running an LLM on an empty/missing message wastes a Sonnet
  # call AND would emit a nonsense verdict the operator might trust.
  cd "$TEST_REPO"
  git -C "$TEST_REPO" checkout -b feat/squash-surface-missing-file -q 2>/dev/null || true

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="/tmp/definitely-does-not-exist-$$.txt" \
    DEVSHOP_HYGIENE_BRANCH="feat/squash-surface-missing-file" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_failure
  assert_output --partial "FAIL: surface=squash requires DEVSHOP_HYGIENE_MESSAGE_FILE"
  # Claude must NOT have been invoked on the missing-file path
  [ ! -f "$CAPTURED_PROMPT" ]
}

@test "prTextHygieneReason squash-surface: empty DEVSHOP_HYGIENE_MESSAGE_FILE also FAILs fast" {
  # Belt-and-suspenders: an explicit empty string is an even-more-broken
  # invocation than a missing file, but the same FAIL path must catch it.
  cd "$TEST_REPO"
  git -C "$TEST_REPO" checkout -b feat/squash-surface-empty-env -q 2>/dev/null || true

  DEVSHOP_HYGIENE_SURFACE=squash \
    DEVSHOP_HYGIENE_MESSAGE_FILE="" \
    DEVSHOP_HYGIENE_BRANCH="feat/squash-surface-empty-env" \
    run bash "$REVIEW" prTextHygieneReason "auto-check at compose time"
  assert_failure
  assert_output --partial "FAIL: surface=squash requires DEVSHOP_HYGIENE_MESSAGE_FILE"
  [ ! -f "$CAPTURED_PROMPT" ]
}

@test "prTextHygieneReason default surface (no env var) still goes through the PR path" {
  # Regression guard: the squash branch is opt-in via DEVSHOP_HYGIENE_SURFACE.
  # When unset, the engine MUST fall through to the existing PR path
  # (`gh pr list` etc.) so the .husky/pre-push contract is unchanged.
  cd "$TEST_REPO"
  create_stub gh "" 0
  git -C "$TEST_REPO" checkout -b feature/pr-surface-default -q 2>/dev/null || true

  run bash "$REVIEW" prTextHygieneReason "PR title + body genuinely match commits"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: prTextHygieneReason" "$CAPTURED_PROMPT"
  # Default surface — PR-path CONTEXT (NOT the squash-specific NOTE)
  ! grep -q "Devshop squash commit" "$CAPTURED_PROMPT"
  ! grep -q "SKIP rule (c)" "$CAPTURED_PROMPT"
}

@test "surviving: testReviewSkipReason reaches claude (mocked PASS)" {
  # Audit-time halt-override review — used by /ak-build Phase 5.8.
  # PR-C explicitly KEPT this check-type even while removing testCoverage*.
  cd "$TEST_REPO"
  # Seed a bare review.md so the case branch's audit-section harvesting has something to read.
  mkdir -p "$TEST_REPO/specs/test-feature"
  cat > "$TEST_REPO/specs/test-feature/review.md" <<'EOF'
## Audit 1
<!-- audited-at: abc1234 -->
findings: high=1 medium=0 low=0
- high: foo.test.ts missing onError assertion
EOF
  git -C "$TEST_REPO" checkout -b feature/test-feature -q 2>/dev/null || true
  run bash "$REVIEW" testReviewSkipReason "deferring foo.test.ts coverage; tracked at TODOS.md § follow-ups"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: testReviewSkipReason" "$CAPTURED_PROMPT"
}

# === CONVENTIONS_TO_INCLUDE narrowing ===

@test "exemptAddition still inlines Test Presence + Project Docs Coverage + Project Docs Hierarchy" {
  cd "$TEST_REPO"
  cat > "$TEST_REPO/kit/docs/guide/conventions.md" <<'EOF'
# conventions
## Test Presence
test-presence body
## Project Docs Coverage
docs-coverage body
## Project Docs Hierarchy
hierarchy body
## Other
out-of-map content here
EOF
  run bash "$REVIEW" exemptAddition "apps/web/lib/util.ts  # covered by api.test.ts"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "test-presence body" "$CAPTURED_PROMPT"
  grep -q "docs-coverage body" "$CAPTURED_PROMPT"
  grep -q "hierarchy body" "$CAPTURED_PROMPT"
  # The "## Other / out-of-map" section must NOT be inlined. Scope the assertion
  # to the conventions block — "unrelated" appears in the prompt template's
  # dirtyPushReason rule ("stashed branch X to push unrelated branch Y") so a
  # whole-file grep would false-positive.
  CONVS_BLOCK=$(awk '/^=== Relevant conventions/{flag=1} flag{print} /^The reason must be specific/{flag=0}' "$CAPTURED_PROMPT")
  echo "$CONVS_BLOCK" | grep -qv "out-of-map content here" || true
  ! echo "$CONVS_BLOCK" | grep -q "out-of-map content here"
}
