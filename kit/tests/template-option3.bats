#!/usr/bin/env bats
# Structural assertions for the template's Option 3 (compose isolation) shape.
# Verifies that the template ships the canonical Option 3 file set + the
# Option-2-removal regression guards. Pure file-content checks; no real
# container needed.
#
# Run on every commit. Pairs with structural-invariants.bats (which covers
# the cross-cutting devcontainer.json assertions: init-devshop / init-firewall
# / workspaceFolder / pnpm-install / TURBO_TELEMETRY_DISABLED — all of which
# the Option 3 swap preserves).
#
# Background: lalista PR 34 (2026-04-28) shipped Option 3 to lalista; the
# devshop template was ported to the same shape immediately after. Roadmap
# note (port plan): kit/notes/roadmap/lalista-option3-template-port.md.
# Architecture guide (operator-facing): kit/docs/guide/local-supabase-compose-isolation.md.
# Threat model: kit/notes/security/local-supabase-isolation-options.md.

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  DC="$DEVSHOP/template/.devcontainer"
}

# =============================================================================
# Compose isolation file set — five files exist, with the right shape
# =============================================================================

@test "option3: compose.yml exists" {
  [ -f "$DC/compose.yml" ]
}

@test "option3: compose.yml declares workspace + supabase-runner services" {
  run grep -E '^  (workspace|supabase-runner):$' "$DC/compose.yml"
  assert_success
  # Both must be present (count = 2 lines)
  local count
  count=$(grep -cE '^  (workspace|supabase-runner):$' "$DC/compose.yml")
  [ "$count" = "2" ]
}

@test "option3: compose.yml pins SUPABASE_URL to host.docker.internal" {
  run grep -q 'SUPABASE_URL: http://host.docker.internal:54321' "$DC/compose.yml"
  assert_success
}

@test "option3: compose.yml does NOT forward 54321 / 54322 from supabase-runner" {
  # If forwarded, supabase start would fail with "port already allocated"
  # — the spawned siblings bind those host ports themselves. See
  # compose.yml's comment block "Why supabase-runner does NOT forward".
  run grep -E '^\s+- "54321:|^\s+- "54322:' "$DC/compose.yml"
  assert_failure
}

@test "option3: compose.yml uses LOCAL_WORKSPACE_FOLDER host-path-mirrored bind" {
  run grep -q '\${LOCAL_WORKSPACE_FOLDER}/supabase:\${LOCAL_WORKSPACE_FOLDER}/supabase' "$DC/compose.yml"
  assert_success
}

@test "option3: init-host-env.sh exists and is executable" {
  [ -f "$DC/init-host-env.sh" ]
  [ -x "$DC/init-host-env.sh" ]
}

@test "option3: init-host-env.sh writes LOCAL_WORKSPACE_FOLDER to .env" {
  run grep -q 'LOCAL_WORKSPACE_FOLDER' "$DC/init-host-env.sh"
  assert_success
}

@test "option3: supabase-runner/Dockerfile exists" {
  [ -f "$DC/supabase-runner/Dockerfile" ]
}

