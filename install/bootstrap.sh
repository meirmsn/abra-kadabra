#!/usr/bin/env bash
# Installs the devshop into a cloud environment (D-01 D). The root bootstrap.sh runs this right after
# the environment's setup script cloned the devshop into /opt/devshop.git. Usage: bootstrap.sh [ref]
# (default HEAD = main as cloned): the ref whose plugin is installed and which is the default version
# for projects without .devshop-version. Never prompts; every step runs even if an earlier one failed,
# and each failure is logged and makes the exit status non-zero (L-43). Log: /tmp/devshop-setup.log.
set -uo pipefail
MIRROR=/opt/devshop.git
VERSIONS=/opt/devshop-versions
PLUGIN=/opt/devshop-plugin
REF=${1:-HEAD}
LOG=/tmp/devshop-setup.log
failed=0
log() { echo "[$(date -u +%T)] $*" >>"$LOG"; }
step_failed() { log "FAILED: $*"; failed=1; }

log "bootstrap start ref=$REF copy-head=$(git --git-dir="$MIRROR" rev-parse --short "$REF" 2>&1)"

# The setup script clones with the token in the URL: keep the URL it used (no hard-coded account,
# L-01) but drop the credentials, so the token isn't left in the copy's config.
url=$(git --git-dir="$MIRROR" config --get remote.origin.url) || step_failed "no remote URL in $MIRROR"
clean=$(printf '%s' "${url:-}" | sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@#\1#')
[ -z "$clean" ] || git --git-dir="$MIRROR" remote set-url origin "$clean" || step_failed "remote set-url"

mkdir -p "$VERSIONS" || step_failed "mkdir $VERSIONS"
echo "$REF" >"$VERSIONS/default-ref" || step_failed "write default-ref"
# When the local copy was made: every DEVSHOP: line shows its age, since it refreshes only when the
# environment cache rebuilds.
date -u +%FT%TZ >"$VERSIONS/copy-date" || step_failed "write copy-date"

{ rm -rf "$PLUGIN" && mkdir -p "$PLUGIN"; } || step_failed "mkdir $PLUGIN"
git --git-dir="$MIRROR" archive "$REF:install/plugin" | tar -x -C "$PLUGIN" 2>>"$LOG" \
  || step_failed "extract install/plugin at $REF"

# Prime /opt/devshop-current with the default version, so the cached environment has one even
# before the first session; priming doesn't run the version's own session-start script.
DEVSHOP_PRIME_ONLY=1 CLAUDE_PROJECT_DIR=/nonexistent bash "$PLUGIN/devshop/hooks/dispatch.sh" >>"$LOG" 2>&1 \
  || step_failed "prime /opt/devshop-current"

claude plugin marketplace add "$PLUGIN" --scope user >>"$LOG" 2>&1 || step_failed "claude plugin marketplace add"
claude plugin install devshop@devshop --scope user >>"$LOG" 2>&1 || step_failed "claude plugin install"

# Pinned tools (L-45): each install/tools.pin line is downloaded, checked against its sha256, and
# its binary linked into /opt/devshop-tools/bin, where the devshop's git hooks run it. A bad or
# missing download is a loud failure; the other tools and steps still run (L-43).
TOOLS=/opt/devshop-tools
install_tools() {
  local name version sum url dir tmp bin
  mkdir -p "$TOOLS/bin" || { step_failed "tools: mkdir $TOOLS/bin"; return; }
  while read -r name version sum url; do
    if [[ ! $name =~ ^[a-z0-9-]+$ || ! $sum =~ ^[0-9a-f]{64}$ || ! $url =~ ^https://[^@[:space:]]+$ ]]; then
      step_failed "tool ${name:-?}: install/tools.pin line is not '<name> <version> <sha256> <https URL>'"
      continue
    fi
    dir="$TOOLS/$name-$version" tmp="$TOOLS/$name.download"
    rm -rf "$dir" "$tmp" && mkdir -p "$dir"
    curl -fsSL -o "$tmp" "$url" 2>>"$LOG" || { step_failed "tool $name: download $url"; continue; }
    echo "$sum  $tmp" | sha256sum -c - >/dev/null 2>&1 \
      || { step_failed "tool $name: checksum of $url is not the pinned $sum"; rm -f "$tmp"; continue; }
    { tar -xf "$tmp" -C "$dir" 2>>"$LOG" && rm -f "$tmp"; } || { step_failed "tool $name: unpack $url"; continue; }
    bin=$(find "$dir" -type f -name "$name" -perm -u+x | head -1)
    { [ -n "$bin" ] && ln -sfn "$bin" "$TOOLS/bin/$name"; } || step_failed "tool $name: no executable '$name' in $url"
  done < <(git --git-dir="$MIRROR" show "$REF:install/tools.pin" | grep -v '^#')
}
install_tools

# gstack (TARGET Shape 7): the one upstream commit install/gstack.pin names, installed unmodified
# after the devshop's own steps, so a gstack failure can't stop them. Its setup runs with stdin
# closed, team mode off and its own Claude hooks off, so it leaves ~/.claude/settings.json alone
# (F-GS-08). --no-browser: Chromium installs on a browser skill's first run instead. Setup output:
# /tmp/devshop-gstack.log.
install_gstack() {
  local url sha dir="$HOME/.claude/skills/gstack" glog=/tmp/devshop-gstack.log
  read -r url sha < <(git --git-dir="$MIRROR" show "$REF:install/gstack.pin" | grep -v '^#')
  [[ ${url:-} =~ ^https://[^@[:space:]]+$ && ${sha:-} =~ ^[0-9a-f]{40}$ ]] \
    || { step_failed "gstack: install/gstack.pin at $REF is missing or not '<https URL> <sha>'"; return; }
  log "gstack $sha from $url"
  { rm -rf "$dir" && git init -q "$dir" && git -C "$dir" fetch -q --depth 1 "$url" "$sha" \
    && git -C "$dir" checkout -q --detach FETCH_HEAD; } >>"$glog" 2>&1 \
    || { step_failed "gstack: fetch $sha (see $glog)"; return; }
  # Bun is tied to the pin: the pinned gstack names the Bun it is tested on, and only that one runs.
  local tested found
  tested=$(sed -n 's/^GSTACK_BUN_TESTED="\([^"]*\)"$/\1/p' "$dir/bin/gstack-bun-version.sh" 2>/dev/null)
  found=$(PATH="$HOME/.bun/bin:$PATH" bun --version 2>/dev/null)
  { [ -n "$tested" ] && [ "$found" = "$tested" ]; } \
    || { step_failed "gstack: bun ${found:-not found}, but gstack $sha is tested on bun ${tested:-unknown}"; return; }
  # Its npm dependencies come only from its lockfile. gstack's setup falls back to an unfrozen
  # install when the frozen one fails, so install frozen first and stop here if that fails.
  (cd "$dir" && PATH="$HOME/.bun/bin:$PATH" timeout 600 bun install --frozen-lockfile </dev/null) >>"$glog" 2>&1 \
    || { step_failed "gstack: frozen dependency install (bun.lock vs this bun; see $glog)"; return; }
  (cd "$dir" && PATH="$HOME/.bun/bin:$PATH" timeout 600 ./setup --host claude --no-team \
    --no-plan-tune-hooks --no-timeline-stop-hook --no-browser --quiet </dev/null) >>"$glog" 2>&1 \
    || { step_failed "gstack: setup exited $? (see $glog)"; return; }
  # The pin is the only upgrade path: no "upgrade available" prompts (auto_upgrade is off by default).
  "$dir/bin/gstack-config" set update_check false >>"$glog" 2>&1 \
    || step_failed "gstack: turning off its update check (see $glog)"
}
install_gstack

if [ "$failed" = 0 ]; then
  log "RESULT: bootstrap done (current -> $(readlink /opt/devshop-current))"
else
  log "RESULT: bootstrap FAILED (see FAILED lines above)"
fi
exit "$failed"
