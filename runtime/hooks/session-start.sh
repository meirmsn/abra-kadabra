#!/usr/bin/env bash
# This devshop version's own SessionStart step (the plugin's dispatcher runs it): points the
# project's git at the devshop's hooks, /opt/devshop-current/git-hooks, and keeps the project's own
# core.hooksPath in devshop.chainHooksPath, so the project's hooks still run, chained after the
# devshop's. Session-local git config in this clone; nothing is committed. Feedback, not a wall:
# the agent can change it back, and required CI runs the same checks.
hooks=/opt/devshop-current/git-hooks
proj=${CLAUDE_PROJECT_DIR:-.}

# The plugin's Bash guard (hooks/pre-bash.sh) fails closed, so without dcg every Bash command is
# blocked. Say so now, not at the first blocked command. A plugin from before the guard doesn't
# register it, so a missing dcg blocks nothing there.
if grep -q 'hooks/pre-bash\.sh' /opt/devshop-plugin/devshop/hooks/hooks.json 2>/dev/null \
  && [ ! -x /opt/devshop-tools/bin/dcg ]; then
  echo "DEVSHOP: dcg is not installed (/opt/devshop-tools/bin/dcg), so every Bash command will be blocked this session; rebuild the environment (setup log: /tmp/devshop-setup.log)"
fi

git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 || exit 0
top=$(git -C "$proj" rev-parse --show-toplevel)

# The repo's declared session setup (e.g. `npm ci` for its pinned tools), so its checks can run. The
# repo's own code, like its tests and lint scripts; silent when it works, loud when it fails.
if [ -x "$top/scripts/setup.sh" ]; then
  (cd "$top" && timeout 600 scripts/setup.sh) >/tmp/devshop-project-setup.log 2>&1 \
    || echo "DEVSHOP: the project's setup (scripts/setup.sh) failed (exit $?); its checks may not run: see /tmp/devshop-project-setup.log"
fi

# The project's CI in two tiers, fast and slow, as the devshop's template has it (spec
# specs/ci-fast-slow-tiers.md). Feedback that reaches the owner, not a wall: required CI is.
tmpl=/opt/devshop-current/templates/ci.yml
ci="$top/.github/workflows/ci.yml"
if [ ! -f "$ci" ]; then
  echo "DEVSHOP: the project has no CI (.github/workflows/ci.yml); start from the devshop's two-tier template, $tmpl"
else
  found=$(timeout 30 /opt/devshop-current/scripts/ci-tiers-check.py "$ci" 2>&1)
  rc=$?
  case $rc in
    0) ;;
    1) echo "DEVSHOP: the project's CI doesn't follow the two tiers (fast, slow) of $tmpl: $(grep -v 'the two-tier shape is' <<<"$found" | sed 's/^ci-tiers-check: [^:]*: //' | paste -sd ';' - | sed 's/;/; /g')" ;;
    *) echo "DEVSHOP: couldn't check the project's CI against $tmpl (exit $rc): $(head -1 <<<"$found")" ;;
  esac
fi

# The project's copies of devshop-owned files (the version's project-files.txt, W10.4.7) against the
# version it pins. Only with a pin: without one there is no agreed version, and the default (HEAD of
# the local copy) would report every devshop change as drift. Feedback, not a wall.
if [ -f "$top/.devshop-version" ]; then
  pin=$(tr -d '[:space:]' <"$top/.devshop-version")
  found=$(timeout 30 /opt/devshop-current/scripts/project-files.py check --devshop-git /opt/devshop.git \
    --version "$pin" --project "$top" 2>&1)
  rc=$?
  case $rc in
    0 | 3) ;;
    1) echo "DEVSHOP: the project's copies of devshop files differ from its pinned version ${pin:0:12}: $(sed -E 's/^([^:]*): (.*)$/\1 (\2)/' <<<"$found" | paste -sd ';' - | sed 's/;/; /g'); the devshop-upgrade skill shows each delta" ;;
    *) echo "DEVSHOP: couldn't check the project's copies of devshop files (exit $rc): $(head -1 <<<"$found")" ;;
  esac
fi

cur=$(git -C "$proj" config --get core.hooksPath)
[ "$cur" = "$hooks" ] && exit 0
if git -C "$proj" config --get devshop.chainHooksPath >/dev/null; then
  echo "DEVSHOP: core.hooksPath had been changed to '${cur:-git default}' after the devshop set it; set back to the devshop's hooks"
else
  git -C "$proj" config devshop.chainHooksPath "$cur"
fi
git -C "$proj" config core.hooksPath "$hooks" \
  || echo "DEVSHOP: couldn't point core.hooksPath at $hooks; the devshop's git hooks won't run"
exit 0
