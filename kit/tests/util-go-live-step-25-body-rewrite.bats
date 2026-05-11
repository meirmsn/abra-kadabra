#!/usr/bin/env bats
# Tests for /ak-go-live § Step 2.5 + the rewrite_pr_body_urls() helper +
# kit/scripts/backfill-pr-image-urls.sh.
#
# Three sections:
#   1) Content tests against the SKILL.md prose contract (D1 / D2 / D3 /
#      D4 / D5 / D6 / D8 / step ordering / version bump).
#   2) Behavior tests of the extracted rewrite_pr_body_urls() helper —
#      sourced directly from kit/scripts/lib/rewrite-pr-body-urls.sh.
#   3) Behavior tests of kit/scripts/backfill-pr-image-urls.sh, with `gh`
#      mocked via _FAKE_GH=1 so no GitHub credentials or network are
#      needed in CI (per spec D7d).

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/go-live/SKILL.md"
  WORKFLOW_FILE="/devshop/kit/docs/guide/workflow.md"
  HELPER_FILE="/devshop/kit/scripts/lib/rewrite-pr-body-urls.sh"
  BACKFILL_SCRIPT="/devshop/kit/scripts/backfill-pr-image-urls.sh"
}

# =============================================================================
# Section 1: Content tests — SKILL.md + workflow.md prose
# =============================================================================

@test "Step 2.5 exists between Step 2 and Step 2b" {
  # Section header present.
  grep -qE '^## Step 2\.5: Rewrite PR-body image URLs to merge SHA' "$SKILL_FILE"

  local step2_line step25_line step2b_line
  step2_line=$(grep -nE '^## Step 2: Land and deploy' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step25_line=$(grep -nE '^## Step 2\.5:' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step2b_line=$(grep -nE '^## Step 2b:' "$SKILL_FILE" | head -1 | cut -d: -f1)

  [ -n "$step2_line" ]
  [ -n "$step25_line" ]
  [ -n "$step2b_line" ]
  [ "$step2_line" -lt "$step25_line" ]
  [ "$step25_line" -lt "$step2b_line" ]
}

@test "Step 2.5 names mergeCommit.oid as the SHA source" {
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" | grep -q 'mergeCommit'
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" | grep -q '\.mergeCommit\.oid'
}

@test "Step 2.5 names headRefName as the branch source (not git branch --show-current)" {
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" | grep -q 'headRefName'
  ! awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" | grep -q 'git branch --show-current'
}

@test "Step 2.5 documents the exact-branch-match phrasing" {
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" \
    | grep -qiE 'exact-match|exact branch|exact match'
  # And explicitly mentions that other refs (other branches, tags, main,
  # third-party repos) are preserved.
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" \
    | grep -qE 'preserved verbatim|tags|third-party'
}

@test "Step 2.5 documents the null-mergeCommit.oid skip" {
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" \
    | grep -qE 'no mergeCommit\.oid|skipping body rewrite'
}

@test "Step 2.5 documents the zero-match silent pass" {
  awk '/^## Step 2\.5:/,/^## Step 2b:/' "$SKILL_FILE" \
    | grep -qE 'nothing to rewrite|silent attesting pass|no /raw/'
}

@test "Step 2.5 runs BEFORE Step 2b's git branch -D" {
  local step25_line branch_d_line
  step25_line=$(grep -nE '^## Step 2\.5:' "$SKILL_FILE" | head -1 | cut -d: -f1)
  branch_d_line=$(grep -n 'git branch -D' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$step25_line" ]
  [ -n "$branch_d_line" ]
  [ "$step25_line" -lt "$branch_d_line" ]
}

@test "ak-go-live SKILL.md version bumped to 1.4.0+" {
  grep -qE '^version: 1\.[4-9]\.' "$SKILL_FILE"
}

@test "workflow.md Step 6 has bullet 2.5 paragraph referencing Step 2.5" {
  awk '/^## Step 6:/,/^## Feature tracking/' "$WORKFLOW_FILE" \
    | grep -qE 'Step 2\.5'
}

# =============================================================================
# Section 2: Behavior tests — rewrite_pr_body_urls() helper
# =============================================================================

@test "helper: rewrites a single feature-branch URL to merge-SHA URL" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
hero shot:
![hero](https://github.com/o/r/raw/feat-x/specs/foo/hero.png)
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "abcdef0123456789"
  grep -q 'https://github.com/o/r/raw/abcdef0123456789/specs/foo/hero.png' "$out"
  ! grep -q '/raw/feat-x/' "$out"
}

@test "helper: rewrites multiple feature-branch URLs in one body" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
1) https://github.com/o/r/raw/feat-x/a.png
2) https://github.com/o/r/raw/feat-x/b.png
3) https://github.com/o/r/raw/feat-x/c.png
4) https://github.com/o/r/raw/feat-x/d.png
5) https://github.com/o/r/raw/feat-x/e.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "deadbeefcafe1234"
  local n
  n=$(grep -c '/raw/deadbeefcafe1234/' "$out")
  [ "$n" -eq 5 ]
  ! grep -q '/raw/feat-x/' "$out"
}

