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
pinned="$top/.devshop-version"
if [ ! -f "$ci" ] && [ ! -f "$pinned" ]; then
  # Neither the pin nor CI: a repo the devshop hasn't set up (specs/project-contract.md).
  echo "DEVSHOP: no devshop files yet (.devshop-version, .github/workflows/ci.yml): a new project is set up by /devshop:new-project"
elif [ -f "$ci" ]; then
  found=$(timeout 30 /opt/devshop-current/scripts/ci-tiers-check.py "$ci" 2>&1)
  rc=$?
  case $rc in
    0) ;;
    1) echo "DEVSHOP: the project's CI doesn't follow the two tiers (fast, slow) of $tmpl: $(grep -v 'the two-tier shape is' <<<"$found" | sed 's/^ci-tiers-check: [^:]*: //' | paste -sd ';' - | sed 's/;/; /g')" ;;
    *) echo "DEVSHOP: couldn't check the project's CI against $tmpl (exit $rc): $(head -1 <<<"$found")" ;;
  esac
fi

# The project contract (this version's project-contract.txt, spec specs/project-contract.md): every
# item the devshop relies on, checked with the version's own copy of the check, so a project missing
# its copy is still checked. Items a stack home `supplies` are required when the stack applies. Only
# with a pin, as for the copies below: a repo with no pin has no agreed contract version. Required
# items missing or malformed: one DEVSHOP: line. Absent optional items: one plain line, for Claude.
# Feedback, not a wall: the project's own fast tier runs the same check in CI.
if [ -f "$pinned" ]; then
  supplies=()
  if homes=$(/opt/devshop-current/scripts/stack-homes.sh "$top" 2>&1); then
    while IFS= read -r home; do
      [ -f "$(dirname "$home")/supplies" ] && supplies+=(--supplies "$(dirname "$home")/supplies")
    done < <(tail -n +2 <<<"$homes")
    found=$(timeout 30 /opt/devshop-current/scripts/contract-check.py --contract /opt/devshop-current/project-contract.txt \
      --project "$top" "${supplies[@]}" 2>&1)
    rc=$?
  else
    found="the stack homes couldn't be read (stack-homes.sh): $(head -1 <<<"$homes")"
    rc=2
  fi
  case $rc in
    0 | 1)
      absent=$(grep '^absent (optional): ' <<<"$found" | sed 's/^absent (optional): //' | paste -sd ',' - | sed 's/,/, /g')
      [ -z "$absent" ] || echo "contract: optional items this project doesn't have: $absent (scripts/contract-check.py --list says what each is for)"
      problems=$(grep -v '^absent (optional): ' <<<"$found" | grep . | sed -E 's/^([^:]*): ([^;]*).*$/\1 (\2)/' | paste -sd ';' - | sed 's/;/; /g')
      [ -z "$problems" ] || echo "DEVSHOP: the project doesn't meet the project contract: $problems; the contract is scripts/project-contract.txt in the project (scripts/contract-check.py --list)"
      ;;
    *) echo "DEVSHOP: couldn't check the project against the project contract (exit $rc): $(head -1 <<<"$found")" ;;
  esac
fi

# The project's copies of devshop-owned files (the version's project-files.txt, W10.4.7) against the
# version it pins. Only with a pin: without one there is no agreed version, and the default (HEAD of
# the local copy) would report every devshop change as drift. Feedback, not a wall.
if [ -f "$top/.devshop-version" ]; then
  pin=$(tr -d '[:space:]' <"$top/.devshop-version")
  label=$pin # a release tag in full, a commit SHA as 12 characters
  [[ ! $pin =~ ^[0-9a-f]{40}$ ]] || label=${pin:0:12}
  found=$(timeout 30 /opt/devshop-current/scripts/project-files.py check --devshop-git /opt/devshop.git \
    --version "$pin" --project "$top" 2>&1)
  rc=$?
  case $rc in
    0 | 3) ;;
    1) echo "DEVSHOP: the project's copies of devshop files differ from its pinned version $label: $(sed -E 's/^([^:]*): (.*)$/\1 (\2)/' <<<"$found" | paste -sd ';' - | sed 's/;/; /g'); the upgrade skill (/devshop:upgrade) shows each delta" ;;
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
