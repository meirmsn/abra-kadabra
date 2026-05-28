#!/usr/bin/env bash
# What: Phase 3.0 preflight helper — verify local environment health before
#       browse/QA/screenshot operations, with optional auto-recovery.
# Why:  When the local env breaks (OOM, zombie processes, Supabase down), the
#       pipeline silently skips verification or defers failures to CI. This
#       script makes env health a deterministic check — exit 0 = healthy,
#       exit 1 = unhealthy with itemized failures.
# Does NOT: start the dev server (operator/Playwright webServer owns lifecycle),
#       restart Supabase (supabase-bootstrap.sh owns that), or check mid-gate
#       health (preflight-time only).
#
# Subcommands:
#   check   — verify 4 conditions: dev server reachable, Supabase healthy,
#             memory headroom >= 1GB, no zombie processes on monitored ports.
#             Exit 0 = all clear, exit 1 = one or more failures (stdout itemizes).
#   recover — kill zombie processes on monitored ports after confirming they are
#             NOT the current session's dev server PID. Exit 0 = recovery
#             succeeded or nothing to recover, exit 1 = could not kill.
#
# Spec: specs/local-env-pillar/spec.md § T1, § D2, § D4.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"

# Monitored ports: dev server (3000, 3001), Supabase API (54321), Supabase DB (54322).
MONITORED_PORTS="${MONITORED_PORTS:-3000 3001 54321 54322}"

# Memory threshold in kB (1GB = 1048576 kB).
MEMORY_THRESHOLD_KB="${MEMORY_THRESHOLD_KB:-1048576}"

# Path to supabase-bootstrap.sh (tests can override).
SUPABASE_BOOTSTRAP="${SUPABASE_BOOTSTRAP:-$DEVSHOP/kit/scripts/preship/supabase-bootstrap.sh}"

# Dev server PID to protect from recovery (tests can override).
# When set, recover will not kill this PID.
DEV_SERVER_PID="${DEV_SERVER_PID:-}"

# Override paths for testability.
PROC_MEMINFO="${PROC_MEMINFO:-/proc/meminfo}"
CGROUP_V2_MAX="${CGROUP_V2_MAX:-/sys/fs/cgroup/memory.max}"
CGROUP_V1_LIMIT="${CGROUP_V1_LIMIT:-/sys/fs/cgroup/memory/memory.limit_in_bytes}"
CGROUP_V2_CURRENT="${CGROUP_V2_CURRENT:-/sys/fs/cgroup/memory.current}"
CGROUP_V1_USAGE="${CGROUP_V1_USAGE:-/sys/fs/cgroup/memory/memory.usage_in_bytes}"

# --- Helpers ---

# Get PIDs listening on a specific port using ss (primary) or lsof (fallback).
# Args: $1 = port number
# Stdout: one PID per line (may be empty).
get_pids_on_port() {
  local port="$1"
  local pids=""

  if command -v ss >/dev/null 2>&1; then
    # ss -tlnp shows listening TCP sockets with process info.
    # Output format includes "pid=NNNN" in the process column.
    pids=$(ss -tlnp "sport = :${port}" 2>/dev/null \
      | grep -oP 'pid=\K[0-9]+' 2>/dev/null || true)
  fi

  if [ -z "$pids" ] && command -v lsof >/dev/null 2>&1; then
    pids=$(lsof -ti ":${port}" -sTCP:LISTEN 2>/dev/null || true)
  fi

  # Deduplicate and print.
  if [ -n "$pids" ]; then
    echo "$pids" | sort -u
  fi
}

# Check if a port has a listening process.
# Args: $1 = port number
# Returns: 0 if listening, 1 if not.
port_is_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnp "sport = :${port}" 2>/dev/null | grep -q "LISTEN" 2>/dev/null && return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti ":${port}" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  fi
  return 1
}

# Get available memory in kB, accounting for cgroup limits in containers.
# Returns: the lesser of MemAvailable and cgroup headroom (if available).
get_available_memory_kb() {
  local mem_available_kb=0
  local cgroup_headroom_kb=""

  # Read MemAvailable from /proc/meminfo.
  if [ -f "$PROC_MEMINFO" ]; then
    mem_available_kb=$(grep -i '^MemAvailable:' "$PROC_MEMINFO" \
      | awk '{print $2}' || echo "0")
  fi

  # Check cgroup v2 first, then v1.
  if [ -f "$CGROUP_V2_MAX" ] && [ -f "$CGROUP_V2_CURRENT" ]; then
    local cgroup_max cgroup_current
    cgroup_max=$(cat "$CGROUP_V2_MAX" 2>/dev/null || echo "max")
    cgroup_current=$(cat "$CGROUP_V2_CURRENT" 2>/dev/null || echo "0")
    if [ "$cgroup_max" != "max" ] && [ "$cgroup_max" != "0" ]; then
      # Convert bytes to kB.
      cgroup_headroom_kb=$(( (cgroup_max - cgroup_current) / 1024 ))
    fi
  elif [ -f "$CGROUP_V1_LIMIT" ] && [ -f "$CGROUP_V1_USAGE" ]; then
    local cgroup_limit cgroup_usage
    cgroup_limit=$(cat "$CGROUP_V1_LIMIT" 2>/dev/null || echo "0")
    cgroup_usage=$(cat "$CGROUP_V1_USAGE" 2>/dev/null || echo "0")
    # cgroup v1 uses a very large number (like 2^63) for "unlimited".
    if [ "$cgroup_limit" -lt 9000000000000000 ] 2>/dev/null && [ "$cgroup_limit" -gt 0 ]; then
      cgroup_headroom_kb=$(( (cgroup_limit - cgroup_usage) / 1024 ))
    fi
  fi

  # Return the lesser of MemAvailable and cgroup headroom.
  # Clamp negative headroom (overcommit) to 0.
  if [ -n "$cgroup_headroom_kb" ] && [ "$cgroup_headroom_kb" -lt 0 ] 2>/dev/null; then
    cgroup_headroom_kb=0
  fi
  if [ -n "$cgroup_headroom_kb" ] && [ "$cgroup_headroom_kb" -lt "$mem_available_kb" ] 2>/dev/null; then
    echo "$cgroup_headroom_kb"
  else
    echo "$mem_available_kb"
  fi
}

