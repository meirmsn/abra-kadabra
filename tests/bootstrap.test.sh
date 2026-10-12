#!/usr/bin/env bash
# Scenario test for the devshop install (D-01 D). Every cloud environment's setup script is:
#   git clone -q --bare https://x-access-token:<token>@github.com/<owner>/<repo>.git /opt/devshop.git || true
#   git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true
# This test replays line 1 as a local bare clone of the committed HEAD (no network) and line 2
# verbatim, then runs the installed plugin's SessionStart hook in a project for every pin case.
# It runs in a private mount namespace with a scratch /opt and /tmp, so the real ones are never
# touched (L-41). Tests the committed HEAD, not uncommitted changes.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
mount -t tmpfs devshop-test-tmp /tmp || fail "can't mount a scratch /tmp"
command -v jq >/dev/null || fail "jq not found"

# The last commit before the install moved out of spikes/ (W10.4.4); a pin to it must stay sane.
PRE_MOVE=6190c0e011c0b14bc4689504ffad935ecf06cf5e
# Where a devshop version keeps its runtime (skills/, hooks/); before the move it was under spikes/.
RUNTIME=runtime

work=$(mktemp -d)
isolate_git "$work"
head=$(git -C "$repo_root" rev-parse HEAD)
git -C "$repo_root" merge-base --is-ancestor "$PRE_MOVE" HEAD 2>/dev/null || fail "pre-move commit $PRE_MOVE is not in HEAD's history (shallow clone? CI needs fetch-depth: 0)"

# The gstack pin at HEAD: one upstream commit (TARGET Shape 7), "<https URL> <40-hex sha>".
gstack_pin_line=$(git -C "$repo_root" show "$head:install/gstack.pin" 2>/dev/null | grep -v '^#') \
  || fail "no install/gstack.pin at HEAD"
