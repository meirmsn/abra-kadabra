#!/usr/bin/env bats
# Structural assertions for the firewall-extras-overlay shape.
#
# The overlay is a [scaffold-once] file at .devcontainer/firewall-extra-domains
# that init-firewall.sh reads at runtime to extend the static template
# allowlist with project-specific external services (Supabase project URL,
# Sentry org ingest, PostHog region, Vercel app URL — anything per-project).
# init-devshop.sh seeds the workspace copy from the template if missing,
# then chowns it root:root 644 on every container start so node (Claude /
# npm) cannot tamper.
#
# Pure file-content checks — no real container, no root, no network. Pairs
# with structural-invariants.bats (template-side wiring) and
# manifest-lifecycle.bats (the [scaffold-once] mechanism).
#
# Background:
#   Architecture: kit/docs/guide/architecture.md § File lifecycle § Hybrid lifecycle
#   Operator-facing: kit/docs/guide/workflow.md § Starting a New Project
#   Footgun reference: kit/docs/guide/ops.md § Known Footguns § Firewall IP rotation

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  DC="$DEVSHOP/template/.devcontainer"
  TEMPLATE_OVERLAY="$DC/firewall-extra-domains"
  INIT_FIREWALL="$DC/init-firewall.sh"
  INIT_DEVSHOP="$DEVSHOP/kit/scripts/init-devshop.sh"
  MANIFEST="$DEVSHOP/kit/manifest.txt"
}

# =============================================================================
# Template overlay file — exists with the documented header shape
# =============================================================================

@test "overlay: template firewall-extra-domains file exists" {
  [ -f "$TEMPLATE_OVERLAY" ]
}

@test "overlay: template overlay header documents one-bare-hostname-per-line format" {
  # pins: template/.devcontainer/firewall-extra-domains :: One bare hostname per line
  run grep -qE 'One bare hostname per line' "$TEMPLATE_OVERLAY"
  assert_success
}

@test "overlay: template overlay header documents '#'-comment + blank-line skip" {
  run grep -qE 'Lines starting with .#. and blank lines are ignored' "$TEMPLATE_OVERLAY"
  assert_success
}

@test "overlay: template overlay footer does NOT claim init-firewall.sh is 'safe to call repeatedly' (regression guard)" {
  # The original footer (pre-fix) claimed `sudo /usr/local/bin/init-firewall.sh`
  # is "safe to call repeatedly" as a shortcut — directly contradicting the
  # CLAUDE.md / ops.md / TODOS warning that the script stalls the Claude
  # session (twice-observed during lalista PR 2 close-out 2026-04-20). The
  # corrected footer routes operators to additive `ipset add` or container
  # rebuild instead. Guard against future regression of THAT specific claim
  # (more precise than greping for the script name itself, since the new
  # footer legitimately mentions the script in the DON'T warning).
  run grep -qE 'safe to call repeatedly' "$TEMPLATE_OVERLAY"
  assert_failure
}

@test "overlay: template overlay footer warns against re-running init-firewall.sh" {
  run grep -qE "DON'T re-run \`?sudo /usr/local/bin/init-firewall\.sh\`?" "$TEMPLATE_OVERLAY"
  assert_success
}

# =============================================================================
# init-firewall.sh — reads, validates, warn-skips, adds (additive)
# =============================================================================

@test "init-firewall: reads project-specific extras from /workspace/.devcontainer/firewall-extra-domains" {
  run grep -qE 'EXTRAS_FILE=.*workspace/\.devcontainer/firewall-extra-domains' "$INIT_FIREWALL"
  assert_success
}

@test "init-firewall: validates extras lines with strict DNS-label regex (anchored, label shape, dotted tail)" {
  # The regex enforces: label start = alnum; interior = alnum-or-dash up to
  # 63 chars, end = alnum; multiple labels joined by '.'. Anchors prevent
  # shell-meta injection bleeding through to dig.
  run grep -qE '\[\[ ! "\$line" =~ \^\(\[a-zA-Z0-9\]\(\[a-zA-Z0-9-\]' "$INIT_FIREWALL"
  assert_success
}

@test "init-firewall: warns + appends to SKIPPED_DOMAINS on malformed extras line" {
  run grep -qE 'WARN: firewall-extra-domains line .+ is not a valid hostname — skipping' "$INIT_FIREWALL"
  assert_success
  # And that it appends to the summary banner array
  run grep -qE 'SKIPPED_DOMAINS\+=\("\$line"\)' "$INIT_FIREWALL"
  assert_success
}

