#!/usr/bin/env bats
# Structural assertions for the template's compose-isolation shape (the
# default local-supabase reachability under /ak-new-project § Step 2b).
# Verifies the canonical compose-isolation file set + regression guards
# against the rejected host-docker-socket-bind-mount shape returning to
# the menu. Pure file-content checks; no real container needed.
#
# Run on every commit. Pairs with structural-invariants.bats (which covers
# the cross-cutting devcontainer.json assertions: init-devshop / init-firewall
# / workspaceFolder / pnpm-install / TURBO_TELEMETRY_DISABLED — all of which
# the compose-isolation swap preserves).
#
# Background: lalista PR 34 (2026-04-28) shipped compose isolation to
# lalista; the devshop template was ported to the same shape immediately
# after. Roadmap note (port plan):
#   kit/notes/roadmap/lalista-option3-template-port.md
# Architecture guide (operator-facing):
#   kit/docs/guide/local-supabase-compose-isolation.md
# Threat model + decision matrix (where the Option-N numbering lives):
#   kit/notes/security/local-supabase-isolation-options.md

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  DC="$DEVSHOP/template/.devcontainer"
}

# =============================================================================
# Compose isolation file set — five files exist, with the right shape
# =============================================================================

@test "compose-isolation: compose.yml exists" {
  [ -f "$DC/compose.yml" ]
}

@test "compose-isolation: compose.yml declares workspace + supabase-runner services" {
  run grep -E '^  (workspace|supabase-runner):$' "$DC/compose.yml"
  assert_success
  # Both must be present (count = 2 lines)
  local count
  count=$(grep -cE '^  (workspace|supabase-runner):$' "$DC/compose.yml")
  [ "$count" = "2" ]
}

@test "compose-isolation: compose.yml pins SUPABASE_URL to host.docker.internal" {
  run grep -q 'SUPABASE_URL: http://host.docker.internal:54321' "$DC/compose.yml"
  assert_success
}

@test "compose-isolation: compose.yml does NOT forward 54321 / 54322 from supabase-runner" {
  # If forwarded, supabase start would fail with "port already allocated"
  # — the spawned siblings bind those host ports themselves. See
  # compose.yml's comment block "Why supabase-runner does NOT forward".
  run grep -E '^\s+- "54321:|^\s+- "54322:' "$DC/compose.yml"
  assert_failure
}

@test "compose-isolation: compose.yml uses LOCAL_WORKSPACE_FOLDER host-path-mirrored bind" {
  run grep -q '\${LOCAL_WORKSPACE_FOLDER}/supabase:\${LOCAL_WORKSPACE_FOLDER}/supabase' "$DC/compose.yml"
  assert_success
}

@test "compose-isolation: init-host-env.sh exists and is executable" {
  [ -f "$DC/init-host-env.sh" ]
  [ -x "$DC/init-host-env.sh" ]
}

@test "compose-isolation: init-host-env.sh writes LOCAL_WORKSPACE_FOLDER to .env" {
  run grep -q 'LOCAL_WORKSPACE_FOLDER' "$DC/init-host-env.sh"
  assert_success
}

@test "compose-isolation: supabase-runner/Dockerfile exists" {
  [ -f "$DC/supabase-runner/Dockerfile" ]
}

@test "compose-isolation: supabase-runner/Dockerfile builds on debian trixie + installs socat + docker-ce-cli + supabase" {
  local f="$DC/supabase-runner/Dockerfile"
  run grep -q 'FROM debian:trixie-slim' "$f"
  assert_success
  run grep -q 'socat' "$f"
  assert_success
  run grep -q 'docker-ce-cli' "$f"
  assert_success
  run grep -q 'github.com/supabase/cli' "$f"
  assert_success
}

@test "compose-isolation: supabase-runner/cmd-relay.mjs exists and is executable" {
  [ -f "$DC/supabase-runner/cmd-relay.mjs" ]
  [ -x "$DC/supabase-runner/cmd-relay.mjs" ]
}

