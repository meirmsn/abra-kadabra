#!/usr/bin/env bash
# Devshop injection — runs as root via sudo on every container start.
# Also called from .husky/pre-commit if symlinks are missing (git ops can lose them).
# Symlinks devshop infrastructure from /devshop into /workspace so
# Claude Code sees it, but git doesn't track it (gitignored in project repo).
#
# Security role: this script is the mechanism that prevents Claude from
# trivially escalating via sudo. It reads DEVCONTAINER_ROOT_PASSWORD from
# .devcontainer/.env, sets root/node passwords, configures sudo with password
# requirement (replaces default passwordless sudo), and locks all security-
# critical files to root ownership (chown root:root + chmod 644).

set -euo pipefail
trap 'echo "init-devshop.sh FAILED at line $LINENO (exit $?): $(sed -n "${LINENO}p" "$0")" >&2' ERR

DEVSHOP=/devshop
WS=/workspace

# --- Password setup ---
# Tolerant of a missing key: without DEVCONTAINER_ROOT_PASSWORD the script
# falls back to the Dockerfile's default (node has NOPASSWD only on the two
# whitelisted init scripts). cut -f2- preserves '=' chars inside the password.
if [ -f "$WS/.devcontainer/.env" ]; then
  ROOT_PASSWORD=$(grep '^DEVCONTAINER_ROOT_PASSWORD=' "$WS/.devcontainer/.env" 2>/dev/null | cut -d= -f2- || true)
  if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "node:$ROOT_PASSWORD" | chpasswd
    echo "node ALL=(ALL:ALL) ALL" > /etc/sudoers.d/node
    chmod 0440 /etc/sudoers.d/node
  else
    printf '\033[1;33m⚠ DEVCONTAINER_ROOT_PASSWORD not set in %s — sudo limited to init-firewall.sh + init-devshop.sh. Add DEVCONTAINER_ROOT_PASSWORD=<value> to enable full sudo.\033[0m\n' "$WS/.devcontainer/.env" >&2
  fi
fi

# --- Devshop GitHub token ---
# Reads GITHUB_TOKEN (or GH_TOKEN) from devshop .env → exports as DEVSHOP_GITHUB_TOKEN
# via /etc/devshop-env. release.sh sources this to push and create GitHub releases.
# SSH remote stays untouched — release.sh constructs a transient HTTPS URL for push.
if [ -f "$DEVSHOP/.devcontainer/.env" ]; then
  _TOKEN=$(grep -E '^(GH_TOKEN|GITHUB_TOKEN)=' "$DEVSHOP/.devcontainer/.env" 2>/dev/null | head -1 | cut -d= -f2 || true)
  _TOKEN=$(echo "$_TOKEN" | tr -d "\"'" || true)
  if [ -n "$_TOKEN" ]; then
    echo "DEVSHOP_GITHUB_TOKEN=$_TOKEN" > /etc/devshop-env
    chmod 644 /etc/devshop-env
  fi
  unset _TOKEN
fi

# --- Devshop-self guard ---
# When the workspace IS the devshop (opened directly in VS Code as a devcontainer),
# skip injection. kit/ is a real directory in the devshop repo but always
# a symlink (.devshopkit) in project repos. Without this guard, symlink creation
# would replace the real kit/ directory with a self-referential symlink (destructive).
if [ -d "$WS/kit" ] && [ ! -L "$WS/kit" ]; then
  # cwd must be $WS, not $DEVSHOP. In devshop-self mode both paths bind to the
  # same host folder but are distinct Linux mounts; pnpm derives storeDir from
  # the cwd's mount point and records it in node_modules/.modules.yaml. Running
  # from $DEVSHOP records /devshop/.pnpm-store/v10; postCreateCommand later runs
  # from $WS and records /workspace/.pnpm-store/v10. The mismatch triggers the
  # "modules directory will be removed and reinstalled" prompt on every rebuild.
  #
  # CI=true also bypasses the prompt entirely as a belt-and-braces guard:
  # pnpm 10.16.0+ (PR #9960) enforces a real keypress for the modules-purge
  # confirmation, but `su node -c` calls setsid() and strips the controlling
  # terminal — raw-mode keypresses can't reach pnpm even though stdin's fd
  # looks like a TTY, so Enter never registers and the rebuild hangs.
  (cd "$WS" && su node -c 'CI=true pnpm install --frozen-lockfile 2>/dev/null || CI=true pnpm install') || true
  # Lock essentials even in devshop-self mode (prevents security freshness warnings)
  for f in "$WS/.claude/settings.json" "$WS/.dcg.toml"; do
    if [ -e "$f" ] && [ "$(stat -c '%U:%G %a' "$f")" != "root:root 644" ]; then
      chown root:root "$f" && chmod 644 "$f"
    fi
  done
  exit 0