@test "option3: supabase-runner/Dockerfile builds on debian trixie + installs socat + docker-ce-cli + supabase" {
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

@test "option3: supabase-runner/cmd-relay.mjs exists and is executable" {
  [ -f "$DC/supabase-runner/cmd-relay.mjs" ]
  [ -x "$DC/supabase-runner/cmd-relay.mjs" ]
}

@test "option3: supabase-runner/cmd-relay.mjs has the canonical 5-verb ALLOWED map" {
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

@test "option3: devcontainer.json uses dockerComposeFile + service" {
  run grep -q '"dockerComposeFile": "compose.yml"' "$DC/devcontainer.json"
  assert_success
  run grep -q '"service": "workspace"' "$DC/devcontainer.json"
  assert_success
}

@test "option3: devcontainer.json has initializeCommand calling init-host-env.sh" {
  run grep -q '"initializeCommand"' "$DC/devcontainer.json"
  assert_success
  run grep -q 'init-host-env.sh' "$DC/devcontainer.json"
  assert_success
}

@test "option3: devcontainer.json does NOT have build:/runArgs:/workspaceMount: (moved to compose.yml)" {
  # build, runArgs, workspaceMount belong on the compose service, not in
  # devcontainer.json under Option 3. Their presence indicates Option 2 drift.
  run grep -E '^\s*"(build|runArgs|workspaceMount)":' "$DC/devcontainer.json"
  assert_failure
}

@test "option3: devcontainer.json mounts is additive (named volumes + devshop bind, no docker.sock)" {
  # Workspace under Option 3 does not bind /var/run/docker.sock — that
  # belongs to supabase-runner only.
  run grep -q '/var/run/docker.sock' "$DC/devcontainer.json"
  assert_failure
  # Named volumes for command history + claude config still here.
  run grep -q 'commandhistory' "$DC/devcontainer.json"
  assert_success
  run grep -q 'home/node/.claude' "$DC/devcontainer.json"
  assert_success
}

@test "option3: devcontainer.json postStartCommand does NOT call init-docker-socket.sh" {
  # The Option 3 devcontainer.json may keep an explanatory COMMENT mentioning
  # init-docker-socket.sh (e.g. "// No init-docker-socket.sh under Option 3").
  # Only match the actual postStartCommand value — extract the line that begins
  # with "postStartCommand": and grep IT for the script name.
  local cmd
  cmd=$(grep '"postStartCommand"' "$DC/devcontainer.json")
  run grep -q 'init-docker-socket' <<< "$cmd"
  assert_failure
}

# =============================================================================
# Workspace Dockerfile — no docker tooling, no init-docker-socket COPY
# =============================================================================

@test "option3: workspace Dockerfile does NOT install docker-ce-cli or docker-compose-plugin" {
  run grep -E 'docker-ce-cli|docker-compose-plugin' "$DC/Dockerfile"
  assert_failure
}

@test "option3: workspace Dockerfile does NOT COPY init-docker-socket.sh" {
  # The Dockerfile may keep an explanatory COMMENT mentioning init-docker-socket.sh
  # (e.g. "# No init-docker-socket.sh under Option 3"). Only match the actual
  # COPY directive — Dockerfile COPY lines are case-insensitive but conventionally
  # uppercased; match either to be safe.
  run grep -E -i '^[[:space:]]*COPY[[:space:]]+init-docker-socket' "$DC/Dockerfile"
  assert_failure
}

# =============================================================================
# init-firewall.sh — host.docker.internal allow rule + Option-2 carry-over removal
# =============================================================================

@test "option3: init-firewall.sh has the host.docker.internal allow rule (getent ahostsv4)" {
  local f="$DC/init-firewall.sh"
  run grep -q 'getent ahostsv4 host.docker.internal' "$f"
  assert_success
  # Both supabase data-plane ports must be ACCEPTed
  run grep -E -- '--dport 54321 -j ACCEPT' "$f"
  assert_success
  run grep -E -- '--dport 54322 -j ACCEPT' "$f"
  assert_success
}

@test "option3: init-firewall.sh does NOT allow api.supabase.com or pooler (regression guard from interlude (d))" {
  # The init-firewall.sh has a comment block explaining WHY these are omitted
  # under Option 3 — those comment lines mention the domains. Match only actual
  # allowlist for-loop entries: lines that are indented + quoted + trailing
  # backslash (the for-loop continuation pattern).
  local f="$DC/init-firewall.sh"
  run grep -E '^[[:space:]]+"api\.supabase\.com"' "$f"
  assert_failure
  run grep -E '^[[:space:]]+"[^"]*pooler\.supabase\.com"' "$f"
  assert_failure
}

@test "option3: init-firewall.sh does NOT allow download.docker.com (workspace has no docker install)" {
  # download.docker.com / registry-1.docker.io / auth.docker.io were in the
  # workspace allowlist when the template installed docker-ce-cli (Option 2).
  # Under Option 3 the workspace doesn't install docker — the supabase-runner
  # does, but it doesn't run this firewall script. The comment block explaining
  # WHY these are omitted mentions the domains; match only actual for-loop entries.
  local f="$DC/init-firewall.sh"
  run grep -E '^[[:space:]]+"download\.docker\.com"' "$f"
  assert_failure
}

# =============================================================================
# init-docker-socket.sh — must not exist (Option 3 workspace has no socket)
# =============================================================================

@test "option3: init-docker-socket.sh does NOT exist" {
  [ ! -f "$DC/init-docker-socket.sh" ]
}

# =============================================================================
# package.json db:* scripts (call the relay)
# =============================================================================

@test "option3: template package.json has db:* scripts pointing at supabase-runner:9000" {
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

@test "option3: template ci.yml gitleaks step greps compose.yml (not devcontainer.json)" {
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

@test "option3: new-project SKILL.md has the Step 2b 'Local supabase reachability' choice" {
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  [ -f "$skill" ] || skip "SKILL.md not found"
  run grep -q 'Step 2b: \[HUMAN\] Choose local supabase reachability' "$skill"
  assert_success
  # Per-choice setup branches must be present (Option 1 / 3 / skip — Option 2
  # is deliberately NOT a menu choice; threat model rejects it).
  run grep -q 'Option 1 — supabase CLI on macOS host' "$skill"
  assert_success
  run grep -q 'Option 3 — compose isolation \[RECOMMENDED' "$skill"
  assert_success
}

@test "option3: new-project SKILL.md does NOT offer Option 2 as a /ak-new-project choice" {
  # Regression guard: if Option 2 ever returns to the prompt, fail loudly so the
  # threat-model rejection is explicit. Searches the Step 2b choice block (a/b/c)
  # for an Option-2 menu entry — a stray reference elsewhere in the doc is fine.
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  [ -f "$skill" ] || skip "SKILL.md not found"
  run grep -E '^  \([a-d]\) Option 2' "$skill"
  assert_failure
}