@test "init-firewall: strips '#' comments + trims whitespace before validating extras lines" {
  # `${raw%%#*}` strips inline comment tail; `tr -d '[:space:]'` trims.
  run grep -qE 'line="\$\{raw%%#\*\}"' "$INIT_FIREWALL"
  assert_success
  run grep -qE "tr -d '\[:space:\]'" "$INIT_FIREWALL"
  assert_success
}

@test "init-firewall: extras read loop is additive (ipset add, not flush/destroy)" {
  # Critical security/safety property: the read loop must use additive
  # `ipset add` only. Any `ipset destroy` or `iptables -F` inside the
  # extras read loop would break the safety guarantee that the overlay
  # can be re-resolved without disrupting the active session.
  local extras_block
  extras_block=$(awk '/^# Project-specific extras —/,/^fi$/' "$INIT_FIREWALL")
  echo "$extras_block" | grep -qE '^\s*ipset add allowed-domains'
  ! echo "$extras_block" | grep -qE 'ipset destroy|iptables -F'
}

@test "init-firewall: project-specific-domains comment block routes to firewall-extra-domains" {
  # The static `for domain in \` loop's preceding comment must point operators
  # at the new overlay (not the old "add entries here" guidance, which became
  # the silent-revert trap).
  run grep -qE 'go in \.devcontainer/firewall-extra-domains' "$INIT_FIREWALL"
  assert_success
}

# =============================================================================
# init-devshop.sh — seeds + locks the workspace overlay copy
# =============================================================================

@test "init-devshop: seeds firewall-extra-domains from template if dst missing" {
  run grep -qE 'FWE_SRC=.*template/\.devcontainer/firewall-extra-domains' "$INIT_DEVSHOP"
  assert_success
  run grep -qE 'FWE_DST=.*\.devcontainer/firewall-extra-domains' "$INIT_DEVSHOP"
  assert_success
  # The seed-only-if-missing guard
  run grep -qE 'if \[ -f "\$FWE_SRC" \] && \[ ! -e "\$FWE_DST" \]; then' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop: seed uses install -D -m 644 -o root -g root (atomic mode + ownership)" {
  # The `-o root -g root` pair is required — without it the seeded file
  # inherits the staging owner, silently dropping to node:node and
  # breaking the lockdown invariant. See CLAUDE.md gotcha on
  # /tmp+sudo handoff for the same fault class on root-owned destinations.
  run grep -qE 'install -D -m 644 -o root -g root "\$FWE_SRC" "\$FWE_DST"' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop: re-locks firewall-extra-domains to root:root 644 on a stat-tuple drift" {
  # Defense-in-depth re-lock: if a `node`-user write created the file or
  # changed its perms mid-session, the next container start restores the
  # locked state. The `stat -c '%U:%G %a'` guard (added with the mtime-bump
  # fix, c6be31e) skips the chown/chmod ONLY when ownership+mode already
  # match root:root 644 — a drifted tuple (node-created or perm-changed
  # file) still mismatches, so the re-lock fires. Conditional-on-drift
  # preserves the security property while dropping the redundant per-boot
  # write; a revert to unconditional chown/chmod is a churn regression, not
  # a correctness one. Pin the guarded form statically.
  run grep -qE '\[ -e "\$FWE_DST" \] && \[ "\$\(stat -c .%U:%G %a. "\$FWE_DST"\)" != "root:root 644" \]' "$INIT_DEVSHOP"
  assert_success
}

# =============================================================================
# Manifest — declares the overlay as [scaffold-once]
# =============================================================================

@test "manifest: declares .devcontainer/firewall-extra-domains [scaffold-once]" {
  # pins: kit/manifest.txt :: .devcontainer/firewall-extra-domains [scaffold-once]
  run grep -qE '^\.devcontainer/firewall-extra-domains \[scaffold-once\]$' "$MANIFEST"
  assert_success
}

@test "manifest: template-side firewall-extra-domains is in init-devshop.sh's static lock list" {
  # Template integrity — the template copy is the seed source; if it
  # were unlocked, a node-user write to it would propagate to all
  # future scaffolds.
  run grep -qE '"\$DEVSHOP/template/\.devcontainer/firewall-extra-domains"' "$INIT_DEVSHOP"
  assert_success
}
