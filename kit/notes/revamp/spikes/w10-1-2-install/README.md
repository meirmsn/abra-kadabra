# W10.1.2 spike — pinned devshop install in a cloud session

Question (A-09/A-22, feeds D-01): can a cloud session working on a **project** repo get the
devshop at a **pinned commit** from this **private** repo, with its skills and hooks loading?

- `plugin/` — throwaway probe plugin: skill `devshop-probe` + a SessionStart hook that writes
  `/tmp/devshop-probe-hook.log` and injects a `DEVSHOP-PROBE-HOOK` line.
- `.claude-plugin/marketplace.json` — local marketplace listing it.
- `setup.sh` — paste into a cloud environment's **Setup script**. Fetches `PIN` (a commit on this
  repo) into `/opt/devshop-pin`, then `claude plugin marketplace add` + `install` at user scope.
  Tries, in order: **0** the attached abra-kadabra clone · **A** git + `DEVSHOP_READ_TOKEN` ·
  **B** REST tarball + token · **C** git without a token. Logs to `/tmp/devshop-setup.log`
  (never the token); always exits 0.

## Run 1 — token, single repo (the planned D-01 route)

1. GitHub → Settings → Developer settings → Fine-grained token: resource owner `meirmsn`,
   repository **only abra-kadabra**, permission **Contents: read-only**, short expiry (7 days).
2. New cloud environment (or edit a spare one): add environment variable
   `DEVSHOP_READ_TOKEN` = the token (not a network secret — those are never sent to GitHub,
   LOG #7); paste `setup.sh` as the setup script.
3. Start a session in it on a repo **other than abra-kadabra** (lalista is fine — nothing is
   changed there) and paste:
   > W10.1.2 check. Show `/tmp/devshop-setup.log` (route + RESULT lines), `cat /tmp/devshop-probe-hook.log`,
   > say whether a DEVSHOP-PROBE-HOOK line is in your context, then run the devshop-probe skill.

**Expected (2026-10-11 evidence below): route A/B refused by the session proxy.**

## Run 2 — devshop attached as a second repo

Same environment and setup script; start the session with the project repo **and**
abra-kadabra both selected. Same check prompt. Tells us: is the second repo cloned before the
setup script runs (route 0), and do **user-scope** plugin hooks load in a multi-repo session
(repo `settings.json` hooks don't, F-CLOUD-02)?

Revoke the token after the runs.

## Evidence so far (this session, 2026-10-11)

- Install half works: route C (this repo is attached here) fetched the pin; marketplace add +
  install at user scope succeeded; a fresh `claude -p` (isolated `CLAUDE_CONFIG_DIR`) ran the
  skill and the hook. Route 0 verified the same way. The plugin is **read in place** from
  `/opt/devshop-pin` (not copied to a cache), so the fetched tree must persist.
- The GitHub path enforces the session's repo scope **whatever Authorization header the client
  sends**: a git fetch of the attached repo with a bogus token succeeded (proxy supplies its
  own credentials); a non-attached private repo returned the proxy's 403 "GitHub access to this
  repository is not enabled for this session" via REST both with no token and with a token
  header, and git asked for credentials. So a user token most likely can't open a non-attached
  repo — Run 1 confirms or refutes it with a real token.
- Owner run (LOG #16 addendum): the setup script runs **before/without the agent proxy** and
  without GitHub credentials, so the in-session evidence above may not apply at setup time; the
  token was not visible to the setup script. Route 0 needs the pin on the clone's branch (merge
  first, then pin the merge commit).
- **Result (owner Run 1, lalista): passed** with the token written inline in the setup script
  (environment variables don't reach it): fetched via `A:git+token`, plugin installed, skill and
  SessionStart hook loaded. Run 2 not needed.