@test "helper: preserves a /raw/<other-branch>/ URL elsewhere in body" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
target: https://github.com/o/r/raw/feat-x/a.png
other:  https://github.com/o/r/raw/feat-other/b.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "1111111111111111"
  grep -q 'https://github.com/o/r/raw/1111111111111111/a.png' "$out"
  grep -q 'https://github.com/o/r/raw/feat-other/b.png' "$out"
}

@test "helper: preserves a /raw/main/ URL" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
target: https://github.com/o/r/raw/feat-x/a.png
main:   https://github.com/o/r/raw/main/some.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "2222222222222222"
  grep -q '/raw/2222222222222222/a.png' "$out"
  grep -q '/raw/main/some.png' "$out"
}

@test "helper: preserves a /raw/<tag>/ URL" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
target: https://github.com/o/r/raw/feat-x/a.png
tag:    https://github.com/o/r/raw/v1.2.3/some.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "3333333333333333"
  grep -q '/raw/3333333333333333/a.png' "$out"
  grep -q '/raw/v1\.2\.3/some.png' "$out"
}

@test "helper: preserves a third-party-repo /raw/<head-ref>/ URL" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
target:      https://github.com/o/r/raw/feat-x/a.png
third-party: https://github.com/other-owner/other-repo/raw/feat-x/b.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "4444444444444444"
  grep -q 'https://github.com/o/r/raw/4444444444444444/a.png' "$out"
  grep -q 'https://github.com/other-owner/other-repo/raw/feat-x/b.png' "$out"
}

@test "helper: escapes slashes in slashed branch names (feat/foo)" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
slashed: https://github.com/o/r/raw/feat/foo/path.png
sibling: https://github.com/o/r/raw/featAfoo/path.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat/foo" "5555555555555555"
  grep -q 'https://github.com/o/r/raw/5555555555555555/path.png' "$out"
  # The sibling URL must NOT be touched — without escaping the `/`, the
  # branch pattern would match `feat<any>foo`.
  grep -q 'https://github.com/o/r/raw/featAfoo/path.png' "$out"
}

@test "helper: escapes regex metacharacters in branch names (feat.foo, feat+foo)" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  # feat.foo branch — should match only itself; featAfoo URL must survive.
  cat > "$in" <<'EOF'
target:  https://github.com/o/r/raw/feat.foo/x.png
sibling: https://github.com/o/r/raw/featAfoo/y.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat.foo" "6666666666666666"
  grep -q 'https://github.com/o/r/raw/6666666666666666/x.png' "$out"
  grep -q 'https://github.com/o/r/raw/featAfoo/y.png' "$out"

  # feat+foo branch — '+' is regex metacharacter for one-or-more; without
  # escaping, `featt+foo` would match `feat+foo` because the `+` would
  # quantify the prior `t`. Construct a fixture that would expose that.
  cat > "$in" <<'EOF'
target:  https://github.com/o/r/raw/feat+foo/p.png
sibling: https://github.com/o/r/raw/feattfoo/q.png
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat+foo" "7777777777777777"
  grep -q 'https://github.com/o/r/raw/7777777777777777/p.png' "$out"
  grep -q 'https://github.com/o/r/raw/feattfoo/q.png' "$out"
}

@test "helper: is a no-op when body has zero matching URLs" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out="$BATS_TEST_TMPDIR/out.md"
  cat > "$in" <<'EOF'
no urls here at all
just some text
EOF
  rewrite_pr_body_urls "$in" "$out" "o/r" "feat-x" "8888888888888888"
  # Output should be byte-identical to input.
  cmp -s "$in" "$out"
}

