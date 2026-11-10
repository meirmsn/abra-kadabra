#!/usr/bin/env bash
# Tests the devshop's one installer of the pinned tools, install/plugin/devshop/tools.sh, in its
# session-start `repair` mode, and the sanctioned repair command that runs it,
# install/plugin/devshop/hooks/repair-tools.sh (specs/pinned-tools-survive-outage.md). The `build`
# mode (the bootstrap's) is tested end to end by tests/bootstrap.test.sh. Runs in a private mount
# namespace with a scratch /opt, /tmp and /usr/local/bin, and a fake curl bound over /usr/bin/curl
# (repair mode runs with PATH=/usr/bin:/bin, so a fake earlier on PATH would not be used).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi
for t in flock timeout sha256sum tar git; do
  [ -x "/usr/bin/$t" ] || [ -x "/bin/$t" ] || fail "$t not found in /usr/bin or /bin"
done
[ -e /usr/bin/curl ] || fail "no /usr/bin/curl to bind the fake over"
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
mount -t tmpfs devshop-test-tmp /tmp || fail "can't mount a scratch /tmp"
mount -t tmpfs devshop-test-ulb /usr/local/bin || fail "can't mount a scratch /usr/local/bin"
work=$(mktemp -d)
isolate_git "$work"

tools_sh=$repo_root/install/plugin/devshop/tools.sh
repair_sh=$repo_root/install/plugin/devshop/hooks/repair-tools.sh
[ -f "$tools_sh" ] || fail "no $tools_sh"
[ -f "$repair_sh" ] || fail "no $repair_sh"

# Two fake tools, alpha and beta, as release tarballs in $work/dl, served by the fake curl by the
# URL's basename. <basename>.504 holding n: the next n fetches answer 504; <basename>.hang: hangs.
mkdir -p "$work/dl" "$work/fk/alpha" "$work/fk/beta"
for t in alpha beta; do
  printf '#!/bin/sh\necho "fake %s $*"\n' "$t" >"$work/fk/$t/$t" && chmod +x "$work/fk/$t/$t"
  tar -czf "$work/dl/$t.tar.gz" -C "$work/fk/$t" "$t"