read -r gstack_url gstack_sha <<<"$gstack_pin_line"
[[ $gstack_url =~ ^https://[^@]+$ && $gstack_sha =~ ^[0-9a-f]{40}$ ]] \
  || fail "install/gstack.pin: want '<https URL> <40-hex sha>', got '$gstack_pin_line'"

# The devshop's pinned tools at HEAD (L-45): "<name> <version> <sha256> <https URL>" per line, the
# same version and checksum CI pins in ci.yml, so a session and CI run the same binaries.
tools_pin=$(git -C "$repo_root" show "$head:install/tools.pin" 2>/dev/null | grep -v '^#') || fail "no install/tools.pin at HEAD"
ci=$(git -C "$repo_root" show "$head:.github/workflows/ci.yml")
for tool in gitleaks shellcheck; do
  read -r _ version sum url < <(grep "^$tool " <<<"$tools_pin") || fail "install/tools.pin has no $tool line"
  [[ $version =~ ^[0-9.]+$ && $sum =~ ^[0-9a-f]{64}$ && $url =~ ^https://[^@[:space:]]+$ ]] \
    || fail "install/tools.pin: bad $tool line"
  upper=$(tr '[:lower:]' '[:upper:]' <<<"$tool")
  { grep -q "^  ${upper}_VERSION: $version$" <<<"$ci" && grep -q "^  ${upper}_SHA256: $sum$" <<<"$ci"; } \
    || fail "install/tools.pin's $tool ($version, $sum) differs from ci.yml's pin"
done
echo "ok - install/tools.pin pins gitleaks and shellcheck exactly as ci.yml does"

# Fake release downloads: a fake `curl` serves files by the URL's basename from $work/dl, so the
# bootstrap downloads, checks and unpacks them exactly as from GitHub.
mkdir -p "$work/dl" "$work/fk/gitleaks" "$work/fk/shellcheck-v0"
printf '#!/usr/bin/env bash\necho "fake gitleaks $*"\n' >"$work/fk/gitleaks/gitleaks"
printf '#!/usr/bin/env bash\necho "fake shellcheck $*"\n' >"$work/fk/shellcheck-v0/shellcheck"
chmod +x "$work/fk/gitleaks/gitleaks" "$work/fk/shellcheck-v0/shellcheck"
gl_url=$(awk '$1 == "gitleaks" { print $4 }' <<<"$tools_pin")
sc_url=$(awk '$1 == "shellcheck" { print $4 }' <<<"$tools_pin")
tar -czf "$work/dl/${gl_url##*/}" -C "$work/fk/gitleaks" gitleaks
tar -cJf "$work/dl/${sc_url##*/}" -C "$work/fk" shellcheck-v0
fake_tools_pin() { # fake_tools_pin [gitleaks sha]: tools.pin pointing at the fake downloads
  printf 'gitleaks 0.0.1 %s %s\nshellcheck 0.0.1 %s %s\n' \
    "${1:-$(sha256sum "$work/dl/${gl_url##*/}" | cut -d' ' -f1)}" "$gl_url" \
    "$(sha256sum "$work/dl/${sc_url##*/}" | cut -d' ' -f1)" "$sc_url"
}

# A fake upstream gstack, reached through the pin's own URL (git insteadOf in the isolated config,
# so the bootstrap fetches it exactly as from GitHub). Its ./setup records its arguments and
# stdin and adds a skill; a second commit's ./setup fails.
gs="$work/gstack.git"
git init -q --bare "$gs"
git -C "$gs" config uploadpack.allowAnySHA1InWant true
git config --global url."$gs".insteadOf "$gstack_url"
git clone -q "$gs" "$work/gs" 2>/dev/null
# shellcheck disable=SC2016  # the fake setup's source: expands when it runs, not here
{
  echo '#!/usr/bin/env bash'
  echo '{ echo "args: $*"; if [ -t 0 ]; then echo "stdin: tty"; else echo "stdin: $(wc -c) bytes"; fi; } >"$HOME/gstack-setup.args"'
  echo 'mkdir -p "$HOME/.claude/skills/autoplan" && echo fake >"$HOME/.claude/skills/autoplan/SKILL.md"'
} >"$work/gs/setup"
mkdir -p "$work/gs/bin"
# Each gstack commit names the Bun it is tested on, as upstream's bin/gstack-bun-version.sh does.
printf 'GSTACK_BUN_FLOOR="9.0.0"\nGSTACK_BUN_TESTED="9.9.9"\n' >"$work/gs/bin/gstack-bun-version.sh"
# shellcheck disable=SC2016  # the fake gstack-config's source
printf '#!/usr/bin/env bash\necho "$*" >>"$HOME/gstack-config.calls"\n' >"$work/gs/bin/gstack-config"
chmod +x "$work/gs/setup" "$work/gs/bin/gstack-config"
git -C "$work/gs" add -A && git -C "$work/gs" commit -qm "fake gstack" && git -C "$work/gs" push -q origin HEAD:refs/heads/main
gs_good=$(git -C "$work/gs" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho "fake gstack setup failed" >&2\nexit 1\n' >"$work/gs/setup"
git -C "$work/gs" commit -qam "fake gstack, setup fails" && git -C "$work/gs" push -q origin HEAD:refs/heads/broken
gs_broken=$(git -C "$work/gs" rev-parse HEAD)
git -C "$work/gs" checkout -q "$gs_good" && touch "$work/gs/BUN_FAIL"
git -C "$work/gs" add -A && git -C "$work/gs" commit -qm "fake gstack, lockfile drift" && git -C "$work/gs" push -q origin HEAD:refs/heads/drift
gs_drift=$(git -C "$work/gs" rev-parse HEAD)

# A source repo standing in for the devshop on GitHub. Its main is HEAD with only the gstack pin
# changed, to the fake's good commit; that is the commit under test from here on. Two more
# branches pin a gstack whose setup fails and a gstack commit that doesn't exist.
src="$work/src.git"
git init -q --bare "$src"
git -C "$repo_root" push -q "$src" "$head:refs/heads/tested"
git clone -q "$src" "$work/dev" 2>/dev/null
repin() { # repin <gstack sha> <branch>: HEAD with the gstack pin set to <sha>, pushed as <branch>
  git -C "$work/dev" checkout -q --detach "$head"
  printf '%s %s\n' "$gstack_url" "$1" >"$work/dev/install/gstack.pin"
  fake_tools_pin "${3:-}" >"$work/dev/install/tools.pin"
  git -C "$work/dev" commit -qam "pin gstack $1" && git -C "$work/dev" push -q origin "HEAD:refs/heads/$2"
}
repin "$gs_good" main
repin "$gs_broken" gstack-broken
repin "$(rand 'a-f0-9' 40)" gstack-missing
repin "$gs_drift" gstack-drift
repin "$gs_good" tools-bad "$(rand 'a-f0-9' 64)"
# A version that walks out of /opt/devshop-tools is refused before anything is removed or written.
git -C "$work/dev" checkout -q --detach origin/main
sed -i 's|^gitleaks 0.0.1 |gitleaks ../../../escape |' "$work/dev/install/tools.pin"
git -C "$work/dev" commit -qam "bad tool version" && git -C "$work/dev" push -q origin HEAD:refs/heads/tools-badver
git --git-dir="$src" symbolic-ref HEAD refs/heads/main
head=$(git -C "$work/dev" rev-parse origin/main)
marker="PIN-MARKER-$(rand 'a-z0-9' 12)"
git clone -q "$src" "$work/side"
mkdir -p "$work/side/$RUNTIME/hooks"
printf '#!/usr/bin/env bash\necho %s\n' "$marker" >"$work/side/$RUNTIME/hooks/session-start.sh"
chmod +x "$work/side/$RUNTIME/hooks/session-start.sh"
git -C "$work/side" add -A && git -C "$work/side" commit -qm "pinned test version"
git -C "$work/side" push -q origin HEAD:refs/heads/side
pinned=$(git -C "$work/side" rev-parse HEAD)

# A fake `claude` CLI: `plugin marketplace add <dir>` remembers the marketplace, `plugin install
# <plugin>@<marketplace>` copies the plugin's source dir, as the real CLI copies it into its cache.
mkdir -p "$work/bin"
cat >"$work/bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "claude $*" >>"$HOME/claude-calls.log"
case "$1 $2 ${3:-}" in
  "plugin marketplace add")
    m=$(jq -er .name "$4/.claude-plugin/marketplace.json")
    mkdir -p "$HOME/marketplaces" && echo "$4" >"$HOME/marketplaces/$m" ;;
  "plugin install "*)
    p=${3%@*}; m=${3#*@}; dir=$(cat "$HOME/marketplaces/$m")
    s=$(jq -er --arg p "$p" '.plugins[] | select(.name == $p) | .source' "$dir/.claude-plugin/marketplace.json")
    rm -rf "$HOME/plugin" && cp -a "$dir/$s" "$HOME/plugin" ;;
  *) echo "fake claude: unexpected: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/claude"
cat >"$work/bin/curl" <<EOF
#!/usr/bin/env bash
# fake curl: -o <out> <url> → copy $work/dl/<basename of url>
out= url=
while [ \$# -gt 0 ]; do case "\$1" in -o) out=\$2; shift 2 ;; -*) shift ;; *) url=\$1; shift ;; esac; done
[ -f "$work/dl/\${url##*/}" ] || { echo "fake curl: 404 \$url" >&2; exit 22; }
cp "$work/dl/\${url##*/}" "\$out"
EOF
chmod +x "$work/bin/curl"
# A fake `bun`: records its calls in the gstack checkout's parent; fails if the checkout has BUN_FAIL.
cat >"$work/bin/bun" <<'EOF'
#!/usr/bin/env bash
[ "$1" != --version ] || { echo "${FAKE_BUN_VERSION:-9.9.9}"; exit 0; }
echo "bun $* (in $PWD)" >>"$HOME/bun.calls"
[ ! -e BUN_FAIL ] || { echo "fake bun: lockfile out of date" >&2; exit 1; }
EOF
chmod +x "$work/bin/bun"
export PATH="$work/bin:$PATH"

# setup_env [main branch] [expected result: done|FAILED]: a fresh VM's environment setup, the
# two-line setup script with line 2 verbatim.
setup_env() {
  rm -rf /opt/* /tmp/devshop-* "$HOME/plugin" "$HOME/marketplaces" "$HOME/.claude" "$HOME/gstack-setup.args" "$HOME/gstack-config.calls" "$HOME/bun.calls"
  git clone -q --bare "$src" /opt/devshop.git
  [ "${1:-main}" = main ] || git --git-dir=/opt/devshop.git update-ref refs/heads/main "refs/heads/$1"
  # Line 1 clones with the token in the URL; the bootstrap must not keep it (nor name an account).
  git --git-dir=/opt/devshop.git remote set-url origin "https://x-access-token:FAKE-TOKEN@example.com/acme/devshop.git"
  # The setup script as the environment holds it: the owner's comment first, then the clone line
  # (here a stand-in carrying a fake token; the clone already ran above), then line 2 verbatim. Run the
  # ways an environment manager might (DEVSHOP_TEST_RUN): as `bash -c`, as a file, or on stdin.
  local script
  script=$(printf '%s\n' "# test-env · rebuilt 2026-01-01 10:00" \
    "true https://x-access-token:FAKE-TOKEN@example.com/acme/devshop.git" \
    "git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true")
  case ${DEVSHOP_TEST_RUN:-c} in
    c) bash -c "$script" ;;
    file) printf '%s\n' "$script" >/tmp/setup-script.sh && bash /tmp/setup-script.sh ;;
    stdin) bash <<<"$script" ;;
  esac
  # Age the copy: the bootstrap records when it was made (DEVSHOP_TEST_COPY_AGE: a `date -d` offset).
  case "${DEVSHOP_TEST_COPY_AGE:-}" in
    '') ;;
    missing) rm -f /opt/devshop-versions/copy-date ;;
    *) date -u -d "$DEVSHOP_TEST_COPY_AGE" +%FT%TZ >/opt/devshop-versions/copy-date ;;
  esac
  [ -f "$HOME/plugin/hooks/hooks.json" ] || { cat /tmp/devshop-setup.log >&2; fail "bootstrap installed no plugin"; }
  grep -q "RESULT: bootstrap ${2:-done}" /tmp/devshop-setup.log || { cat /tmp/devshop-setup.log >&2; fail "setup log doesn't say ${2:-done}"; }
}

# session <pin or ''> [setup_env args]: start a session in a fresh project on a fresh VM from the
# environment's cached setup (every cloud session starts from that snapshot); prints the hook's output.
session() {
  local proj cmd
  setup_env "${@:2}" >&2
  proj=$(mktemp -d "$work/proj.XXXX")
  [ -z "$1" ] || printf '%s\n' "$1" >"$proj/.devshop-version"
  cmd=$(jq -er '.hooks.SessionStart[0].hooks[0].command' "$HOME/plugin/hooks/hooks.json")
  (cd "$proj" && CLAUDE_PLUGIN_ROOT="$HOME/plugin" CLAUDE_PROJECT_DIR="$proj" bash -c "$cmd") \
    || fail "SessionStart hook exited non-zero"
}

# check <case> <output> <grep -E pattern for its one DEVSHOP: line> <sha current must point at>
check() {
  local lines
  lines=$(grep -c '^DEVSHOP:' <<<"$2" || true)
  [ "$lines" = 1 ] || { echo "$2" >&2; fail "$1: expected exactly one DEVSHOP: line, got $lines"; }
  grep -Eq "$3" <<<"$2" || { echo "$2" >&2; fail "$1: DEVSHOP: line doesn't match /$3/"; }
  # Staleness is visible: every line dates the local devshop copy to the minute and names the
  # project, so a same-day stale copy or the wrong environment shows (W10.4.4).
  local copy_re
  copy_re="$(date -u +%F) [0-9]{2}:[0-9]{2} UTC \\(0 days old\\)"
  local env_re='env note "test-env · rebuilt 2026-01-01 10:00"'
  grep -Eq "^DEVSHOP: .* · devshop copy of ${want_copy:-$copy_re} · project proj\\.[A-Za-z0-9]{4} · ${want_env:-$env_re}(;|$)" <<<"$2" \
    || { echo "$2" >&2; fail "$1: DEVSHOP: line doesn't date the devshop copy"; }
  [ "$(readlink /opt/devshop-current)" = "/opt/devshop-versions/$4" ] \
    || fail "$1: /opt/devshop-current -> $(readlink /opt/devshop-current), want version $4"
  [ -d /opt/devshop-current/skills ] || fail "$1: the current version has no skills/"
  echo "ok - $1"
  grep '^DEVSHOP:' <<<"$2" | sed 's/^/     /'
}

# The setup script clones with the token in the URL: the bootstrap drops the token and keeps the
# URL it was given (no hard-coded account, L-01).
setup_env
url=$(git --git-dir=/opt/devshop.git config --get remote.origin.url)
[ "$url" = "https://example.com/acme/devshop.git" ] || fail "remote URL after bootstrap: '$url', want the clone's URL without the token"
! grep -rq FAKE-TOKEN /opt/devshop.git/config || fail "the token is still in /opt/devshop.git/config"
echo "ok - bootstrap keeps the clone's URL and drops the token"

out=$(session '')
check "HEAD default (no .devshop-version)" "$out" \
  "^DEVSHOP: using HEAD \(${head:0:12}\) from environment default \(no \.devshop-version\)" "$head"

out=$(session "$pinned")
check "pinned SHA" "$out" "^DEVSHOP: using $pinned \(${pinned:0:12}\) from project \.devshop-version" "$pinned"
grep -qx "$marker" <<<"$out" || fail "pinned SHA: the pinned version's SessionStart script didn't run"
echo "ok - pinned SHA: the pinned version's own SessionStart script ran"

unknown=$(rand 'a-f0-9' 40)
out=$(session "$unknown")
check "unknown pin keeps the default" "$out" "^DEVSHOP: version '$unknown' \(project \.devshop-version\) is not in" "$head"

out=$(session "$PRE_MOVE")
if [ "$head" = "$PRE_MOVE" ] || git -C "$repo_root" cat-file -e "$PRE_MOVE:$RUNTIME" 2>/dev/null; then
  check "pin to a pre-move commit" "$out" "^DEVSHOP: using $PRE_MOVE " "$PRE_MOVE"
else
  check "pin to a pre-move commit keeps the default" "$out" "^DEVSHOP: version '$PRE_MOVE' \(${PRE_MOVE:0:12}\) has no devshop runtime" "$head"
fi

# A stale copy shows its age (the copy refreshes only when the environment cache rebuilds).
want_copy="$(date -u -d '9 days ago' +%F) [0-9]{2}:[0-9]{2} UTC \\(9 days old\\)"
out=$(DEVSHOP_TEST_COPY_AGE='9 days ago' session '')
check "HEAD default on a 9-day-old copy" "$out" "^DEVSHOP: using HEAD " "$head"
unset want_copy

want_copy="unknown date \\([^)]*\\)"
out=$(DEVSHOP_TEST_COPY_AGE=missing session '')
check "HEAD default, copy date missing" "$out" "^DEVSHOP: using HEAD " "$head"
unset want_copy

# The environment's note: the setup script's first line, if it is a comment, read while setup runs
# (the session can't read the script or the environment's name). From `bash -c` (above) or a file;
# on stdin the script can't be read back, and the line says so.
out=$(DEVSHOP_TEST_RUN="file" session '')
check "env note from a setup script run as a file" "$out" "^DEVSHOP: using HEAD " "$head"
want_env="env note unavailable"
out=$(DEVSHOP_TEST_RUN="stdin" session '')
check "env note unavailable when the script came on stdin" "$out" "^DEVSHOP: using HEAD " "$head"
unset want_env
# Only that one comment line is kept: the token on the next line is never stored or logged.
! grep -rqs FAKE-TOKEN /opt/devshop-versions /opt/devshop-plugin /opt/devshop.git/config /tmp/devshop-setup.log \
  || fail "the setup script's token reached the install"
echo "ok - only the setup script's comment line is kept; its token never is"

# .devshop-version is project content: anything but a version name is refused, never passed to git.
out=$(session "--output=/tmp/x")
check "a pin that isn't a version keeps the default" "$out" "^DEVSHOP: '--output=/tmp/x' \(project \.devshop-version\) is not a devshop version" "$head"

# gstack (TARGET Shape 7): the bootstrap installs the pinned upstream commit unmodified and runs
# its setup non-interactively, with team mode and gstack's own Claude hooks off (F-GS-08).
setup_env
[ "$(git -C "$HOME/.claude/skills/gstack" rev-parse HEAD 2>/dev/null)" = "$gs_good" ] \
  || fail "gstack: ~/.claude/skills/gstack is not at the pinned commit"
want="args: --host claude --no-team --no-plan-tune-hooks --no-timeline-stop-hook --no-browser --quiet"
got=$(head -1 "$HOME/gstack-setup.args" 2>/dev/null)
[ "$got" = "$want" ] || fail "gstack setup ran with '$got', want '$want'"
grep -qx "stdin: 0 bytes" "$HOME/gstack-setup.args" || fail "gstack setup's stdin isn't closed: $(tail -1 "$HOME/gstack-setup.args")"
[ -f "$HOME/.claude/skills/autoplan/SKILL.md" ] || fail "gstack setup's skills are missing"
# gstack's npm dependencies come only from its lockfile: installed frozen before its setup runs.
grep -qx "bun install --frozen-lockfile (in $HOME/.claude/skills/gstack)" "$HOME/bun.calls" 2>/dev/null \
  || fail "gstack's dependencies weren't installed with --frozen-lockfile first: $(cat "$HOME/bun.calls" 2>/dev/null)"
# The pin is the only upgrade path: gstack's own update check is off (auto_upgrade is off by default).
grep -qx "set update_check false" "$HOME/gstack-config.calls" 2>/dev/null || fail "gstack's update check wasn't turned off"
echo "ok - gstack installed at the pinned commit; setup ran non-interactively with its hooks off; update check off"

# Bun is tied to the gstack pin: a Bun other than the one the pinned gstack is tested on fails the
# gstack step loudly, before anything is installed with it.
FAKE_BUN_VERSION=1.0.0 setup_env main FAILED
grep -q "FAILED: gstack: bun 1.0.0, but gstack .* is tested on bun 9.9.9" /tmp/devshop-setup.log \
  || { cat /tmp/devshop-setup.log >&2; fail "a Bun mismatch wasn't logged as a gstack failure"; }
{ [ ! -e "$HOME/bun.calls" ] && [ ! -e "$HOME/gstack-setup.args" ]; } || fail "gstack installed with the wrong Bun"
echo "ok - a Bun other than the pinned gstack's tested one fails the gstack step, before installing"

# The pinned tools are installed where the devshop's hooks run them.
for tool in gitleaks shellcheck; do
  [ "$(/opt/devshop-tools/bin/$tool --version 2>/dev/null)" = "fake $tool --version" ] \
    || { cat /tmp/devshop-setup.log >&2; fail "$tool isn't installed at /opt/devshop-tools/bin"; }
done
echo "ok - pinned gitleaks and shellcheck installed, checksum-verified, in /opt/devshop-tools/bin"

# A download whose checksum doesn't match the pin is refused loudly; the devshop still installs.
out=$(session '' tools-bad FAILED)
grep -q "FAILED: tool gitleaks: checksum" /tmp/devshop-setup.log || { cat /tmp/devshop-setup.log >&2; fail "a bad gitleaks checksum wasn't logged as a failure"; }
[ ! -e /opt/devshop-tools/bin/gitleaks ] || fail "gitleaks with a bad checksum was installed"
check "tools-bad: devshop still installed" "$out" "^DEVSHOP: using HEAD " "$(git --git-dir="$src" rev-parse tools-bad)"
out=$(session '' tools-badver FAILED)
grep -q "FAILED: tool gitleaks: install/tools.pin line" /tmp/devshop-setup.log || { cat /tmp/devshop-setup.log >&2; fail "a tool version with ../ wasn't refused"; }
{ [ ! -e /escape ] && [ ! -e /opt/escape ]; } || fail "a tool version escaped /opt/devshop-tools"
echo "ok - a tool version that would leave /opt/devshop-tools is refused"

# A gstack failure is loud but can't stop the devshop (L-43): the plugin is installed and the
# DEVSHOP: line still appears.
# Lockfile drift fails closed: gstack's own setup (whose fallback would re-resolve from the
# registry) never runs.
setup_env gstack-drift FAILED
grep -q "FAILED: gstack: frozen dependency install" /tmp/devshop-setup.log || fail "lockfile drift wasn't logged as a gstack failure"
[ ! -e "$HOME/gstack-setup.args" ] || fail "gstack setup ran after the frozen dependency install failed"
echo "ok - gstack lockfile drift fails closed, before gstack's setup"

for broken in gstack-broken gstack-missing gstack-drift; do
  out=$(session '' "$broken" FAILED)
  grep -q "FAILED: gstack" /tmp/devshop-setup.log || { cat /tmp/devshop-setup.log >&2; fail "$broken: log doesn't name the gstack failure"; }
  check "$broken: devshop still installed" "$out" "^DEVSHOP: using HEAD " "$(git --git-dir="$src" rev-parse "$broken")"
done

# Setup fails loudly but still does every step it can (L-43): without the claude CLI, the copy is
# still cleaned and primed, and the log names the failed steps.
rm -rf /opt/* /tmp/devshop-*
git clone -q --bare "$src" /opt/devshop.git
rc=0
mkdir -p "$work/bin-noclaude" && ln -sf "$work/bin/curl" "$work/bin/bun" "$work/bin-noclaude/"
(PATH=$work/bin-noclaude:/usr/bin:/bin && git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash) || rc=$?
[ "$rc" != 0 ] || fail "bootstrap without the claude CLI exited 0"
{ grep -q "FAILED: claude plugin install" /tmp/devshop-setup.log && grep -q "RESULT: bootstrap FAILED" /tmp/devshop-setup.log; } \
  || { cat /tmp/devshop-setup.log >&2; fail "setup log doesn't name the failed step"; }
[ "$(readlink /opt/devshop-current)" = "/opt/devshop-versions/$head" ] || fail "a failed plugin install stopped the priming"
echo "ok - a failed step is logged, makes setup exit non-zero, and the other steps still run"

rm -rf "$work"
echo "all bootstrap scenarios passed"
