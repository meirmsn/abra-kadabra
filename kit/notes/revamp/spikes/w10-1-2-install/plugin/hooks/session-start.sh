#!/usr/bin/env bash
# W10.1.2 probe: leave a marker file and inject one line of context.
echo "$(date -u +%FT%TZ) devshop-probe 0.1.0 SessionStart ran (root: ${CLAUDE_PLUGIN_ROOT})" >> /tmp/devshop-probe-hook.log
echo "DEVSHOP-PROBE-HOOK 0.1.0 — SessionStart hook from the pinned install ran"
