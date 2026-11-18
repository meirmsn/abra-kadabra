#!/usr/bin/env bash
# A build that fails: its message must reach the could-not-run reason, colour codes removed.
printf '\033[31mbuild broke: missing page\033[0m\n' >&2
exit 1
