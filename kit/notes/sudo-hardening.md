# Sudo Hardening — Scoping node user's sudo access

## Problem

The Microsoft devcontainer base image (`mcr.microsoft.com/devcontainers/javascript-node:20`)
gives the `node` user full passwordless sudo by default. Our Dockerfile adds a scoped
entry for the firewall script, but the base image's broad entry remains.

This means Claude (running as `node`) could bypass filesystem-level protections on
security-critical files:

```bash
sudo chown node:node .claude/settings.json
# now Claude can edit the file freely
```

The current mitigations:

- `Bash(sudo *)` is NOT in the Claude Code allowlist — user sees and approves/denies
- DCG runs on all Bash commands — but `sudo chown` isn't a "destructive" pattern
- Root ownership + deny rules catch the 99% case (routine/accidental edits)

## Desired state

Scope `node` user's sudo to only what's needed:

- `/usr/local/bin/init-firewall.sh` (firewall setup on container start)
- Possibly `apt-get` for package installs during development
- Possibly VS Code server operations (need to verify what VS Code needs)

## Risks of restricting

- VS Code Dev Containers may need sudo for some operations (server install, extension host)
- `supabase start` might need sudo for Docker operations inside DinD
- Future tooling might break in surprising ways

## Approach

1. Check what the base image's sudoers entry actually looks like
2. Check if VS Code remote server needs sudo (and for what specifically)
3. Check if `supabase start` under DinD needs sudo
4. If all can be scoped: override the base image's sudoers with specific entries
5. If too fragile: accept the current model (deny list + root ownership + approval prompt)

## When to do this

After Phase 1 is stable and the dev workflow is validated. Premature restriction
risks breaking the development environment in hard-to-debug ways.