# --- Subcommands ---

cmd_check() {
  local failures=()

  # Check 1: Dev server reachable on expected port (3000 or 3001).
  local dev_server_up=0
  for port in 3000 3001; do
    if port_is_listening "$port"; then
      dev_server_up=1
      break
    fi
  done
  if [ "$dev_server_up" = "0" ]; then
    failures+=("dev-server: no process listening on port 3000 or 3001")
  fi

  # Check 2: Supabase healthy via supabase-bootstrap.sh status.
  if [ -f "$SUPABASE_BOOTSTRAP" ]; then
    local sb_status
    sb_status=$(bash "$SUPABASE_BOOTSTRAP" status 2>/dev/null || echo "error")
    if [ "$sb_status" != "running" ]; then
      failures+=("supabase: status is '$sb_status' (expected 'running')")
    fi
  else
    failures+=("supabase: bootstrap script not found at $SUPABASE_BOOTSTRAP")
  fi

  # Check 3: Memory headroom >= 1GB.
  local avail_kb
  avail_kb=$(get_available_memory_kb)
  if [ "$avail_kb" -lt "$MEMORY_THRESHOLD_KB" ] 2>/dev/null; then
    local avail_mb=$(( avail_kb / 1024 ))
    local threshold_mb=$(( MEMORY_THRESHOLD_KB / 1024 ))
    failures+=("memory: ${avail_mb}MB available, need ${threshold_mb}MB (Turbopack peak ~800MB)")
  fi

  # Check 4: No zombie processes on monitored ports.
  local zombie_ports=""
  for port in $MONITORED_PORTS; do
    local pids
    pids=$(get_pids_on_port "$port")
    if [ -n "$pids" ]; then
      while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        # Check if process is a zombie (state Z in /proc/<pid>/status).
        if [ -f "/proc/$pid/status" ]; then
          local state
          state=$(grep '^State:' "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "")
          if [ "$state" = "Z" ]; then
            zombie_ports+=" $port(pid=$pid)"
          fi
        fi
      done <<< "$pids"
    fi
  done
  if [ -n "$zombie_ports" ]; then
    failures+=("zombies: zombie processes on ports:${zombie_ports}")
  fi

  # Report.
  if [ "${#failures[@]}" -gt 0 ]; then
    echo "UNHEALTHY: ${#failures[@]} check(s) failed"
    for f in "${failures[@]}"; do
      echo "  - $f"
    done
    return 1
  else
    echo "HEALTHY: all 4 checks passed"
    return 0
  fi
}

cmd_recover() {
  local recovered=0
  local failed=0

  for port in $MONITORED_PORTS; do
    local pids
    pids=$(get_pids_on_port "$port")
    if [ -z "$pids" ]; then
      continue
    fi

    while IFS= read -r pid; do
      [ -z "$pid" ] && continue

      # Only kill zombie processes (state Z in /proc/<pid>/status).
      if [ -f "/proc/$pid/status" ]; then
        local state
        state=$(grep '^State:' "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "")
        if [ "$state" != "Z" ]; then
          continue
        fi
      else
        # Can't verify process state — skip rather than kill blindly.
        continue
      fi

      # Protect the current session's dev server.
      if [ -n "$DEV_SERVER_PID" ] && [ "$pid" = "$DEV_SERVER_PID" ]; then
        echo "skip: PID $pid on port $port is the current session's dev server"
        continue
      fi

      # Attempt kill.
      if kill -9 "$pid" 2>/dev/null; then
        echo "killed: PID $pid on port $port"
        recovered=1
      else
        echo "failed: could not kill PID $pid on port $port"
        failed=1
      fi
    done <<< "$pids"
  done

  if [ "$failed" = "1" ]; then
    echo "recover: some processes could not be killed"
    return 1
  elif [ "$recovered" = "1" ]; then
    echo "recover: zombie processes killed successfully"
    return 0
  else
    echo "recover: no zombie processes found on monitored ports"
    return 0
  fi
}

# --- CLI dispatch ---

case "${1:-}" in
  check)
    cmd_check
    ;;
  recover)
    cmd_recover
    ;;
  *)
    echo "Usage: $0 {check|recover}" >&2
    exit 64
    ;;
esac