done
sum() { sha256sum "$work/dl/$1.tar.gz" | cut -d' ' -f1; }
pin() { # pin [alpha sha]: a tools.pin for alpha and beta
  printf '# a comment\nalpha 1.0.0 %s https://example.com/dl/alpha.tar.gz\nbeta 2.0.0 %s https://example.com/dl/beta.tar.gz\n' \
    "${1:-$(sum alpha)}" "$(sum beta)"
}
cat >"$work/curl" <<EOF
#!/bin/bash
echo "\$*" >>"$work/curl.calls"
out= url=
while [ \$# -gt 0 ]; do case "\$1" in -o) out=\$2; shift 2 ;; --connect-timeout|--max-time) shift 2 ;; -*) shift ;; *) url=\$1; shift ;; esac; done
b=\${url##*/}
[ ! -e "$work/dl/\$b.hang" ] || exec sleep 30
if [ -s "$work/dl/\$b.504" ] && [ "\$(cat "$work/dl/\$b.504")" -gt 0 ]; then
  echo \$(( \$(cat "$work/dl/\$b.504") - 1 )) >"$work/dl/\$b.504"; echo "fake curl: 504 \$url" >&2; exit 22
fi
[ ! -e "$work/dl/\$b.slow" ] || sleep 1
[ -f "$work/dl/\$b" ] || { echo "fake curl: 404 \$url" >&2; exit 22; }
cp "$work/dl/\$b" "\$out"
EOF
chmod +x "$work/curl"
mount --bind "$work/curl" /usr/bin/curl || fail "can't bind the fake curl over /usr/bin/curl"

T=/opt/devshop-tools U=/usr/local/bin L=/tmp/devshop-tools-repair.log
fresh() { rm -rf /opt/* /usr/local/bin/* "$L" "$work/curl.calls" "$work"/dl/*.504 "$work"/dl/*.hang "$work"/dl/*.slow; pin >"$work/tools.pin"; }
calls() { if [ -f "$work/curl.calls" ]; then grep -c "$1" "$work/curl.calls" || true; else echo 0; fi; }
# repair [limit]: tools.sh repair on $work/tools.pin; sets out and rc.
repair() { rc=0; out=$(bash "$tools_sh" repair "$work/tools.pin" "$T" "$U" "$L" ${1:+"$1"} 2>"$work/err") || rc=$?; }
installed() { [ "$("$T/bin/$1" --version 2>/dev/null)" = "fake $1 --version" ] && [ "$(readlink "$U/$1")" = "$T/bin/$1" ]; }

fresh
repair
{ [ "$rc" = 0 ] && [ "$out" = $'repaired alpha\nrepaired beta' ] && installed alpha && installed beta; } \
  || { echo "rc=$rc out=$out" >&2; cat "$L" "$work/err" >&2; fail "pinned-tools-survive-outage AC-1: missing tools aren't installed, verified and linked"; }
grep -q -- "--connect-timeout 10" "$work/curl.calls" || fail "pinned-tools-survive-outage AC-4: repair doesn't pass --connect-timeout 10"
echo "ok - pinned-tools-survive-outage AC-1: repair installs the missing tools, checksum-verified, and links them on PATH"

rm -f "$work/curl.calls"
repair
{ [ "$rc" = 0 ] && [ -z "$out" ] && [ "$(calls .)" = 0 ]; } || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-3: repair with every tool present downloaded or said something"; }
echo "ok - pinned-tools-survive-outage AC-3: with every tool present, repair downloads nothing and says nothing"

# Only the missing tool is fetched; the present one keeps its install.
rm -f "$T/bin/beta" "$work/curl.calls"
repair
{ [ "$out" = "repaired beta" ] && [ "$(calls alpha)" = 0 ] && [ "$(calls beta)" = 1 ] && installed alpha && installed beta; } \
  || { echo "out=$out" >&2; fail "pinned-tools-survive-outage AC-1: repair fetched a present tool or missed the absent one"; }
# A dangling link counts as missing.
rm -rf "$T/alpha-1.0.0" "$work/curl.calls"
repair
{ [ "$out" = "repaired alpha" ] && installed alpha; } || { echo "out=$out" >&2; fail "pinned-tools-survive-outage AC-1: a dangling link wasn't repaired"; }
echo "ok - pinned-tools-survive-outage AC-1: only the missing tool is fetched; a dangling link is missing"

for bad in 504 404 sha; do
  fresh
  case $bad in
    504) echo 9 >"$work/dl/alpha.tar.gz.504" ;;
    404) pin | sed 's|/alpha.tar.gz|/gone.tar.gz|' >"$work/tools.pin" ;;
    sha) pin "$(rand 'a-f0-9' 64)" >"$work/tools.pin" ;;
  esac
  repair
  { [ "$rc" = 1 ] && [ "$out" = $'missing alpha\nrepaired beta' ] && [ ! -e "$T/bin/alpha" ] && installed beta; } \
    || { echo "rc=$rc out=$out" >&2; cat "$L" >&2; fail "pinned-tools-survive-outage AC-2: a $bad download installed alpha or wasn't said"; }
  [ ! -e "$T/alpha.download" ] || fail "pinned-tools-survive-outage AC-2: a $bad download was left behind"
  grep -q "FAILED: tool alpha" "$L" || fail "pinned-tools-survive-outage AC-2: the $bad failure isn't in $L"
done
echo "ok - pinned-tools-survive-outage AC-2: a 504, a 404 and a wrong sha256 install nothing and say the tool is missing"

fresh
echo 9 >"$work/dl/alpha.tar.gz.504"
repair
[ "$(calls alpha)" = 2 ] || fail "pinned-tools-survive-outage AC-4: repair fetched alpha $(calls alpha) times, want at most 2"
fresh
echo 1 >"$work/dl/alpha.tar.gz.504"
repair
{ [ "$(calls alpha)" = 2 ] && installed alpha; } || fail "pinned-tools-survive-outage AC-4: one 504 then a good fetch didn't install alpha on the second try"
echo "ok - pinned-tools-survive-outage AC-4: each missing tool is fetched at most twice"

fresh
touch "$work/dl/alpha.tar.gz.hang"
start=$(date +%s)
repair 3
took=$(($(date +%s) - start))
{ [ "$took" -le 8 ] && [ "$rc" = 1 ] && grep -qx "missing alpha" <<<"$out"; } \
  || { echo "rc=$rc took=${took}s out=$out" >&2; fail "pinned-tools-survive-outage AC-4: a hung download outlived the repair's limit or wasn't said"; }
grep -q '^60$' < <(sed -n 's/^limit=\${6:-\([0-9]*\)}.*/\1/p' "$tools_sh") \
  || fail "pinned-tools-survive-outage AC-4: tools.sh's default repair limit isn't 60 s"
echo "ok - pinned-tools-survive-outage AC-4: a hung download stops at the repair's limit (60 s by default) and is said"

# A PATH with a fake sha256sum that passes everything doesn't make repair trust a bad file.
fresh
pin "$(rand 'a-f0-9' 64)" >"$work/tools.pin"
mkdir -p "$work/evil"
# shellcheck disable=SC2016 # the fake's source: expands when it runs
printf '#!/bin/sh\necho "$2: OK"; exit 0\n' >"$work/evil/sha256sum" && chmod +x "$work/evil/sha256sum"
rc=0
out=$(PATH="$work/evil:$PATH" DEVSHOP_TOOL_RETRY_DELAY=0 bash "$tools_sh" repair "$work/tools.pin" "$T" "$U" "$L" 2>/dev/null) || rc=$?
{ [ "$rc" = 1 ] && [ ! -e "$T/bin/alpha" ]; } || fail "pinned-tools-survive-outage AC-4: a fake sha256sum on PATH got an unverified alpha installed"
echo "ok - pinned-tools-survive-outage AC-4: a fake sha256sum on PATH doesn't get an unverified file installed"

for bad in blank badsum badurl badname dotdot; do
  fresh
  case $bad in
    blank) pin | sed '2G' >"$work/tools.pin" ;;
    badsum) pin | sed 's/^beta 2.0.0 [0-9a-f]*/beta 2.0.0 xyz/' >"$work/tools.pin" ;;
    badurl) pin | sed 's|https://example.com/dl/beta|http://example.com/dl/beta|' >"$work/tools.pin" ;;
    badname) pin | sed 's/^beta /Be_ta /' >"$work/tools.pin" ;;
    dotdot) pin | sed 's|^beta 2.0.0 |beta ../../x |' >"$work/tools.pin" ;;
  esac
  repair
  { [ "$rc" = 1 ] && grep -q '^unreadable install/tools.pin line [0-9]* is not ' <<<"$out" && [ "$(calls .)" = 0 ] && [ ! -e "$T/bin/alpha" ]; } \
    || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-8: a $bad tools.pin line downloaded something or wasn't said"; }
