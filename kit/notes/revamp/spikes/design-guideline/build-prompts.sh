#!/usr/bin/env bash
# Builds one prompt of the design-guideline dry run from real files, never retyped:
#   build-prompts.sh <scratch dir> <guidelines dir> <build SKILL.md> <out prompt file>
# The control passes origin/main's build skill and guidelines (materialised with git archive);
# the guided arm passes the working tree's. Section 2 of the skill is quoted verbatim.
set -euo pipefail
scratch=$1 guidelines=$2 skill=$3 out=$4
here=$(cd "$(dirname "$0")" && pwd)
section2=$(awk '/^## 2\./{f=1} /^## 3\./{f=0} f' "$skill")
task=$(cat "$here/site/task.md")
{
  printf '%s\n' \
    "You are a builder session making a UI change in the project at $scratch (a static site:" \
    "index.html, base.css, theme.js, and the project's files beside them). You may read anything and" \
    "edit files only inside that directory. Commit nothing. Run no gstack command and no design" \
    "review in this run; skip the stack-homes step (none apply)." \
    "" \
    "Before writing, follow this section of the devshop's build skill, quoted verbatim. Where it says" \
    "/opt/devshop-current/guidelines/, use $guidelines/ (the guidelines for this run); where it says" \
    "/opt/devshop-current/templates/ui/, the project already has its baseline." \
    "" \
    "$section2" \
    "" \
    "The task:" \
    "" \
    "$task" \
    "" \
    "When done, reply with exactly two parts and nothing else:" \
    "1. \"FILES READ, IN ORDER:\" a numbered list of every file you read (with the Read tool or a shell" \
    "   command), in the order you read them, with a line \"-- first edit --\" at the point where you" \
    "   made your first edit to any file." \
    "2. \"DIFF:\" the verbatim output of: git -C $scratch diff"
} >"$out"