fi

# --- Create devshop symlinks ---
# Extracted to create-devshop-symlinks.sh so it can also be called from
# session-start.sh and .husky/pre-commit when symlinks are lost by git ops.
DEVSHOP="$DEVSHOP" WS="$WS" bash "$DEVSHOP/kit/scripts/sync/create-devshop-symlinks.sh"

# --- Copy security-critical files (real files, not symlinks) ---
# Symlinks are fragile: git ops delete them, node can replace them.
# Root-owned copies survive git ops and can't be modified by node.
# Freshness is checked by check-security-files-freshness.sh in pre-commit.
# Devshop settings.json uses kit/ paths (works from /devshop/ cwd).
# Workspace copy needs .devshopkit/ paths (works from /workspace/ cwd).
# Hooks run from the shell's cwd, which differs per repo.
[ -L "$WS/.claude/settings.json" ] && rm "$WS/.claude/settings.json"
bash "$DEVSHOP/kit/scripts/sync/normalize-devshop-paths.sh" < "$DEVSHOP/.claude/settings.json" > "$WS/.claude/settings.json"

[ -L "$WS/.dcg.toml" ] && rm "$WS/.dcg.toml"
[ -f "$DEVSHOP/.dcg.toml" ] && cp "$DEVSHOP/.dcg.toml" "$WS/.dcg.toml"


# --- Claude memory symlink ---
# Claude writes memories to ~/.claude/projects/-workspace/memory/ (native path).
# Symlink redirects to /workspace/.claude/memory/ so memories are tracked in git.
# .gitignore uses ".claude/*" + "!.claude/memory/" to track only the memory dir.
MEMORY_DIR="$WS/.claude/memory"
MEMORY_LINK="/home/node/.claude/projects/-workspace/memory"
mkdir -p "$MEMORY_DIR" "$(dirname "$MEMORY_LINK")"
chown -R node:node /home/node/.claude/projects
ln -sfn "$MEMORY_DIR" "$MEMORY_LINK"
chown -h node:node "$MEMORY_LINK"

# --- Gstack projects symlink ---
# containerEnv sets GSTACK_HOME=/workspace/.gstack so skills that honor it write
# to the volume-mounted, git-tracked tree. Five gstack skills (canary, ship,
# land-and-deploy, plan-ceo-review, plan-design-review) hardcode
# ~/.gstack/projects/$SLUG/... instead. Without a redirect their artifacts
# (design docs, ceo-plans, review HTML/PNG/JSON) land in /home/node/.gstack/
# which is NOT volume-mounted — wiped on every container rebuild.
# Editing the in-tree gstack SKILL.md.tmpl files is forbidden (CLAUDE.md §
# gstack — /gstack-upgrade wipes local edits with no warning), so the fix
# lives here: symlink /home/node/.gstack/projects → /workspace/.gstack/projects
# so both write paths converge on one git-tracked location.
GSTACK_PROJECTS_DIR="$WS/.gstack/projects"
GSTACK_PROJECTS_LINK="/home/node/.gstack/projects"
mkdir -p "$GSTACK_PROJECTS_DIR"
chown -R node:node "$WS/.gstack"
# One-time migration if a prior session created a real ~/.gstack/projects dir.
if [ -d "$GSTACK_PROJECTS_LINK" ] && [ ! -L "$GSTACK_PROJECTS_LINK" ]; then
  cp -an "$GSTACK_PROJECTS_LINK"/. "$GSTACK_PROJECTS_DIR"/ 2>/dev/null || true
  rm -rf "$GSTACK_PROJECTS_LINK"
fi
mkdir -p "$(dirname "$GSTACK_PROJECTS_LINK")"
ln -sfn "$GSTACK_PROJECTS_DIR" "$GSTACK_PROJECTS_LINK"
chown -h node:node "$GSTACK_PROJECTS_LINK"
chown -R node:node /home/node/.gstack

# --- Install devshop dependencies (husky, lint-staged, prettier, eslint, etc.) ---
# Runs on every start so deps stay current when devshop is updated from another project.
# Fast no-op when lockfile and node_modules are in sync.
# CI=true bypasses pnpm's interactive modules-purge prompt — `su node -c` strips
# the controlling terminal, so raw-mode keypresses can't reach pnpm. See the
# devshop-self branch above for the full rationale + pnpm PR #9960 reference.
(cd "$DEVSHOP" && su node -c 'CI=true pnpm install --frozen-lockfile 2>/dev/null || CI=true pnpm install') || true

