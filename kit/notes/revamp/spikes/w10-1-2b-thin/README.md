# W10.1.2b spike — thin, code-based devshop install

Follow-up to W10.1.2 (owner, 2026-10-11): minimum UI work, version per project in code.

**Design**
- **Environment (UI, once, shared by all projects):** setup script = a read-only **token** (fine-grained, abra-kadabra only) +
  `git clone --bare` of the devshop into `/opt/devshop.git` + run `bootstrap.sh` from that copy
  (`env-setup.sh`). Holds no version.
- **Devshop (code):** `bootstrap.sh` installs a **stub plugin** at user scope. The stub's `skills`
  is a symlink to `/opt/devshop-current/skills`; its SessionStart hook (`dispatch.sh`) reads the
  project's `.devshop-version` (else the environment default), extracts that version's
  `runtime/` from the local copy (no network) into `/opt/devshop-versions/<sha>`, repoints
  `/opt/devshop-current`, and runs that version's own `hooks/session-start.sh`.
- **Project (code):** one file, `.devshop-version` (tag or SHA). Bumping = a one-line PR.

**Why a stub:** a plugin installed by a SessionStart hook does not load until the next session
(tested locally); a symlinked skills dir switched by the hook does — including skills that exist
only in the newly pinned version (tested locally).

**Local evidence (2026-10-11, isolated config, real `/opt`):** no pin → default (`spike-2`);
`.devshop-version` = older commit → `spike-1`; pin to a commit without a runtime → kept the
previous version with a warning.

**Known limit:** the local copy refreshes only when the environment cache rebuilds (setup
script edited, network settings changed, or ~7 days). A project pinned to a newer version gets a
clear `DEVSHOP:` warning until then.

## Owner run

1. On your machine: `ssh-keygen -t ed25519 -N "" -C devshop-deploy -f devshop_deploy`
2. abra-kadabra → Settings → Deploy keys → Add: paste `devshop_deploy.pub`, **leave "Allow write
   access" unchecked**.
3. Environment → Setup script: replace everything with `env-setup.sh`, pasting the contents of
   `devshop_deploy` (private key) between the `KEY` lines. Delete the old spike token line/block.
4. New lalista session in that environment, paste:
   > W10.1.2b check — read-only, change nothing, never print keys or the setup script. Show
   > `/tmp/devshop-clone.log` and `/tmp/devshop-setup.log`; quote every context line starting
   > with DEVSHOP; `cat /tmp/devshop-probe2-hook.log`; run the devshop-probe2 skill and quote it.

Expected: clone OK over SSH, bootstrap done, `DEVSHOP: using claude/gallant-keller-1f1ih8 …
from environment default`, the probe2 hook line, and `DEVSHOP-PROBE2-SKILL spike-2`.

**Owner run 1 (2026-10-11):** clone failed — the cloud image has no `ssh` binary. `env-setup.sh` now
installs `openssh-client` first (log: `/tmp/devshop-ssh-install.log`).

**Owner run 2:** SSH client installed, but `ssh.github.com` does not resolve and port 22 times out —
the network policy allows HTTPS only. Deploy keys (SSH-only) are out; `env-setup.sh` now clones over
HTTPS with a fine-grained read-only token (the route proven in W10.1.2). The deploy key can be deleted.

**Owner run 3 (2026-10-11 12:49): passed.** HTTPS + token clone clean; bootstrap from code installed
the stub; in the lalista session the dispatcher reported `DEVSHOP: using … from environment
default`, the pinned version's hook ran and `devshop-probe2` resolved to the same commit. The
runtime hook also ran once during setup (bootstrap priming) — fixed: priming no longer runs it.

**Final form (owner run 4, after #46 merged): passed.** Setup script = `env-setup.sh` (two lines,
token + `HEAD:bootstrap.sh`); token not stored on disk; hook ran once; default = `HEAD` (`main`).