@test "compose-isolation: supabase-runner/cmd-relay.mjs has the canonical 5-verb ALLOWED map" {
  local f="$DC/supabase-runner/cmd-relay.mjs"
  for verb in '"db-reset"' '"status"' '"start"' '"stop"' '"gen-types"'; do
    run grep -q "$verb" "$f"
    assert_success
  done
  run grep -q 'listen(9000' "$f"
  assert_success
}

# =============================================================================
# devcontainer.json — compose-based, with initializeCommand
# =============================================================================

@test "compose-isolation: devcontainer.json uses dockerComposeFile + service" {
  run grep -q '"dockerComposeFile": "compose.yml"' "$DC/devcontainer.json"
  assert_success
  run grep -q '"service": "workspace"' "$DC/devcontainer.json"
  assert_success
}

@test "compose-isolation: devcontainer.json has initializeCommand calling init-host-env.sh" {
  run grep -q '"initializeCommand"' "$DC/devcontainer.json"
  assert_success
  run grep -q 'init-host-env.sh' "$DC/devcontainer.json"
  assert_success
}

@test "compose-isolation: devcontainer.json does NOT have build:/runArgs:/workspaceMount: (moved to compose.yml)" {
  # build, runArgs, workspaceMount belong on the compose service, not in
  # devcontainer.json under compose isolation. Their presence indicates
  # host-docker-socket-bind-mount drift.
  run grep -E '^\s*"(build|runArgs|workspaceMount)":' "$DC/devcontainer.json"
  assert_failure
}

@test "compose-isolation: devcontainer.json mounts is additive (named volumes + devshop bind, no docker.sock)" {
  # Workspace under compose isolation does not bind /var/run/docker.sock —
  # that belongs to supabase-runner only.
  run grep -q '/var/run/docker.sock' "$DC/devcontainer.json"
  assert_failure
  # Named volumes for command history + claude config still here.
  run grep -q 'commandhistory' "$DC/devcontainer.json"
  assert_success
  run grep -q 'home/node/.claude' "$DC/devcontainer.json"
  assert_success
}

@test "compose-isolation: devcontainer.json postStartCommand does NOT call init-docker-socket.sh" {
  # The devcontainer.json may keep an explanatory COMMENT mentioning
  # init-docker-socket.sh (e.g. "// No init-docker-socket.sh under
  # compose isolation"). Only match the actual postStartCommand value
  # — extract the line that begins with "postStartCommand": and grep IT
  # for the script name.
  local cmd
  cmd=$(grep '"postStartCommand"' "$DC/devcontainer.json")
  run grep -q 'init-docker-socket' <<< "$cmd"
  assert_failure
}

# =============================================================================
# Workspace Dockerfile — no docker tooling, no init-docker-socket COPY
# =============================================================================

@test "compose-isolation: workspace Dockerfile does NOT install docker-ce-cli or docker-compose-plugin" {
  run grep -E 'docker-ce-cli|docker-compose-plugin' "$DC/Dockerfile"
  assert_failure
}

@test "compose-isolation: workspace Dockerfile does NOT COPY init-docker-socket.sh" {
  # The Dockerfile may keep an explanatory COMMENT mentioning
  # init-docker-socket.sh. Only match the actual COPY directive —
  # Dockerfile COPY is conventionally uppercased; case-insensitive
  # match to be safe.
  run grep -E -i '^[[:space:]]*COPY[[:space:]]+init-docker-socket' "$DC/Dockerfile"
  assert_failure
}

# =============================================================================
# init-firewall.sh — host.docker.internal allow rule + carry-over removal
# =============================================================================

@test "compose-isolation: init-firewall.sh has the host.docker.internal allow rule (getent ahostsv4)" {
  local f="$DC/init-firewall.sh"
  run grep -q 'getent ahostsv4 host.docker.internal' "$f"
  assert_success
  # Both supabase data-plane ports must be ACCEPTed
  run grep -E -- '--dport 54321 -j ACCEPT' "$f"
  assert_success
  run grep -E -- '--dport 54322 -j ACCEPT' "$f"
  assert_success
}