# --- Populate Playwright cache stubs (Chromium symlinks) ---
# Devcontainers apt-install /usr/bin/chromium and export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
# but Playwright's launch path checks ~/.cache/ms-playwright/<rev>/ BEFORE honoring the env
# override — an empty cache produces "Please run `npx playwright install`" even with a
# system Chromium present. Stub the cache so headless-browser skills (/qa, /design-review,
# /benchmark, /canary, /ak-pre-ship Phase 0) work on first invocation without operators
# having to know to run the script manually.
#
# Must run as node (cache lives under /home/node/.cache/). Idempotent: re-running on
# every container start is a fast no-op once stubs exist. Discovers required revisions
# from each playwright-core/browsers.json under $WS and $DEVSHOP/.claude/skills/gstack;
# warns and exits 0 when no browsers.json is found yet (first container start before
# project pnpm install) — next start picks them up automatically.
(cd "$WS" && su node -c 'bash /devshop/kit/scripts/populate-playwright-cache.sh' 2>/dev/null) || true

# --- Lock security-critical files (root-owned, world-readable, not writable by node) ---
# Two layers: (1) deny rules in settings.json block Edit/Write tools,
# (2) chown root:root + chmod 644 blocks Bash workarounds.
# To edit any of these: sudo nano <file>
#
# Workspace [locked] files (template-derived) are sourced from kit/manifest.txt
# via the shared parser at kit/scripts/sync/lib/parse-manifest.sh — single source
# of truth. install -m <src_mode> -o root -g root atomically refreshes content +
# chowns + chmods per-file. Mode comes from the template source so executable
# entries (compose-isolation init-host-env.sh + supabase-runner/cmd-relay.mjs,
# both 755 in template/) keep their exec bit while config files (644) stay 644.
# A new template/<file> propagates on the next container start without a
# parallel hardcoded list (this is the .husky/pre-push fix).
#
# The refresh + lock steps are content/ownership-conditional, not unconditional.
# The install runs only when cmp -s reports the destination differs (or is
# missing) — the install is the script's only mtime-bumping write, so gating it
# stops VS Code's spurious "Configuration file(s) changed — Rebuild?" prompt
# from re-arming on every container start. Every chown/chmod lock step below
# (the manifest content-match branch, the firewall-extras lock, the devshop-self
# for-loop, and the recursive find over every kit script) runs only when the
# stat -c '%U:%G %a' tuple has drifted from the desired root:root <mode>; an
# already-locked file is skipped, eliminating redundant per-boot ctime churn
# while still recovering ownership a git op eroded.
#
# Devshop-self locks (the $DEVSHOP/... and $DEVSHOP/template/... lists below) and
# project-only locks (settings.json, settings.local.json, .dcg.toml, .env,
# .claude dir) stay hardcoded — they're devshop-bootstrap or operator-secret
# files outside the project-workspace lifecycle the manifest describes.
#
# See kit/docs/guide/architecture.md § File lifecycle for the model.

# Manifest-driven [locked] files: refresh content from template/ + chown root.
# Skips entries whose template source is absent — host-supabase / skip projects
# don't carry the compose-isolation files and the missing-source guard keeps
# the loop silent.
source "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"
parse_manifest "$DEVSHOP/kit/manifest.txt"
while IFS= read -r path; do
  [ -z "$path" ] && continue
  src="$DEVSHOP/template/$path"
  dst="$WS/$path"
  if [ -f "$src" ]; then
    src_mode=$(stat -c '%a' "$src")
    if ! cmp -s "$src" "$dst"; then
      # Content differs (or dst missing — cmp -s exits 2). Full refresh:
      # rewrites content + sets owner/mode atomically. This is the only
      # mtime-bumping write in the script, so gating it stops VS Code's
      # spurious "Configuration file(s) changed" rebuild prompt re-arming.
      install -D -m "$src_mode" -o root -g root "$src" "$dst"
    else
      # Content already matches — skip the install (no mtime bump). Still
      # recover ownership/mode if a git op eroded them (the security re-lock).
      if [ "$(stat -c '%U:%G %a' "$dst")" != "root:root $src_mode" ]; then
        chown root:root "$dst" && chmod "$src_mode" "$dst"
      fi
    fi
  fi
done < <(manifest_paths_by locked)

