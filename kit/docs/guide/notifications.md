# Notifications

Claude Code pushes to your iPhone, Apple Watch, and Mac via [ntfy.sh](https://ntfy.sh) when it needs input or finishes a task. Wiring ships with every project — you configure once (per user, per project's `.devcontainer/.env`).

## What fires

| Event               | Banner                                         | Priority |
| ------------------- | ---------------------------------------------- | -------- |
| `Notification` hook | `{project} — Claude Code` / `Needs your input` | high     |
| `Stop` hook         | `{project} — Claude Code` / `Task finished`    | default  |

Scripts at `/devshop/kit/scripts/notify-claude-{request,done}` read `$NTFY_URL` from env, no-op silently if unset, and always exit 0 (never block Claude).

`{project}` auto-labels from `package.json` `name` field (fallback: directory basename).

## Debounce (30s)

To avoid pinging you when you're actively working, notifications are **scheduled 30 seconds out**, not sent immediately. If any activity signal fires before the 30s elapses, the pending notification is cancelled:

- `UserPromptSubmit` (you sent Claude a new prompt) → cancel
- `PreToolUse` (Claude proceeded to use a tool — typically after you granted permission) → cancel
- Another `Notification` or `Stop` → replaces the pending one

Net effect: if you're at the computer and responding, you won't get pings. If you walked away and nothing happens for 30s, you do.

Implementation: `notify-claude-request` / `notify-claude-done` background a `sleep 30 && curl ...` job, stash its PID in `/tmp/claude-notify-pending.pid`. `notify-claude-cancel` reads the PID and kills it. Single pending slot per container (multiple sessions share it — last event wins, which is the right UX for one-human-one-device).

## One-time user setup

1. **Generate a topic** (once, reused across every project):

   ```bash
   openssl rand -hex 32
   ```

   → 64 hex chars, e.g. `60c9bacd782a4622bdb17719acd11c65...` (256-bit entropy, unguessable). **ntfy caps topic names at 64 characters**, so any human-readable prefix leaves you over the limit — the raw hex is the topic.

2. **Add to each project's `.devcontainer/.env`** (gitignored, loaded via `--env-file` at container start):

   ```
   NTFY_URL=https://ntfy.sh/<your-topic>
   ```

   Same URL in every project's `.env`. `/ak-new-project` Step 4 includes `NTFY_URL` in the `.env` template so future projects are one copy-paste.

3. **Subscribe on iPhone**: ntfy iOS app ([App Store](https://apps.apple.com/us/app/ntfy/id1625396347)) → **+** → paste the topic (the hex string, no `https://`) → accept notification permission. Apple Watch mirrors automatically.

4. **Subscribe on Mac** (optional, no app install): open `https://ntfy.sh/<your-topic>` in Safari → accept notifications → File → **Add to Dock** to keep alive when browser closes. Chrome: ⋮ → Install ntfy.sh as app.

5. **Rebuild the devcontainer** so Docker re-reads `.devcontainer/.env`.

## How it works

```
Claude event → hook → /devshop/kit/scripts/notify-claude-*
                        ↓ reads $NTFY_URL (loaded from .devcontainer/.env)
                        ↓ curl POST → ntfy.sh/<topic>
                                       ↓ Apple APNS
                                       ↓ iPhone / Watch / Mac
```

- **`NTFY_URL` source**: each project's `.devcontainer/.env`, loaded by Docker via `--env-file` in `devcontainer.json` `runArgs`.
- **Why not host shell + `containerEnv`**: `${localEnv:...}` only resolves from the VSCode process env. On Mac, launching VSCode from Dock/Spotlight inherits the launchd env (no `~/.zshrc` exports). `.env` is reliable regardless of launch method.
- **Firewall allowlist entry** (in each `.devcontainer/init-firewall.sh`):

  ```
  "ntfy.sh" \
  ```

- **Hook wiring**: lives in `/devshop/.claude/settings.json` (source of truth). `init-devshop.sh` copies it into every project's `.claude/settings.json` at each container start, preserving absolute `/devshop/kit/...` paths via `normalize-devshop-paths.sh`.

## Privacy

- **Content**: title/body transit through ntfy.sh (operator-readable) and Apple APNS (required for iOS push). Defaults (`"Needs your input"` / `"Task finished"`) leak nothing.
- **Topic URL**: 256-bit random, unguessable. Only subscribers you point to it can read.
- **Sensitive content**: if you ever include specifics (paths, prompt text) in notifications, self-host ntfy on your VPS + set `upstream-base-url: https://ntfy.sh` so only wake-up pings transit through ntfy.sh, not bodies.

## Disabling

- Blank out `NTFY_URL` in `.devcontainer/.env` → rebuild → scripts silently no-op.
- Per-project only: comment out the hooks block in `.claude/settings.json` (note: `init-devshop.sh` will regenerate it from devshop's copy at next container start, so this is temporary).
- Temporary mute: long-press topic in iOS ntfy app → Pause.

## Rotating the topic

1. Generate a new topic: `openssl rand -hex 32`
2. Update `NTFY_URL` in every project's `.devcontainer/.env`
3. Rebuild each container
4. Re-subscribe on iPhone and Mac (unsubscribe the old one)

Rare operation — the cost of editing N `.env` files is acceptable for the privacy benefit of a fresh, untraceable topic.

## Multi-project differentiation

All projects share one topic by default — banners differentiate via the project label in the title (`lalista — Claude Code`, `abra-kadabra — Claude Code`, …).

For per-project mute, set a different `NTFY_URL` per project's `.env`, subscribe each topic on iOS individually.