done
rc=0
out=$(bash "$tools_sh" repair "$work/no-such.pin" "$T" "$U" "$L" 2>/dev/null) || rc=$?
{ [ "$rc" = 1 ] && grep -q '^unreadable ' <<<"$out"; } || fail "pinned-tools-survive-outage AC-8: a missing tools.pin wasn't said"
rc=0
bash "$tools_sh" fix "$work/tools.pin" "$T" "$U" "$L" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "tools.sh with an unknown mode didn't exit 2"
echo "ok - pinned-tools-survive-outage AC-8: a malformed or missing tools.pin downloads nothing and is said"

# The repair command: the local copy's pin at its default ref, through tools.sh.
setup_copy() { # setup_copy [tools.pin content]: a local devshop copy whose default ref pins alpha and beta
  rm -rf "$work/src"
  mkdir -p "$work/src/install" /opt/devshop-plugin/versions
  printf '%s\n' "${1:-$(pin)}" >"$work/src/install/tools.pin"
  git -C "$work/src" init -q && git -C "$work/src" add -A && git -C "$work/src" commit -qm pin
  git clone -q --bare "$work/src" /opt/devshop.git
  echo HEAD >/opt/devshop-plugin/versions/default-ref
}
# run_repair: the command as a session runs it; sets out and rc.
run_repair() { rc=0; out=$(bash "$repair_sh" 2>&1) || rc=$?; }
fresh && setup_copy
echo 9 >"$work/dl/beta.tar.gz.504"
run_repair
{ [ "$rc" = 1 ] && grep -q "repaired alpha" <<<"$out" && grep -q "missing beta" <<<"$out" && installed alpha; } \
  || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-5: repair-tools.sh with beta failing didn't exit 1 naming it"; }
