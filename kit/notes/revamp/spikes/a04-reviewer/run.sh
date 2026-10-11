#!/bin/bash
# Spike A-04 (W10.1.4, LOG #7): one locked-down reviewer call on a fixed case; ran 20x per case, 40/40 stable.
# usage: run.sh <seeded|honest> <n>  — writes out/<case>-<n>.json (out/ is not committed)
S=$(dirname "$0"); cd "$S/$1" || exit 1; mkdir -p ../out
P='You are an independent code reviewer. Read spec.md, src/ and test/ in the current directory. For each acceptance item decide whether it is implemented AND has a test. Return verdict "fail" if any item is unmet, else "pass"; list unmet item ids (e.g. "AC-2") in unmet.'
start=$(date +%s)
claude -p "$P" --setting-sources "" --tools "Read,Grep,Glob" --strict-mcp-config --no-session-persistence \
  --model sonnet --output-format json < /dev/null --json-schema "$(cat ../schema.json)" > "../out/$1-$2.json" 2> "../out/$1-$2.err"
echo "$1-$2 exit=$? secs=$(( $(date +%s)-start ))" >> ../out/timing.log