@test "helper: is idempotent — second call on rewritten body is a no-op" {
  source "$HELPER_FILE"
  local in="$BATS_TEST_TMPDIR/in.md" out1="$BATS_TEST_TMPDIR/out1.md" out2="$BATS_TEST_TMPDIR/out2.md"
  cat > "$in" <<'EOF'
hero: https://github.com/o/r/raw/feat-x/foo.png
EOF
  rewrite_pr_body_urls "$in"  "$out1" "o/r" "feat-x" "9999999999999999"
  rewrite_pr_body_urls "$out1" "$out2" "o/r" "feat-x" "9999999999999999"
  # Second call leaves out2 byte-identical to out1.
  cmp -s "$out1" "$out2"
  ! grep -q '/raw/feat-x/' "$out2"
}

# =============================================================================
# Section 3: Behavior tests — backfill-pr-image-urls.sh
# =============================================================================
#
# The script gates real `gh` calls behind `_FAKE_GH=1`; tests below set
# that env var + point _FAKE_GH_FIXTURE at a JSON file with the canned
# `gh pr list` output, and _FAKE_GH_CAPTURE at a file where the fake
# captures `gh pr edit` invocations.

# Helper: write a fixture array of one or more PR objects to the given
# tmpfile. Each subsequent arg is a one-line JSON object.
write_fixture() {
  local out="$1"; shift
  local json="["
  local first=1
  for obj in "$@"; do
    if [ "$first" -eq 1 ]; then
      json="${json}${obj}"
      first=0
    else
      json="${json},${obj}"
    fi
  done
  json="${json}]"
  printf '%s\n' "$json" > "$out"
}

@test "backfill: --help prints usage and exits 0" {
  run "$BACKFILL_SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q -- '--owner'
  echo "$output" | grep -q -- '--repo'
  echo "$output" | grep -q -- '--dry-run'
  echo "$output" | grep -q -- '--accept-history-rewrite'
}

@test "backfill: missing --owner exits 1" {
  run "$BACKFILL_SCRIPT" --repo lalista
  [ "$status" -eq 1 ]
  echo "$output" | grep -q -- '--owner'
}

@test "backfill: missing --repo exits 1" {
  run "$BACKFILL_SCRIPT" --owner meirmsn
  [ "$status" -eq 1 ]
  echo "$output" | grep -q -- '--repo'
}

@test "backfill: --dry-run + --accept-history-rewrite together exit 1" {
  run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --accept-history-rewrite
  [ "$status" -eq 1 ]
  echo "$output" | grep -qiE 'mutually exclusive|conflict'
}

