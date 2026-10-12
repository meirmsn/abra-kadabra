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
# Where a devshop version keeps its runtime (skills/, hooks/), as of the commit under test.
RUNTIME=kit/notes/revamp/spikes/w10-1-2b-thin/runtime

work=$(mktemp -d)
isolate_git "$work"
head=$(git -C "$repo_root" rev-parse HEAD)
git -C "$repo_root" merge-base --is-ancestor "$PRE_MOVE" HEAD 2>/dev/null || fail "pre-move commit $PRE_MOVE is not in HEAD's history (shallow clone? CI needs fetch-depth: 0)"

# A source repo standing in for the devshop on GitHub: main = HEAD, plus a pinned side commit
# that adds a runtime SessionStart script printing a marker.
src="$work/src.git"
git init -q --bare "$src"
git -C "$repo_root" push -q "$src" "$head:refs/heads/main"
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
export PATH="$work/bin:$PATH"

# setup_env: a fresh VM's environment setup — the two-line setup script, line 2 verbatim.
setup_env() {
  rm -rf /opt/* /tmp/devshop-* "$HOME/plugin" "$HOME/marketplaces"
  git clone -q --bare "$src" /opt/devshop.git
  # Line 1 clones with the token in the URL; the bootstrap must not keep it (nor name an account).
  git --git-dir=/opt/devshop.git remote set-url origin "https://x-access-token:FAKE-TOKEN@example.com/acme/devshop.git"
  git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true
  [ -f "$HOME/plugin/hooks/hooks.json" ] || { cat /tmp/devshop-setup.log >&2; fail "bootstrap installed no plugin"; }
}

# session <pin or ''>: start a session in a fresh project on a fresh VM from the environment's
# cached setup (every cloud session starts from that snapshot); prints the hook's output.
session() {
  local proj cmd
  setup_env >&2
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
  [ "$(readlink /opt/devshop-current)" = "/opt/devshop-versions/$4" ] \
    || fail "$1: /opt/devshop-current -> $(readlink /opt/devshop-current), want version $4"
  [ -d /opt/devshop-current/skills ] || fail "$1: the current version has no skills/"
  echo "ok - $1"
  grep '^DEVSHOP:' <<<"$2" | sed 's/^/     /'
}

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

rm -rf "$work"
echo "all bootstrap scenarios passed"
