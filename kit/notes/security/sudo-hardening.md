# Sudo Hardening — node user scoped to specific NOPASSWD scripts (SOLVED)

The `node` user's sudo access is scoped to exactly the two scripts that must run
as root on container start. General `sudo` requires a password the `node` user
does not have. This closes the escalation path where Claude (running as `node`)
could bypass the filesystem-level protections on security-critical files.

## Shipped model

The Microsoft devcontainer base image (`mcr.microsoft.com/devcontainers/javascript-node:20`)
grants `node` full passwordless sudo via `/etc/sudoers.d/node` (common-utils
`NOPASSWD:ALL`). The Dockerfile **removes that blanket entry** and replaces it
with two narrowly scoped NOPASSWD entries:

- `node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh` — firewall setup on
  container start.
- `node ALL=(root) NOPASSWD: /usr/local/bin/init-devshop.sh` — devshop init on
  container start.

Both live in `/etc/sudoers.d/node-firewall` (mode `0440`). The blanket
`/etc/sudoers.d/node` is deleted (`rm -f`) immediately after.

See `.devcontainer/Dockerfile` (the `init-firewall.sh` / `init-devshop.sh`
NOPASSWD entries + the blanket-removal `rm -f /etc/sudoers.d/node`).

## What this prevents

General privilege escalation is gone. `node` cannot run an arbitrary command as
root to undo the filesystem-level protections on security-critical files:

```bash
sudo chown node:node .claude/settings.json   # prompts for a password node lacks → denied
```

Only `init-firewall.sh` and `init-devshop.sh` run NOPASSWD; any other `sudo`
invocation requires a password the `node` user was never given.

## Verification

```bash
sudo -n true        # → "sudo: a password is required"  (general sudo needs a password)
```

A clean `sudo -n true` (succeeds without a password) would mean a blanket
NOPASSWD entry has leaked back in. The expected result is the password-required
error.

Belt-and-suspenders, unchanged: `Bash(sudo *)` is not in the Claude Code
allowlist (the operator sees + approves/denies), and root ownership + deny rules
on the security-critical files catch routine/accidental edits.