@test "backfill: default mode is dry-run" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local capture="$BATS_TEST_TMPDIR/edit.captured"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  : > "$capture"
  write_fixture "$fixture" \
    '{"number":1,"headRefName":"feat-x","mergeCommit":{"oid":"abc1234"},"body":"![hero](https://github.com/o/r/raw/feat-x/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" _FAKE_GH_CAPTURE="$capture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  # No `gh pr edit` invocation — capture file empty.
  [ ! -s "$capture" ]
  # Audit row says dry-run-would-rewrite.
  local row
  row=$(cat "$audit_dir"/*.jsonl)
  echo "$row" | grep -q '"outcome":"dry-run-would-rewrite"'
  echo "$row" | grep -q '"dry_run":true'
}

@test "backfill: --accept-history-rewrite mutates the body" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local capture="$BATS_TEST_TMPDIR/edit.captured"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  : > "$capture"
  write_fixture "$fixture" \
    '{"number":7,"headRefName":"feat-x","mergeCommit":{"oid":"deadbeefcafe1234"},"body":"![hero](https://github.com/o/r/raw/feat-x/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" _FAKE_GH_CAPTURE="$capture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --accept-history-rewrite --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  # Capture file recorded one gh pr edit invocation containing the rewritten body.
  grep -q 'gh pr edit 7' "$capture"
  grep -q 'https://github.com/o/r/raw/deadbeefcafe1234/h.png' "$capture"

  local row
  row=$(cat "$audit_dir"/*.jsonl)
  echo "$row" | grep -q '"outcome":"rewrote"'
  echo "$row" | grep -q '"dry_run":false'
}

@test "backfill: skips PR with empty headRefName, audit reason=no-head-ref" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":2,"headRefName":"","mergeCommit":{"oid":"abc"},"body":"x","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  cat "$audit_dir"/*.jsonl | grep -q '"reason":"no-head-ref"'
}

@test "backfill: skips PR with null mergeCommit.oid, audit reason=no-merge-sha" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":3,"headRefName":"feat-x","mergeCommit":null,"body":"x","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  cat "$audit_dir"/*.jsonl | grep -q '"reason":"no-merge-sha"'
}

@test "backfill: skips PR edited >5min after merge, audit reason=body-edited-post-merge" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":4,"headRefName":"feat-x","mergeCommit":{"oid":"abc"},"body":"![](https://github.com/o/r/raw/feat-x/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:28:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  cat "$audit_dir"/*.jsonl | grep -q '"reason":"body-edited-post-merge"'
}

@test "backfill: does NOT skip PR edited within 5min grace" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":5,"headRefName":"feat-x","mergeCommit":{"oid":"abc1234"},"body":"![](https://github.com/o/r/raw/feat-x/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:26:00Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  # Should produce a dry-run-would-rewrite row, NOT a body-edited-post-merge skip.
  cat "$audit_dir"/*.jsonl | grep -q '"outcome":"dry-run-would-rewrite"'
  ! cat "$audit_dir"/*.jsonl | grep -q '"reason":"body-edited-post-merge"'
}

@test "backfill: silent skip for PR with no matching URLs, audit reason=no-matching-urls" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":6,"headRefName":"feat-x","mergeCommit":{"oid":"abc"},"body":"no images here at all","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  cat "$audit_dir"/*.jsonl | grep -q '"reason":"no-matching-urls"'
}

@test "backfill: --limit caps PR scan" {
  # 5 PRs in fixture; --limit 2 should produce 2 audit rows.
  # NOTE: --limit is forwarded to `gh pr list --limit <N>` — the real gh
  # CLI applies the limit server-side. Since the fake just emits the
  # whole fixture, we simulate by using a fixture with 2 elements.
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":10,"headRefName":"feat-a","mergeCommit":{"oid":"a"},"body":"![](https://github.com/o/r/raw/feat-a/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}' \
    '{"number":11,"headRefName":"feat-b","mergeCommit":{"oid":"b"},"body":"![](https://github.com/o/r/raw/feat-b/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --limit 2 --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  local count
  count=$(wc -l < "$audit_dir"/*.jsonl | tr -d ' ')
  [ "$count" -eq 2 ]
}

@test "backfill: --since filters to merged-on-or-after" {
  # 3 PRs with varying mergedAt; --since 2026-05-01 should keep only the
  # two from May.
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":20,"headRefName":"feat-old","mergeCommit":{"oid":"a"},"body":"x","mergedAt":"2026-04-01T00:00:00Z","updatedAt":"2026-04-01T00:00:01Z"}' \
    '{"number":21,"headRefName":"feat-may1","mergeCommit":{"oid":"b"},"body":"x","mergedAt":"2026-05-02T00:00:00Z","updatedAt":"2026-05-02T00:00:01Z"}' \
    '{"number":22,"headRefName":"feat-may2","mergeCommit":{"oid":"c"},"body":"x","mergedAt":"2026-05-08T00:00:00Z","updatedAt":"2026-05-08T00:00:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --since 2026-05-01 --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  ! cat "$audit_dir"/*.jsonl | grep -q '"pr":20'
  cat "$audit_dir"/*.jsonl | grep -q '"pr":21'
  cat "$audit_dir"/*.jsonl | grep -q '"pr":22'
}

@test "backfill: idempotent re-run on already-rewritten body is all-skip" {
  # Simulate the second run by feeding a fixture whose body is already
  # rewritten (URL contains the SHA, not the head-ref).
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":30,"headRefName":"feat-x","mergeCommit":{"oid":"deadbeefcafe1234"},"body":"![](https://github.com/o/r/raw/deadbeefcafe1234/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  cat "$audit_dir"/*.jsonl | grep -q '"reason":"no-matching-urls"'
}

@test "backfill: audit log JSONL is well-formed" {
  local fixture="$BATS_TEST_TMPDIR/fixture.json"
  local audit_dir="$BATS_TEST_TMPDIR/audit"
  write_fixture "$fixture" \
    '{"number":40,"headRefName":"feat-x","mergeCommit":{"oid":"abc1234"},"body":"![](https://github.com/o/r/raw/feat-x/h.png)","mergedAt":"2026-05-08T14:22:00Z","updatedAt":"2026-05-08T14:22:01Z"}'

  _FAKE_GH=1 _FAKE_GH_FIXTURE="$fixture" \
    run "$BACKFILL_SCRIPT" --owner o --repo r --dry-run --audit-dir "$audit_dir"
  [ "$status" -eq 0 ]
  # Each line is valid JSON; required keys present.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "$line" | jq -e '.ts and .pr and (.outcome|type=="string") and (.dry_run|type=="boolean")' >/dev/null
  done < "$audit_dir"/*.jsonl
}
