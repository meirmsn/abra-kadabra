#!/usr/bin/env bats
# Structural assertions for the PRODUCTION_URL firewall lifecycle in the
# template. Two scripts cooperate to lock the project's prod hostname into
# the egress allowlist:
#
#   1. init-prod-url.sh — runs at container start as root via init-firewall.sh.
#      Reads PRODUCTION_URL from /workspace/.devcontainer/.env (operator-set,
#      virtiofs-mounted), validates against a strict DNS-label regex, and
#      atomically writes the value to /etc/refresh-allowed-ips/production_url
#      (overlay-fs, kernel-enforced root-only writes).
#
#   2. refresh-allowed-ips.sh — node-user-callable via NOPASSWD sudoers. Re-
#      reads the locked /etc/ file, re-validates with the SAME regex (defense
#      in depth), re-resolves the hostname via `dig`, additively adds the
#      fresh IPs to the `allowed-domains` ipset. No flush, no iptables touch.
#
# These scripts are root-owned and form the egress security boundary — every
# project's post-deploy curl to prod rides on them. Regressions here are
# high-blast-radius: a relaxed regex lets an attacker-controlled hostname into
# the allowlist; a dropped argv-refusal opens the sudo entry to argument
# injection; an `ipset destroy` inside the read loop turns a recovery into a
# session-wide network drop.
#
# Pure file-content checks — no real container, no root, no network. Pairs
# with firewall-extras-overlay.bats (project-side extras lifecycle) and
# init-firewall-port-allowance.bats (port allowlist shape).
#
# Background:
#   Threat model + virtiofs/overlay-fs rationale: init-prod-url.sh header
#   Operator-facing: /devshop/CLAUDE.md § Known Footguns § Firewall IP rotation
#   Onboarding gap: /ak-go-live § Step 1.5 tri-state classifier (Mode A/B/C)

setup() {
  load helpers/setup
  # Resolve to the repo root of the current worktree, not the canonical /devshop —
  # otherwise a template-touching change on a feature branch asserts against the
  # main checkout's pre-branch state and produces false-greens. BATS_TEST_DIRNAME
  # is kit/tests/; ../../ is the repo root (whether that's /devshop or a worktree).
  DEVSHOP=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  DC="$DEVSHOP/template/.devcontainer"
  INIT_PROD_URL="$DC/init-prod-url.sh"
  REFRESH_AI="$DC/refresh-allowed-ips.sh"
  INIT_FIREWALL="$DC/init-firewall.sh"
  GO_LIVE_SKILL="$DEVSHOP/.claude/skills/devshop/go-live/SKILL.md"
}

# =============================================================================
# init-prod-url.sh — boot-time bootstrap (.env → /etc/)
# =============================================================================

@test "init-prod-url: file exists in template/.devcontainer/" {
  [ -f "$INIT_PROD_URL" ]
}

