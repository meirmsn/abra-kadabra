#!/usr/bin/env bats
# Behavior tests for kit/scripts/lib/extract-prod-url.sh.
#
# The helper extracts a bare production hostname from the `Production URL:`
# line of a CLAUDE.md, used by /ak-go-live Step 1.5 (health probe) and its
# Mode A escape hatch. Regression coverage for home-os PR #39: the URL
# written mid-sentence (backticked, followed by prose) used to glue the host
# to the trailing text and silently skip the probe.
#
# Pure function tests against synthetic fixtures; no real container, no curl.

setup() {
  load helpers/setup
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  source "$REPO_ROOT/kit/scripts/lib/extract-prod-url.sh"
  CLAUDE_MD="$BATS_TEST_TMPDIR/CLAUDE.md"
}

# Helper: write CLAUDE.md content and run the extractor.
extract() {
  printf '%s\n' "$1" > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
}

@test "mid-sentence backticked URL followed by prose (home-os PR #39)" {
  extract 'Production URL: `https://home-os-nu-two.vercel.app`. Full deploy config, status commands, and dashboard follow-ups: [DEPLOY.md](./DEPLOY.md).'
  assert_success
  assert_output "home-os-nu-two.vercel.app"
}

@test "mid-sentence label after a sentence boundary (home-os PR #44)" {
  extract 'Vercel auto-on-push from `main` (no manual step). Production URL: `https://home-os-nu-two.vercel.app`. Full deploy config: [DEPLOY.md](./DEPLOY.md).'
  assert_success
  assert_output "home-os-nu-two.vercel.app"
}

@test "stray URL before the mid-sentence label does not win" {
  extract 'See https://docs.example.com for setup. Production URL: https://real.vercel.app.'
  assert_success
  assert_output "real.vercel.app"
}

@test "colon-less prose mention on the same line as the label does not win (colon guard)" {
  # The new (^|sentence-boundary) alternation makes mid-line label matching
  # possible; this pins the trailing-`:` guard against that new branch — a
  # colon-less "production url" mention earlier in the SAME sentence must not
  # match, only the real `Production URL:` label.
  extract 'Done. See production url docs first. Production URL: https://real.vercel.app.'
  assert_success
  assert_output "real.vercel.app"
}

@test "bare https URL on its own line" {
  extract 'Production URL: https://app.vercel.app'
  assert_success
  assert_output "app.vercel.app"
}

@test "scheme-less host (fallback path)" {
  extract 'Production URL: app.vercel.app'
  assert_success
  assert_output "app.vercel.app"
}

@test "URL with a path strips the path" {
  extract '- **Production URL:** https://app.vercel.app/dashboard'
  assert_success
  assert_output "app.vercel.app"
}

@test "URL ending a sentence with a trailing dot is stripped" {
  extract 'Production URL: https://app.vercel.app.'
  assert_success
  assert_output "app.vercel.app"
}

@test "http (non-tls) scheme is tolerated, scheme stripped" {
  extract 'Production URL: http://localhost.test'
  assert_success
  assert_output "localhost.test"
}

@test "unfilled placeholder yields empty" {
  extract 'Production URL: <fill in your prod url>'
  assert_success
  assert_output ""
}

@test "no Production URL line yields empty" {
  extract 'Some other config line here'
  assert_success
  assert_output ""
}

@test "case-insensitive match on the label" {
  extract 'production url: https://app.vercel.app'
  assert_success
  assert_output "app.vercel.app"
}

@test "first match wins when multiple production-url lines exist" {
  printf '%s\n%s\n' 'Production URL: https://first.vercel.app' 'Staging production URL: https://second.vercel.app' > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
  assert_success
  assert_output "first.vercel.app"
}

@test "missing file yields empty without error" {
  run extract_prod_url "$BATS_TEST_TMPDIR/does-not-exist.md"
  assert_success
  assert_output ""
}

@test "uppercase scheme is stripped (case-insensitive scheme strip)" {
  extract 'Production URL: HTTPS://app.vercel.app'
  assert_success
  assert_output "app.vercel.app"
}

@test "prose mention of 'production url' above the canonical line is ignored" {
  printf '%s\n%s\n' 'See the production url docs before deploying.' \
    'Production URL: https://canonical.vercel.app' > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
  assert_success
  assert_output "canonical.vercel.app"
}

@test "prose line carrying a stale URL above the canonical line is ignored (no wrong-host probe)" {
  printf '%s\n%s\n' 'The old production url was https://stale-staging.vercel.app before the cutover.' \
    'Production URL: https://canonical.vercel.app' > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
  assert_success
  assert_output "canonical.vercel.app"
}

@test "go-live SKILL.md sources the helper (both call sites wired)" {
  SKILL="$REPO_ROOT/.claude/skills/devshop/go-live/SKILL.md"
  run grep -c 'source /devshop/kit/scripts/lib/extract-prod-url.sh' "$SKILL"
  assert_success
  assert_output "2"
}
