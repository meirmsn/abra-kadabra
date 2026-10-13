#!/usr/bin/env bash
# Tests the reviewer prompt's screenshot check (W10.6.9d): the reviewer may skip the two screenshot
# commits pr-assets.sh adds only after checking them, and one check is that every file in the
# screenshot commit is a regular file (mode 100644), so a link named like an image can't pass. The
# prompt names the command that shows modes; this proves that command shows a link's mode on a
# parentless commit (the old `git show --stat` didn't), and that the prompt still asks for it.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
prompt="$repo_root/runtime/reviewer/prompt.md"
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# A parentless screenshot commit holding a regular image and a link named like one.
git init -q "$work/r"
printf '\x89PNG\r\n\x1a\n' >"$work/r/01-real.png"
ln -s ../../secret "$work/r/02-link.png"
git -C "$work/r" add -A
git -C "$work/r" commit -qm "devshop assets: feat/x at 0123456789ab"

raw=$(git -C "$work/r" log -1 --raw --format=)
grep -Eq $'100644 [0-9a-f]+ [0-9a-f]+ A\t01-real.png$' <<<"$raw" || fail "the raw listing doesn't show the image as 100644: $raw"
grep -Eq $'120000 [0-9a-f]+ [0-9a-f]+ A\t02-link.png$' <<<"$raw" || fail "the raw listing doesn't show the link as 120000: $raw"
! git -C "$work/r" show --stat --format= | grep -q 120000 || fail "git show --stat now shows modes; recheck the prompt's choice"
echo "ok - git log -1 --raw --format= shows each file's mode on a parentless commit; git show --stat doesn't"

# shellcheck disable=SC2016 # literal backticks, as the prompt writes them
grep -qF '`git log -1 --raw --format= <assets commit>`' "$prompt" || fail "the prompt no longer names the command that shows file modes"
# shellcheck disable=SC2016
grep -qF 'mode `100644`' "$prompt" || fail "the prompt no longer requires mode 100644 for the screenshot files"
echo "ok - the prompt asks for that command and mode 100644"
echo "PASS: reviewer screenshot check"