@test "init-prod-url: refuses argv (prevents attacker-supplied PRODUCTION_URL)" {
  # The script must reject any positional argument. Without this, a caller
  # with access (init-firewall.sh runs as root → so this is mostly defense
  # in depth) could pass an attacker-controlled hostname directly. Match
  # the explicit "$#" check + exit 1.
  run grep -qE 'if \[ "\$#" -ne 0 \]; then' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: hard-coded ENVFILE = /workspace/.devcontainer/.env" {
  # Source file is the operator-set .env on the virtiofs mount. If this path
  # ever changes to something node-writable (e.g., /tmp/), the threat model
  # of the two-file design collapses — a compromised npm dep could rewrite
  # the source mid-session.
  run grep -qE '^ENVFILE=/workspace/\.devcontainer/\.env$' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: hard-coded LOCKED_FILE = /etc/refresh-allowed-ips/production_url" {
  # Destination is the overlay-fs runtime allowlist source. This is the file
  # /ak-go-live § Step 1.5 tri-state classifier reads (Mode C disambig) and
  # the file refresh-allowed-ips.sh reads on every invocation. Any drift here
  # breaks Step 1.5 + Step 3 canary + the onboarding-gap escape hatch.
  run grep -qE 'LOCKED_FILE="\$LOCKED_DIR/production_url"' "$INIT_PROD_URL"
  assert_success
  run grep -qE '^LOCKED_DIR=/etc/refresh-allowed-ips$' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: validates with canonical strict DNS-label regex" {
  # Distinctive substring of the canonical regex — per-label structure with
  # 0-61 interior chars and required alphanumeric boundaries. Any future
  # loosening (e.g., dropping the per-label length cap, allowing underscores)
  # must not regress this check without conscious update.
  run grep -qF '[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: rejects malformed PRODUCTION_URL without writing locked file" {
  # On regex-reject, the script must NOT overwrite an existing valid locked
  # file with garbage. Verify the early-exit + error pair are present.
  run grep -qE 'is not a bare hostname' "$INIT_PROD_URL"
  assert_success
  run grep -qE 'Expected form: example\.com' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: empty PRODUCTION_URL writes empty locked file (no-op fixture)" {
  # When .env's PRODUCTION_URL is empty (pre-/setup-deploy state), the script
  # writes an empty locked file rather than leaving it absent. This is what
  # makes refresh-allowed-ips.sh's no-op branch fire cleanly instead of
  # erroring on a missing file.
  run grep -qE 'PRODUCTION_URL unset/empty in \$ENVFILE — wrote empty \$LOCKED_FILE' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: writes locked file atomically (mktemp + mv, not direct redirect)" {
  # A direct `> "$LOCKED_FILE"` opens a race window where refresh-allowed-ips.sh
  # could read a partial value. The atomic pattern is: write to a temp file
  # in the same dir, then rename. Verify both halves.
  run grep -qE 'TMP=\$\(mktemp "\$LOCKED_DIR/\.production_url\.XXXXXX"\)' "$INIT_PROD_URL"
  assert_success
  run grep -qE 'mv -f "\$TMP" "\$LOCKED_FILE"' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: locked file is root:root 0644" {
  # node-user must be able to READ for the refresh-allowed-ips.sh runtime
  # path, but never WRITE. Verify both chown + chmod on the destination.
  run grep -qE 'chown root:root "\$TMP"' "$INIT_PROD_URL"
  assert_success
  run grep -qE 'chmod 0644 "\$TMP"' "$INIT_PROD_URL"
  assert_success
}

@test "init-prod-url: strips inline comments + surrounding quotes from .env value" {
  # The awk extractor must tolerate the common .env shapes: trailing # comments
  # and single/double-quoted values. Without these, PRODUCTION_URL="host.app"
  # would round-trip as 'host.app' (quotes intact) and fail the regex.
  run grep -qE 'sub\(/\[\[:space:\]\]\*#\.\*\$/, "", \$0\)' "$INIT_PROD_URL"
  assert_success
  run grep -qE 'gsub\(/\^\[' "$INIT_PROD_URL"
  assert_success
}

# =============================================================================
# refresh-allowed-ips.sh — runtime allowlist refresh (sudo entry point)
# =============================================================================

@test "refresh-allowed-ips: file exists in template/.devcontainer/" {
  [ -f "$REFRESH_AI" ]
}

@test "refresh-allowed-ips: refuses argv (prevents attacker-supplied domain via sudo)" {
  # This is the script node-user can sudo. Argv-refusal blocks the obvious
  # injection: `sudo refresh-allowed-ips.sh attacker.com`. The hostname source
  # MUST be the locked /etc/ file, never argv.
  run grep -qE 'if \[ "\$#" -ne 0 \]; then' "$REFRESH_AI"
  assert_success
}

@test "refresh-allowed-ips: reads from /etc/, never from .env directly" {
  # Reading .env here would defeat the entire two-file design (see init-prod-url.sh
  # header). The locked /etc/ file is the only legitimate source. Verify both:
  # the LOCKED_FILE constant points at /etc/, AND no active code defines an
  # ENVFILE variable (the convention init-prod-url.sh uses for the .env path).
  # Comment references to ".env" in the header docstring are legitimate.
  run grep -qE '^LOCKED_FILE=/etc/refresh-allowed-ips/production_url$' "$REFRESH_AI"
  assert_success
  # No ENVFILE assignment — would be the regression signal.
  run grep -qE '^ENVFILE=' "$REFRESH_AI"
  assert_failure
}

@test "refresh-allowed-ips: re-validates with the same canonical regex (defense in depth)" {
  # Even though init-prod-url.sh validates before writing, a corrupted locked
  # file (or a bug in the writer) shouldn't reach `dig` unchecked. Same
  # distinctive substring as the init-prod-url check.
  run grep -qF '[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]' "$REFRESH_AI"
  assert_success
}

