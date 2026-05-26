# Dev Container

Sandboxed VS Code Dev Container with restricted outbound network access (allowlist-only firewall).

Adapted from: https://github.com/anthropics/claude-code/tree/main/.devcontainer

## Non-obvious details

### Firewall guarantee

`waitFor: postStartCommand` in `devcontainer.json` blocks VS Code from connecting until `init-firewall.sh` succeeds. The script self-verifies by confirming `example.com` is unreachable and `api.github.com` is reachable — so you're never silently in an unprotected environment.

Domain-based rules resolve IPs once at startup. If a service's IPs rotate while the container is running, the rules go stale until the next restart. See `kit/docs/guide/ops.md § Firewall IP rotation` for the recovery recipe.

### Named volumes are invisible to macOS

Shell history (`/commandhistory`) and Claude Code config (`/home/node/.claude`) use Docker named volumes — they survive container rebuilds but live inside Docker's Linux VM, not on the host filesystem. They are **not** backed up by Time Machine and are **lost on machine migration**.

### macOS file sync performance

`consistency=delegated` on the workspace bind mount lets Docker sync file changes back to macOS lazily, improving I/O speed on the known Docker-for-Mac file sync bottleneck.

### Shell history flush

`PROMPT_COMMAND='history -a'` writes history after every command rather than at session end — without it, a crash or abrupt close loses everything since the terminal opened. The `/commandhistory` directory is created at build time because Docker attaches named volumes at runtime — if the target doesn't exist in the image, Docker creates it as root, causing permission errors for the `node` user.

### Sudo scoping

The `node` user has passwordless sudo only for specific scripts (`init-firewall.sh`, `init-devshop.sh`, `refresh-allowed-ips.sh`) — not general sudo. General sudo would let anything running as `node` escalate to root arbitrarily.
