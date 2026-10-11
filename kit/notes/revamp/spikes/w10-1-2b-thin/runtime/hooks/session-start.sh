#!/usr/bin/env bash
# The pinned version's own SessionStart work (stub dispatcher calls it).
echo "$(date -u +%FT%TZ) runtime spike-2 session-start ran" >> /tmp/devshop-probe2-hook.log
echo "DEVSHOP-PROBE2-HOOK spike-2 — the pinned version's SessionStart ran"