@test "refresh-allowed-ips: empty locked file → no-op exit (clean Mode A pre-onboarding state)" {
  # /ak-go-live § Step 1.5 tri-state Mode A scenario: project just scaffolded,
  # .env's PRODUCTION_URL is empty, /etc/ is empty. The refresh script must
  # exit 0 cleanly here, not error. Otherwise the Mode A escape hatch's
  # "sudo /usr/local/bin/refresh-allowed-ips.sh" call would surface an error.
  # Verify both the no-op message AND the `exit 0` within the same conditional
  # block (extract the empty-check block and check for both).
  local block
  block=$(awk '/if \[ -z "\$PRODUCTION_URL" \]; then/,/^fi$/' "$REFRESH_AI" | head -10)
  echo "$block" | grep -qE 'PRODUCTION_URL unset/empty in \$LOCKED_FILE — no-op'
  echo "$block" | grep -qE '^[[:space:]]*exit 0[[:space:]]*$'
}

@test "refresh-allowed-ips: ipset adds are additive only — no flush/destroy" {
  # The whole point of this script (vs re-running init-firewall.sh) is that
  # it adds new IPs without disrupting in-flight connections. A future bug
  # adding `ipset destroy` or `ipset flush` or `iptables -F` inside this
  # script would turn a recovery into a session-wide network drop.
  ! grep -qE 'ipset destroy|ipset flush|iptables -F' "$REFRESH_AI"
  # And the add path uses `ipset add` (positive assertion)
  run grep -qE 'ipset add allowed-domains' "$REFRESH_AI"
  assert_success
}

@test "refresh-allowed-ips: validates each resolved IP before ipset add" {
  # `dig` output isn't inherently trusted (DNS poisoning is rare but the
  # validation is cheap). Reject anything that doesn't look like a dotted-
  # quad before passing to ipset.
  run grep -qE '\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}' "$REFRESH_AI"
  assert_success
}

@test "refresh-allowed-ips: errors if 'allowed-domains' ipset is missing" {
  # The ipset is created by init-firewall.sh at container start. If it's
  # missing, something is wrong upstream — fail loudly rather than silently
  # swallow ipset's permission errors.
  run grep -qE "ipset 'allowed-domains' missing — has init-firewall\.sh run\?" "$REFRESH_AI"
  assert_success
}

# =============================================================================
# Cross-script invariants — both scripts share one source of truth
# =============================================================================

@test "canonical: DOMAIN_REGEX is identical in init-prod-url.sh and refresh-allowed-ips.sh" {
  # The two-script design only works if both validate with the SAME regex.
  # Drift here means init-prod-url.sh writes a value that refresh-allowed-ips.sh
  # then rejects (operator confusion) or vice versa.
  local ipu rai
  ipu=$(grep -E "^DOMAIN_REGEX=" "$INIT_PROD_URL" | head -1)
  rai=$(grep -E "^DOMAIN_REGEX=" "$REFRESH_AI" | head -1)
  [ -n "$ipu" ]
  [ -n "$rai" ]
  [ "$ipu" = "$rai" ]
}

@test "canonical: init-firewall.sh invokes init-prod-url.sh at container start" {
  # The whole flow depends on init-firewall.sh calling init-prod-url.sh in
  # its root-context invocation chain. Without this, the locked /etc/ file
  # never gets written and every container start lands in Mode A.
  run grep -qE '/usr/local/bin/init-prod-url\.sh' "$INIT_FIREWALL"
  assert_success
}

@test "canonical: go-live SKILL.md inline regex copies stay in sync with template scripts" {
  # The canonical strict-DNS-label regex lives in FOUR sites: the two
  # template scripts (checked for identity by the test above), the
  # /ak-go-live § Step 1.5 main probe, and the /ak-go-live § Step 3.5 Mode A
  # escape hatch. Without this assertion, a future template-side tightening
  # of DOMAIN_REGEX could land (test 19 stays green because the templates
  # drift together) without propagating to the skill — the skill's
  # extractor then accepts hostnames the template scripts reject, and an
  # operator-pasted value passes the skill's Step 1.5 validation, gets
  # sudo-tee'd into /etc/refresh-allowed-ips/production_url by the escape
  # hatch, then refresh-allowed-ips.sh's defense-in-depth re-validation
  # rejects it and the canary lands in a "I just configured this — why
  # does it fail?" loop. Codified retroactively from commit 5f6a08b
  # ("adopt canonical DNS-label regex (per-label rigor)") which existed
  # precisely to sync the skill with the templates after a drift surfaced.
  #
  # Distinctive substring (the per-label length cap) is the same probe
  # used by tests 5 + 14 — works regardless of whether the surrounding
  # escaping context is bash $'...' (templates) or markdown grep -qE
  # backslash-soup (skill prose).
  local count
  count=$(grep -cF '[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]' "$GO_LIVE_SKILL")
  [ "$count" -ge 2 ]
}
