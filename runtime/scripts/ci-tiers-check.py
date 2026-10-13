#!/usr/bin/env python3
"""Shape check for a project's CI in two tiers, fast and slow (spec specs/ci-fast-slow-tiers.md).

Usage: ci-tiers-check.py WORKFLOW   (a project's .github/workflows/ci.yml)
Rules; runtime/templates/ci.yml follows them:
  - a job `fast` with a step running `scripts/check-fast.sh "$BASE"`
  - a job `slow` that needs `fast`, with a step running `scripts/check-slow.sh`
  - neither job has a job-level `if` or `continue-on-error`: GitHub counts a skipped required job
    as passed
  - any other job with an `environment` (a deploy) needs both
A step runs a script when one line of its `run`, not a comment, starts with the script's path, and
the step itself has no `if` or `continue-on-error`.
Feedback, not a wall: session start and this repo's lint run it; required CI is the wall.
Exit 0 = the shape holds; 1 = problems (listed); 2 = can't run (no file, unparseable, no PyYAML).
"""
import sys

TIERS = {"fast": 'scripts/check-fast.sh "$BASE"', "slow": "scripts/check-slow.sh"}


def cant_run(msg):
    print(f"ci-tiers-check: {msg}", file=sys.stderr)
    sys.exit(2)


def needs(job):
    n = job.get("needs", [])
    return [n] if isinstance(n, str) else list(n or [])


def runs(job, command):
    """True when a step of the job runs `command` unconditionally."""
    for step in job.get("steps") or []:
        if not isinstance(step, dict) or "if" in step or step.get("continue-on-error"):
            continue
        for line in str(step.get("run", "")).splitlines():
            line = line.strip()
            if line == command or line.startswith(command + " "):
                return True
    return False


def problems(workflow):
    jobs = workflow.get("jobs") if isinstance(workflow, dict) else None
    if not isinstance(jobs, dict) or not jobs:
        return ["no jobs"]
    found = []
    for tier, command in TIERS.items():
        job = jobs.get(tier)
        if not isinstance(job, dict):
            found.append(f"no job '{tier}'")
            continue
        if not runs(job, command):
            found.append(f"'{tier}' doesn't run {command} (in a step without its own 'if')")
        for key in ("if", "continue-on-error"):
            if key in job:
                found.append(f"'{tier}' has a job-level '{key}' (a skipped required job counts as passed)")
    slow = jobs.get("slow")
    if isinstance(slow, dict) and "fast" not in needs(slow):
        found.append("'slow' doesn't need 'fast'")
    for name, job in jobs.items():
        if name in TIERS or not isinstance(job, dict) or "environment" not in job:
            continue
        for tier in TIERS:
            if tier not in needs(job):
                found.append(f"'{name}' has an environment but doesn't need '{tier}'")
    return found


def main(argv):
    if len(argv) != 2:
        cant_run("usage: ci-tiers-check.py WORKFLOW")
    try:
        import yaml
    except ImportError as e:
        cant_run(f"PyYAML not importable ({e}); CI installs the pinned one")
    try:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        cant_run(f"can't read {argv[1]}: {e}")
    try:
        workflow = yaml.safe_load(text)
    except yaml.YAMLError as e:
        cant_run(f"can't parse {argv[1]}: {e}")
    found = problems(workflow)
    for p in found:
        print(f"ci-tiers-check: {argv[1]}: {p}")
    if found:
        print("ci-tiers-check: the two-tier shape is runtime/templates/ci.yml in the devshop")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