rm "$work/dl/beta.tar.gz.504"
run_repair
{ [ "$rc" = 0 ] && grep -q "repaired beta" <<<"$out" && installed beta; } \
  || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-5: repair-tools.sh didn't exit 0 once nothing was missing"; }
echo "ok - pinned-tools-survive-outage AC-5: repair-tools.sh exits 1 naming a still-missing tool, 0 once none is"

# Two overlapping runs: the lock makes the second wait, so each tool is fetched and installed once.
fresh && setup_copy
touch "$work/dl/alpha.tar.gz.slow" "$work/dl/beta.tar.gz.slow"
bash "$repair_sh" >"$work/r1" 2>&1 & p1=$!
bash "$repair_sh" >"$work/r2" 2>&1 & p2=$!
r1=0 r2=0
wait "$p1" || r1=$?
wait "$p2" || r2=$?
{ [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$(calls alpha)" = 1 ] && [ "$(calls beta)" = 1 ] && installed alpha && installed beta; } \
  || { cat "$work/r1" "$work/r2" "$L" >&2; fail "pinned-tools-survive-outage AC-5: two overlapping repairs fetched a tool twice or failed (r1=$r1 r2=$r2)"; }
echo "ok - pinned-tools-survive-outage AC-5: two overlapping repairs leave each tool fetched and installed once"

# The repair command reads only the local copy: a DEVSHOP_* override changes nothing, and an
# unreadable default ref or pin is said, with nothing downloaded.
fresh && setup_copy
rc=0
out=$(DEVSHOP_TOOL_RETRY_DELAY=x bash "$repair_sh" 2>&1) || rc=$?
{ [ "$rc" = 0 ] && installed alpha; } || { echo "$out" >&2; fail "repair-tools.sh with a DEVSHOP_ override didn't repair as usual"; }
fresh && setup_copy && rm /opt/devshop-plugin/versions/default-ref
run_repair
{ [ "$rc" = 1 ] && grep -q "unreadable no default ref" <<<"$out" && [ "$(calls .)" = 0 ]; } \
  || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-8: a missing default ref wasn't said"; }
fresh && setup_copy && echo no-such-ref >/opt/devshop-plugin/versions/default-ref
run_repair
{ [ "$rc" = 1 ] && grep -q "unreadable no install/tools.pin at no-such-ref" <<<"$out" && [ "$(calls .)" = 0 ]; } \
  || { echo "rc=$rc out=$out" >&2; fail "pinned-tools-survive-outage AC-8: a ref without tools.pin wasn't said"; }
echo "ok - pinned-tools-survive-outage AC-8: repair-tools.sh says an unreadable default ref or pin and downloads nothing"

rm -rf "$work"
echo "all tools scenarios passed"