@test "compose-isolation: init-firewall.sh does NOT allow api.supabase.com or pooler (regression guard from interlude (d))" {
  # The init-firewall.sh has a comment block explaining WHY these are
  # omitted — those comment lines mention the domains. Match only actual
  # allowlist for-loop entries: lines that are indented + quoted (the
  # for-loop continuation pattern).
  local f="$DC/init-firewall.sh"
  run grep -E '^[[:space:]]+"api\.supabase\.com"' "$f"
  assert_failure
  run grep -E '^[[:space:]]+"[^"]*pooler\.supabase\.com"' "$f"
  assert_failure
}

@test "compose-isolation: init-firewall.sh does NOT allow download.docker.com (workspace has no docker install)" {
  # download.docker.com / registry-1.docker.io / auth.docker.io were in
  # the workspace allowlist when the template installed docker-ce-cli
  # (the rejected host-docker-socket-bind-mount shape). Under compose
  # isolation the workspace doesn't install docker — the supabase-runner
  # does, but it doesn't run this firewall script. The comment block
  # explaining WHY these are omitted mentions the domains; match only
  # actual for-loop entries.
  local f="$DC/init-firewall.sh"
  run grep -E '^[[:space:]]+"download\.docker\.com"' "$f"
  assert_failure
}

# =============================================================================
# init-docker-socket.sh — must not exist (workspace has no socket)
# =============================================================================

@test "compose-isolation: init-docker-socket.sh does NOT exist" {
  [ ! -f "$DC/init-docker-socket.sh" ]
}

# =============================================================================
# package.json db:* scripts (call the relay)
# =============================================================================

@test "compose-isolation: template package.json has db:* scripts pointing at supabase-runner:9000" {
  local pkg="$DEVSHOP/template/package.json"
  for script in '"db:start":' '"db:stop":' '"db:reset":' '"db:status":' '"db:gen-types":'; do
    run grep -q "$script" "$pkg"
    assert_success
  done
  run grep -q 'supabase-runner:9000' "$pkg"
  assert_success
}

# =============================================================================
# CI workflow gitleaks grep flipped from devcontainer.json (JSON) to compose.yml (YAML)
# =============================================================================

@test "compose-isolation: template ci.yml gitleaks step greps compose.yml (not devcontainer.json)" {
  local ci="$DEVSHOP/template/.github/workflows/ci.yml"
  run grep -q "grep 'GITLEAKS_VERSION:' .devcontainer/compose.yml" "$ci"
  assert_success
  # The old shape (sed pattern with double-quote stripping for JSON) must be gone
  run grep -q "grep GITLEAKS_VERSION .devcontainer/devcontainer.json" "$ci"
  assert_failure
}

# =============================================================================
# /ak-new-project SKILL.md — has the Step 2b prompt
# =============================================================================

@test "compose-isolation: new-project SKILL.md has the Step 2b 'Local supabase reachability' choice" {
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  [ -f "$skill" ] || skip "SKILL.md not found"
  run grep -q 'Step 2b: \[HUMAN\] Choose local supabase reachability' "$skill"
  assert_success
  # Per-choice setup branches must be present (host-supabase / compose-isolation
  # / skip — host-docker-socket-bind-mount is deliberately NOT a menu choice;
  # threat model rejects it).
  run grep -q 'Host Supabase' "$skill"
  assert_success
  run grep -q 'Compose isolation \[RECOMMENDED' "$skill"
  assert_success
}

@test "compose-isolation: new-project SKILL.md does NOT offer host-docker-socket-bind-mount as a /ak-new-project choice" {
  # Regression guard: if the rejected shape ever returns to the prompt, fail
  # loudly so the threat-model rejection is explicit. Match plausible re-add
  # phrasings in the (a)/(b)/(c) menu block — either the threat-model number
  # ("Option 2") or the architecture name ("Host docker socket bind-mount").
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  [ -f "$skill" ] || skip "SKILL.md not found"
  run grep -E '^  \([a-d]\) (Option 2|Host docker socket)' "$skill"
  assert_failure
}