# Project-firewall-extras seed + lock (bespoke; not via manifest annotation).
# Seed from /devshop/template/.devcontainer/firewall-extra-domains if missing
# in workspace (operator-owned thereafter; init-firewall.sh reads it at runtime).
# chown root:root 644 on every start so node (Claude / npm) cannot modify;
# operator with sudo can edit.
FWE_SRC="$DEVSHOP/template/.devcontainer/firewall-extra-domains"
FWE_DST="$WS/.devcontainer/firewall-extra-domains"
if [ -f "$FWE_SRC" ] && [ ! -e "$FWE_DST" ]; then
  install -D -m 644 -o root -g root "$FWE_SRC" "$FWE_DST"
fi
if [ -e "$FWE_DST" ] && [ "$(stat -c '%U:%G %a' "$FWE_DST")" != "root:root 644" ]; then
  chown root:root "$FWE_DST" && chmod 644 "$FWE_DST"
fi

# Manifest-driven [locked-dir]s: sticky bit on workspace dirs.
while IFS= read -r d; do
  [ -z "$d" ] && continue
  [ -d "$WS/$d" ] && chmod 1755 "$WS/$d"
done < <(manifest_paths_by locked-dir)

# Devshop-self + project-special locks (NOT in manifest by design):
#   settings.json        — copied via normalize-devshop-paths.sh above; not template-derived
#   settings.local.json  — operator-created additional permissions; project-only
#   .dcg.toml            — copied from $DEVSHOP/.dcg.toml above; not template-derived
#   .devcontainer/.env   — operator-created secrets; project-only
#   $DEVSHOP/...         — devshop-self bootstrap protection
#   $DEVSHOP/template/...— template-source integrity (read by ak-new-project)
for f in \
  "$WS/.claude/settings.json" \
  "$WS/.claude/settings.local.json" \
  "$WS/.dcg.toml" \
  "$WS/.devcontainer/.env" \
  "$DEVSHOP/kit/scripts/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/devcontainer.json" \
  "$DEVSHOP/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/.devcontainer/Dockerfile" \
  "$DEVSHOP/.devcontainer/checksums.sha256" \
  "$DEVSHOP/.devcontainer/.env" \
  "$DEVSHOP/.husky/pre-commit" \
  "$DEVSHOP/.husky/pre-push" \
  "$DEVSHOP/.husky/prepare-commit-msg" \
  "$DEVSHOP/template/.devcontainer/devcontainer.json" \
  "$DEVSHOP/template/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/template/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/template/.devcontainer/Dockerfile" \
  "$DEVSHOP/template/.devcontainer/checksums.sha256" \
  "$DEVSHOP/template/.devcontainer/firewall-extra-domains" \
  "$DEVSHOP/template/.husky/pre-commit" \
  "$DEVSHOP/template/.husky/pre-push" \
  "$DEVSHOP/template/.husky/prepare-commit-msg" \
  "$DEVSHOP/.claude/settings.json" \
  "$DEVSHOP/.dcg.toml" \
  ; do
  if [ -e "$f" ] && [ "$(stat -c '%U:%G %a' "$f")" != "root:root 644" ]; then
    chown root:root "$f" && chmod 644 "$f"
  fi
done
# Lock all devshop scripts (recursive — covers root + subfolders like
# preship/, commit-hooks/, sync/; future scripts are auto-protected)
find "$DEVSHOP/kit/scripts/" -type f -name '*.sh' -print0 | \
  while IFS= read -r -d '' f; do
    if [ "$(stat -c '%U:%G %a' "$f")" != "root:root 644" ]; then
      chown root:root "$f" && chmod 644 "$f"
    fi
  done

# Sticky bit on dirs not covered by manifest [locked-dir] (devshop-self + .claude).
# Workspace [locked-dir]s (.husky, .devcontainer) are handled by the manifest
# loop above. .claude is project-special: it contains symlinks (skills, commands)
# and locked copies (settings.json) but isn't in template/, so it stays here.
for d in \
  "$WS/.claude" \
  "$DEVSHOP/.claude" \
  "$DEVSHOP/.devcontainer" \
  "$DEVSHOP/.husky" \
  "$DEVSHOP/template/.devcontainer" \
  "$DEVSHOP/template/.husky" \
  ; do
  [ -d "$d" ] && chmod 1755 "$d"
done

# --- Derive Supabase ports from config.toml (backstop) ---
# initializeCommand runs derive-ports-from-config.sh on the HOST before
# compose-up. This backstop re-runs it inside the container so mid-session
# edits to supabase/config.toml are picked up on the next container start
# without relying solely on the host-side pass. Runs as root (this script's
# context) so it can write to the locked .devcontainer/.env.
DERIVE_SCRIPT=$WS/.devcontainer/derive-ports-from-config.sh
if [ -f "$DERIVE_SCRIPT" ]; then
  bash "$DERIVE_SCRIPT" "$WS" || true
fi
