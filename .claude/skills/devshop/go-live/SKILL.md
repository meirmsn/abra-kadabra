---
name: ak-go-live
version: 1.4.0
description: |
  Autonomous deploy pipeline: merge → deploy → canary → reflect → notify.
  Runs after user approves PR. Chains /land-and-deploy → /canary → reflection.
  Does NOT auto-rollback — production rollbacks need human judgment.
  Use when asked to "land it", "go live", "deploy", or "merge and ship". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
---

# Go Live

Autonomous deploy pipeline: merge → deploy → canary → reflect → notify.

Run after the user has reviewed the PR and is ready to deploy.

## Step 1: Pre-flight

Verify the PR is ready:

```bash
PR=$(gh pr list --head "$(git branch --show-current)" --json number,mergeable,reviewDecision --jq '.[0]')
```

Check:

- PR exists
- CI is green (`gh pr checks`)
- No merge conflicts

If any check fails, report and stop.

## Step 1.5: Production health probe (catches pre-existing prod issues before merge masks them)

After PR readiness is confirmed but BEFORE invoking `/land-and-deploy`, curl the production URL from `CLAUDE.md § Deploy Configuration`. The goal isn't canary verification (that's Step 3 post-deploy); it's catching pre-existing production failures whose symptoms the about-to-land deploy might silently change or mask.

```bash
# Extract the bare host from the `Production URL:` line in CLAUDE.md via the
# shared helper, which tolerates the wild-seen formats (bare, backticked,
# https-prefixed) AND the URL appearing mid-sentence (home-os PR #39 hit a
# silent skip when the old inline sed glued the host to trailing prose).
# Validate as DNS-label shape, then dial with explicit https:// so the probe
# doesn't degrade to http:// + 308-redirect on HTTPS-only hosts.
# shellcheck source=/devshop/kit/scripts/lib/extract-prod-url.sh
source /devshop/kit/scripts/lib/extract-prod-url.sh
BARE_HOST=$(extract_prod_url CLAUDE.md)
if ! printf '%s' "$BARE_HOST" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$'; then
  echo "PROD_URL not configured (or malformed) in CLAUDE.md § Deploy Configuration (got: '$BARE_HOST') — skipping health probe"
  exit 0
fi
PROD_URL="https://$BARE_HOST"
echo "Probing production at $PROD_URL ..."
HTTP=$(curl -s -o /tmp/prod-preflight.html -w "%{http_code}" --connect-timeout 8 "$PROD_URL/" 2>/dev/null)
echo "HTTP $HTTP"
```

**If `HTTP` is 2xx or 3xx**: production is healthy. Continue to Step 2.

**If `HTTP` is 000** (connection failed): in-container connectivity issue, not a pre-existing prod issue — **do NOT** treat as a pre-existing prod issue or auto-roll back. Three distinct root causes share the same `HTTP 000` symptom; the disambiguation requires one extra read of the runtime allowlist file.

**First, just run the refresh script — then re-probe.** Before disambiguating Mode A/B/C, run `sudo /usr/local/bin/refresh-allowed-ips.sh` and re-probe. Vercel edge-IP rotation (the Mode C cause) is by far the common case, and a rotation can recur mid-pipeline (e.g. a fresh deploy served from new edge IPs after merge). The script re-resolves the prod host and re-adds the current edge IPs, so it usually clears the `000` in one shot. It reads the host from `/etc/refresh-allowed-ips/production_url` (populated at container start from `.env`'s `PRODUCTION_URL`) and is a **no-op when that file is empty** — so it fixes Mode C but cannot fix a genuine Mode A/B. Only fall through to the classifier below if the re-probe is still `000` after the refresh.

**Read `$ETC_FILE` WITHOUT `sudo` to classify.** The file is world-readable (`-rw-r--r-- root root`). Do NOT `sudo cat` it: if sudo is configured `NOPASSWD` only for `refresh-allowed-ips.sh` (not for `cat`), `sudo cat "$ETC_FILE" 2>/dev/null` returns empty on the password prompt and you'll misread a **populated** file as empty — downgrading a real Mode C into a phantom Mode A/B. A plain `cat` reads the true contents.

```bash
# Tri-state HTTP 000 classifier — Mode A / B / C.
# NOTE: only reach here if `sudo /usr/local/bin/refresh-allowed-ips.sh` + re-probe
# did NOT restore connectivity. Read $ETC_FILE WITHOUT sudo — it's world-readable, and
# `sudo cat ... 2>/dev/null` silently returns empty if sudo wants a password (NOPASSWD is
# scoped to refresh-allowed-ips.sh, not cat), which misclassifies a populated file as empty.
ETC_FILE=/etc/refresh-allowed-ips/production_url
HAVE_ETC=$(cat "$ETC_FILE" 2>/dev/null | tr -d '[:space:]')

if [ -n "$HAVE_ETC" ]; then
  echo "Mode C: /etc/refresh-allowed-ips/production_url is populated ($HAVE_ETC)."
  echo "HTTP 000 with /etc/ populated → Vercel rotated edge IPs since container start."
  echo "Run: sudo /usr/local/bin/refresh-allowed-ips.sh"
  echo "Then retry the probe. Full recipe: /devshop/CLAUDE.md § Known Footguns § Firewall IP rotation."
else
  echo "Mode A or B: /etc/refresh-allowed-ips/production_url is empty (0 bytes)."
  echo "Either .env never had PRODUCTION_URL set (Mode A), or .env has it but the"
  echo "container hasn't been rebuilt since (Mode B). To distinguish, ask the operator:"
  echo ""
  echo "  ! grep '^PRODUCTION_URL=' /workspace/.devcontainer/.env"
  echo ""
  echo "If the line prints a non-empty value → Mode B. Operator pasted into .env"
  echo "but skipped the rebuild. init-firewall.sh only runs at container start;"
  echo "mid-session .env edits don't propagate to /etc/. Fix:"
  echo ""
  echo "  VS Code → Cmd/Ctrl+Shift+P → 'Dev Containers: Rebuild Container'"
  echo "  After rebuild: ! cat /etc/refresh-allowed-ips/production_url   (world-readable; no sudo)"
  echo "  (should print the bare host)."
  echo ""
  echo "If empty / line absent → Mode A. Operator never pasted the URL after first deploy."
  echo "Fix: append the line, then rebuild (same /ak-new-project § Step 13 three-step procedure):"
  echo ""
  echo "  ! sudo sed -i 's|^PRODUCTION_URL=\$|PRODUCTION_URL=<bare-host>|' /workspace/.devcontainer/.env"
  echo "    (or sudo nano /workspace/.devcontainer/.env if no empty PRODUCTION_URL= line is present)"
  echo "  VS Code → Cmd/Ctrl+Shift+P → 'Dev Containers: Rebuild Container'"
  echo "  After rebuild: ! cat /etc/refresh-allowed-ips/production_url   (world-readable; no sudo)"
fi
```

**Mode A in-session escape hatch** (when the deploy is already in flight and a mid-deploy rebuild isn't acceptable): if `CLAUDE.md § Deploy Configuration § Production URL` has a known value AND `/etc/refresh-allowed-ips/production_url` is **genuinely empty** (confirm with a NON-sudo `cat`, not `sudo cat` — see the classifier note above), offer to write the bare hostname directly into the runtime file for the current session only. Note this hatch only works if `sudo tee` succeeds; where NOPASSWD is scoped only to the refresh script, it won't, and there's no in-session shortcut for a true Mode A:

```bash
# Derive bare host from CLAUDE.md via the shared helper — tolerates the
# wild-seen formats (bare, backticked, https-prefixed) AND a mid-sentence
# URL, and yields empty for an un-filled `<fill in>` placeholder (no
# hostname-shaped token), which the DNS-label check below rejects.
# shellcheck source=/devshop/kit/scripts/lib/extract-prod-url.sh
source /devshop/kit/scripts/lib/extract-prod-url.sh
BARE_HOST=$(extract_prod_url CLAUDE.md)
if ! printf '%s' "$BARE_HOST" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$'; then
  echo "Could not derive a valid bare hostname from CLAUDE.md (got: '$BARE_HOST')."
  echo "Expected format under § Deploy Configuration: 'Production URL: <your-app>.com'"
  echo "(bare hostname, no scheme, no path). Fall back to the Mode A/B fix above."
  exit 0
fi

# Ephemeral write — survives this session only, lost on next rebuild.
# WARNING: this `sudo tee` may fail with "a terminal is required to read the password"
# when sudo has NOPASSWD scoped only to refresh-allowed-ips.sh (not to tee). Unlike the
# refresh-first path, that failure is NOT harmless here: the refresh script READS the host
# FROM this file, so if the tee didn't write it, the script is a no-op and the hatch
# achieves nothing. Re-confirm the file is really empty with a NON-sudo `cat` first — a
# populated file read via `sudo cat` looks falsely empty, in which case skip this hatch
# entirely and just run the refresh script. For a genuine Mode A where the tee fails,
# there is no in-session shortcut — fall back to the paste-then-rebuild fix above.
if ! echo "$BARE_HOST" | sudo tee /etc/refresh-allowed-ips/production_url >/dev/null 2>&1; then
  echo "sudo tee failed (no NOPASSWD for tee) — cannot write \$ETC_FILE; the refresh"
  echo "script would be a no-op. No in-session shortcut: apply the permanent Mode A/B fix."
  exit 0
fi
sudo /usr/local/bin/refresh-allowed-ips.sh
echo "Session-only patch applied. The /etc/ file will revert to empty on next container"
echo "rebuild — for the permanent fix, apply the three-step procedure (paste into .env,"
echo "rebuild, verify) from /ak-new-project § Step 13."
```

Surface the ephemerality explicitly to the operator — this shortcut unblocks the current `/ak-go-live` run but does not fix the underlying gap. The operator still needs to apply the permanent three-step fix before the next session, otherwise the next container start will revert `/etc/` to empty and the next deploy lands in the same broken state.

**Continue the pipeline** in all three modes — the probe-availability gap is a connectivity issue, not a prod issue, and does not warrant a rollback. The disambiguation exists so the agent doesn't re-derive Mode A/B/C from first principles each session and so the operator gets the right next-action immediately.

**If `HTTP` is 4xx or 5xx** (a real response from the server): production has a pre-existing issue. Surface to the user via AskUserQuestion:

> Production `$PROD_URL/` is currently returning HTTP `<code>`. This is pre-existing (caught before this PR's merge), not introduced by the diff about to land.
>
> Options:
>
> - **Investigate first** — pause `/ak-go-live`; spin up a separate session to diagnose the production failure before merging anything that may interact with the same code paths.
> - **Ship + flag** — proceed with the merge if you can confirm the diff doesn't touch the failing surface; file a TODO for the prod issue with the symptoms captured.
> - **Ship and ignore** — only if you already know about this issue and are tracking it elsewhere.

**Codified from**:

- The 4xx/5xx path: lalista PR 26 (2026-04-26). Prod `/` had been returning 500 since project setup (trailing newline in `NEXT_PUBLIC_SUPABASE_URL` from a copy-paste fat-finger; SSR `getUser()` fetched the malformed URL and threw uncaught). Nobody noticed because every authenticated flow goes through `/sign-in`, which worked. Caught during this Step 1.5 probe, fixed in the same PR before merge (added `.trim()` defense at every env var read site).
- The HTTP 000 split: lalista PR 28 (2026-04-27). Pre-merge probe AND post-merge canary BOTH hit HTTP 000 within ~10 minutes of each other (Vercel rotated edge IPs since container start). The previous Step 1.5 logic lumped 000 with 4xx/5xx and asked "investigate the prod failure?" — wrong category, costing ~30 sec of disambiguation per occurrence. Step 3 already had the firewall-fallback paragraph; mirroring it here closes the gap so the agent doesn't re-derive disambiguation each session.
- The Mode A/B split: home-os PR #9 + same-day auth-magic-link session (2026-05-13). PR #9's first `/ak-go-live` ran with `/etc/refresh-allowed-ips/production_url` empty because `.env`'s `PRODUCTION_URL=` slot was never filled (Mode A). The deploy completed on indirect signals (Vercel `state=READY`, `deploy-migrations.yml` green) but the in-container canary was disabled. Operator pasted `PRODUCTION_URL=home-os-nu-two.vercel.app` into `.env` post-deploy without rebuilding → Mode B; confirmed via `sudo cat /etc/refresh-allowed-ips/production_url` returning 0 bytes with mtime = container creation, predating the `.env` paste. The prior binary "in-container vs prod" disambiguation gave identical advice for both modes — wrong-half-the-time, since Mode B operators don't need the paste step. The tri-state classifier reads `/etc/` and routes to the right next-action immediately.
- The `sudo cat` false-empty trap + refresh-first ordering: home-os PR #43 (2026-05-28). HTTP 000 hit at the Step 1.5 probe AND again post-merge (Vercel rotated edge IPs for the fresh deploy). The classifier's `HAVE_ETC=$(sudo cat "$ETC_FILE" 2>/dev/null …)` returned empty and the agent diagnosed Mode A/B — but `/etc/refresh-allowed-ips/production_url` was actually **populated** (`home-os-nu-two.vercel.app`). `sudo cat` had silently failed on the password prompt (NOPASSWD was scoped to `refresh-allowed-ips.sh`, not `cat`), and `2>/dev/null` hid it, so a populated, world-readable (`0644`) file read as empty. It was always Mode C (pure edge-IP rotation); `sudo /usr/local/bin/refresh-allowed-ips.sh` fixed it both times because the file it reads was populated all along. Fixes: (1) read `$ETC_FILE` with a plain `cat`, never `sudo cat`, so a password-gated sudo can't fake an empty result; (2) run the refresh script first + re-probe, since rotation is the common cause and recurs post-merge; (3) the refresh script reads the host FROM `$ETC_FILE` and is a no-op when it's empty, so the Mode A escape hatch's `sudo tee` failing (same NOPASSWD scope) genuinely breaks the hatch — it is not "harmless," there's just no in-session shortcut for a true Mode A.

The probe is a single curl; it adds <1s in the green path and saves a fix-loop on the red path.

## Step 1.6: Migration sequencing pre-flight (catches non-additive migrations before the parallel-deploy race)

Only fires when the PR diff touches `supabase/migrations/**`. The architecture's implicit assumption is that all migrations are backwards-compatible in **both** directions during the PR window — new code on old schema works (handles missing column gracefully), AND old code on new schema works (new NOT NULL column has a default). Additive migrations satisfy this; mutating migrations (renames, drops, NOT NULL without default, type changes) violate it — they break Vercel preview during the PR window AND cause a ~30–60s post-merge race where prod runs new code against the old schema before `deploy-migrations.yml` finishes.

```bash
BASE=${BASE:-main}
MIGRATIONS_TOUCHED=$(git diff --name-only "origin/${BASE}...HEAD" 2>/dev/null | grep -E '^supabase/migrations/' || true)
[ -z "$MIGRATIONS_TOUCHED" ] && : # no migration changes; skip the rest of Step 1.6
```

If the diff touches migrations, classify each touched file. Honor a pre-declared classification when present:

1. **Spec pre-declaration** (preferred). If `specs/<feature>/spec.md` has a `## Migration Sequencing` section recording the migration's compatibility + deploy plan, trust that classification. Track A of the migration-sequencing convention plants this at spec time; this step is its enforcement point.

2. **Heuristic classification** (fallback when the spec didn't pre-declare). Scan each touched file for mutating signals; if any fire, treat as mutating:

   ```bash
   for f in $MIGRATIONS_TOUCHED; do
     # Mutating signals (any one match → mutating):
     #   DROP TABLE / DROP COLUMN / DROP CONSTRAINT
     #   RENAME (table or column)
     #   ALTER COLUMN ... TYPE
     #   ALTER COLUMN ... SET NOT NULL (without an accompanying DEFAULT in same file)
     # Additive (none of the above):
     #   CREATE TABLE / CREATE INDEX / CREATE POLICY
     #   ALTER TABLE ... ADD COLUMN [... DEFAULT ...]
     grep -iE 'DROP (TABLE|COLUMN|CONSTRAINT)|RENAME (TABLE|COLUMN|TO)|ALTER COLUMN .* (TYPE|SET NOT NULL)' "$f" || true
   done
   ```

   When the heuristic is ambiguous (mixed signals, novel DDL shape), prefer the **mutating** default — a false positive costs one operator-question; missing a real mutating migration costs a ~30–60s prod brownout.

If every touched migration is **additive** → continue to Step 2. The post-merge `deploy-migrations.yml` race is fine per the existing comment in that workflow (new code handles missing column with default; old code ignores added column).

If any migration is **mutating** → BEFORE invoking `/land-and-deploy`, surface via AskUserQuestion:

> The PR's migration `<NNN>_<name>.sql` is mutating (rename / drop / NOT NULL without default / type change). After merge, Vercel auto-deploys the front-end in parallel with `deploy-migrations.yml`; for ~30–60s prod runs new code against the old schema → user-visible 500s. Vercel preview during the PR window also reads prod, so reviewers may see breakage that looks like a real bug.
>
> Options:
>
> - **Apply migration to prod first, then merge** (recommended). Run `supabase db push --include-roles` against prod via the operator-side path the project documented in `CLAUDE.md` (Path A: password-manager CLI like `op read`; Path B: `!`-prefix shell escape with `read -s`), OR trigger `deploy-migrations.yml` via `gh workflow run`. Confirm prod schema is M+1 (e.g. via `supabase db diff` or a direct query). THEN merge the code PR. Closes the parallel-deploy race window.
> - **Merge anyway, accept brief breakage** — only if `specs/<feature>/spec.md § Migration Sequencing` already documented this as an accepted trade-off (timeboxed: "preview is intentionally broken from PR-open to PR-merge; expect <2hr").
> - **Pause and re-spec** — the spec author skipped Track A's scoping question. Surface the gap, update the spec, then resume `/ak-go-live`.

**Codified from**: `kit/ROADMAP.md § Migration sequencing safety nets for the Vercel-preview window` (Track B). This step adds the **pre-merge** half of the migration-sequencing discipline; the **post-merge** half is already documented in the sequencing-note comment of `apps/web/.github/workflows/deploy-migrations.yml`.

## Step 1.7: Auth-config deploy reminder

Vercel app + Supabase migrations + edge functions all auto-deploy on push:main. **Auth config** (`site_url`, `uri_allow_list`, password policy, CAPTCHA, email templates) does NOT — it ships via the Supabase dashboard or `PATCH /v1/projects/{ref}/config/auth` manually.

If the spec or PR body references auth-config changes, surface to the user before merge:

> The PR references auth-config changes that don't auto-deploy with the merge. Apply them via the Supabase dashboard or Management API now, ideally **before** the app deploy if the new code relies on new redirect URLs / CAPTCHA / password policy. Auth-config changes are cheap to roll back (re-PATCH), so ordering is flexible — but they must ship manually.

### Deploy surfaces

Every Supabase-backed project has multiple deploy surfaces; deploying one does NOT deploy the others. `git push` / PR merge only triggers the Next.js app deploy — Supabase migrations, edge functions, and auth config stay untouched unless the corresponding workflow fires or you run the command explicitly.

| Surface                 | How it deploys                                                                                                              | Trigger                                  | `/ak-go-live` covers? |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | --------------------- |
| Next.js app (Vercel)    | Automatic on push — preview on PR, production on merge                                                                      | `git push` / PR merge                    | Yes                   |
| Supabase migrations     | `.github/workflows/deploy-migrations.yml` runs `supabase db push --include-roles` (path-filtered to `supabase/migrations/`) | Auto on push:main when migrations change | Yes (via the merge)   |
| Supabase edge functions | `.github/workflows/deploy-functions.yml` runs `supabase functions deploy` per dir (path-filtered to `supabase/functions/`)  | Auto on push:main when functions change  | Yes (via the merge)   |
| Supabase auth config    | Management API `/v1/projects/{ref}/config/auth` or dashboard                                                                | Manual, per change                       | No (manual)           |

### Schema-mutating migration safety

Schema-mutating migrations (renames, drops, NOT NULL without default, type changes) need extra care because migrations + Vercel deploy race in parallel on push:main. Schema-additive migrations (new columns/tables, defaults, NOT NULL only on backfilled columns) are safe — old code keeps working on the new schema.

For schema-mutating migrations, two options:

1. **Mark as backwards-incompatible in the PR description** and gate merge on the deploy-migrations workflow finishing first. Brief window where old code sees new schema.
2. **Split into two PRs**: PR 1 ships additive migration + dual-shape code paths. PR 2 ships the mutating migration + cleanup. Slower but window-free.

Default to option 2 for prod-impact mutations; option 1 is fine for low-traffic windows on solo-dev projects. The functions-vs-app race is symmetric and follows the same remedy.

### Rollback

Rollback is reverse-order across all surfaces with the same backwards-compatibility caveats: revert the app first to pull traffic off the new schema/functions, then roll back migrations (if the migration's `-- ROLLBACK` block supports it) and edge functions.

### CI-vs-prod credential separation

CI-vs-prod credential separation is the structural enforcement of the deploy boundary. Deploy workflows hold prod-grade Supabase credentials; fast-job + slow-job CI use the local-stack defaults. The `assertNotProdUrlInTestEnv` helper in `packages/core/src/supabase.ts` throws if `NODE_ENV=test` ever passes the prod URL. Full detail: `/ak-new-project § Security Posture`.

## Step 1.8: Pending tasks pre-flight surface

`/ak-build`'s PR body convention reserves specific section headers for tasks the deploy needs to be aware of:

- `## Out-of-band deploy items` — work that doesn't auto-deploy with the merge (e.g., `supabase functions deploy <name>`, paste email templates into the dashboard, run `terraform apply`, update an auth allow-list). These are **deploy prereqs** — the deploy is not "live" until they're done.
- `### Manual review` — visual / spec / intent items for the human PR reviewer. Already-approved by the time `/ak-go-live` runs; surface as a reminder, not a gate.
- `## Operator follow-up` (when present) — post-deploy reminders (e.g., "monitor the metric dashboard for 24h", "follow up with the legal team on copy"). Surface as a reminder, not a gate.
- `## Test plan` `[ ]` items — checkboxes `/ak-build` Phase 5.3's auto-marker should have flipped on CI green. A leftover `[ ]` here usually means the bookkeeping was skipped (legacy build, hotfix PR, or Phase 5.3 silently failed) — surface as a sanity-check signal.

This step pulls every `[ ]` checkbox from the merging PR's body + the latest audit / ready-for-review comments, groups them by section, annotates each (`[manual]` / `[deferred]` / `[!]`), and prints a single "Pending tasks before live" view so the operator sees at a glance what they own. The deploy then blocks (via `AskUserQuestion`) only on `[manual]` items under `## Out-of-band deploy items` — the other categories are non-blocking reminders.

```bash
PR=${PR:-$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')}
[ -z "$PR" ] && echo "No open PR found — skipping pending-tasks surface" && exit 0

# Pull body + relevant comments. Scan only comments matching the canonical
# /ak-build Phase 6 / Phase 7 headers — don't accidentally parse a reviewer's
# casual comment that happens to contain `[ ]` markdown.
gh pr view "$PR" --json body --jq .body > /tmp/pending-pr-body.md
gh pr view "$PR" --json comments --jq '
  [.comments[] | select(.body | test("^## (Pre-ship audit trail|Ready for review)"; "m"))]
  | .[].body' > /tmp/pending-pr-comments.md
```

Parse the combined input. The classifier groups items by their nearest-enclosing recognized header (h3 wins over h2 when items live under both, since `### Manual review` is nested inside `## Test plan`):

```bash
awk '
  BEGIN { section = "Other"; in_comment = 0 }
  /^## (Out-of-band deploy items|Operator follow-up|Test plan)/ { section = $0; sub(/^## */, "", section); next }
  /^### (Manual review|CI gates)/ { section = $0; sub(/^### */, "", section); next }
  /^## / { section = "Other"; next }
  /^- \[ \] / {
    item = $0; sub(/^- \[ \] */, "", item)
    print (in_comment ? "(comment) " : "") section "\t" item
  }
' /tmp/pending-pr-body.md > /tmp/pending-items.tsv

awk '
  BEGIN { section = "Other"; in_comment = 1 }
  /^## (Out-of-band deploy items|Operator follow-up|Test plan)/ { section = $0; sub(/^## */, "", section); next }
  /^### (Manual review|CI gates)/ { section = $0; sub(/^### */, "", section); next }
  /^## / { section = "Other"; next }
  /^- \[ \] / {
    item = $0; sub(/^- \[ \] */, "", item)
    print "(comment) " section "\t" item
  }
' /tmp/pending-pr-comments.md >> /tmp/pending-items.tsv
```

Annotate by section, then print:

| Section                    | Annotation   | Blocks merge?             |
| -------------------------- | ------------ | ------------------------- |
| `Out-of-band deploy items` | `[manual]`   | **Yes**                   |
| `Operator follow-up`       | `[manual]`   | No                        |
| `Manual review`            | `[deferred]` | No                        |
| `Test plan` / `CI gates`   | `[!]`        | No (sanity-check only)    |
| `Other`                    | `[manual]`   | No (default conservative) |

Anything the future Arm B automates flips from `[manual]` to `[auto]` — Arm A surfaces only `[manual]` / `[deferred]` / `[!]` because no automation core exists yet.

If `/tmp/pending-items.tsv` is empty (PR doesn't follow `/ak-build`'s convention — e.g., a hotfix opened by hand), print "No structured pending tasks found in PR body — proceeding" and continue without blocking. Operator can manually verify out-of-band steps.

Otherwise print the grouped output and gate on the prereq bucket:

```
Pending tasks before live (PR #<N>):

[manual] (blocks — Out-of-band deploy items):
  - <item 1>
  - <item 2>

[manual] (Operator follow-up — non-blocking, surfaced as reminder):
  - <item>

[deferred] (Manual review — for PR reviewer; non-blocking):
  - <item>

[!] (Test plan checkboxes auto-marker should have flipped — sanity check):
  - <item>
```

If the `[manual]` blocking bucket is non-empty, surface via `AskUserQuestion`:

> **Pending out-of-band deploy items** — these need to be done for the deploy to be considered live. `/ak-go-live` cannot do them automatically (the automation core is scoped at `kit/ROADMAP.md § /ak-go-live post-merge prod-config sync (Arm B — automation core)` — Management API integration + `SUPABASE_ACCESS_TOKEN` credential surface — and remains deferred). Pick:
>
> - **Done — proceed** — operator confirms the items above are already complete or will be done as part of this deploy session; continue to Step 2.
> - **Pause** — pause `/ak-go-live` so the operator can complete the items first, then resume by re-invoking `/ak-go-live`.
> - **Skip — accept the gap** — proceed without the items; deploy lands but is not fully live until the operator catches up. Use only if the items are post-merge in nature (e.g., "re-run the prod advisor" — informational) and don't gate user-facing functionality.

If empty, print "No blocking pending tasks — proceeding" and continue to Step 2.

**Codified from**: `kit/ROADMAP.md § /ak-go-live post-merge prod-config sync (Arm B — automation core)` — that entry's "Status" line points back here for Arm A. Arm B (Management API integration that converts most `[manual]` items to `[auto]` — email-template push, allow-list verify, asset reachability check) is scoped in the same ROADMAP entry but remains deferred; until it ships, every `[ ]` item in `Out-of-band deploy items` is `[manual]` and the operator sees them all.

## Step 2: Land and deploy

### Step 2.0: Working-tree cleanliness gate

Before invoking `/land-and-deploy`, verify the working tree is clean. `gh pr merge --squash --delete-branch` runs `git checkout <base>` under the hood after the squash; if local changes exist that would be overwritten, the merge fails mid-flight — but on the GitHub side it has often already merged the PR + deleted the remote branch (irrecoverable state if you weren't expecting it). The local error message `failed to run git: error: Your local changes to the following files would be overwritten by checkout` is confusing because it sounds like nothing happened; the user has to inspect GitHub to discover the merge already shipped.

```bash
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ]; then
  echo "✖ Step 2.0: working tree is dirty — would corrupt mid-merge."
  echo "$DIRTY" | head -10
  # Surface to operator via AskUserQuestion with three options:
  #   A) commit the changes on the feature branch (if they're feature-related)
  #   B) stash them (if they're unrelated session noise)
  #   C) abort /ak-go-live so the operator can sort it out
fi
```

Common offenders the agent should recognize:

- **Subagent artifact left uncommitted** — e.g., Phase 5.8's `## Audit N` section in `review.md` (codified in `/ak-build` Phase 5.8.3's commit-or-surface rule, but a stale skill version may have shipped without it). If the dirty file is a `specs/<feature>/review.md` or similar feature artifact, option A (commit on the feature branch) is the right call — the file belongs in the PR.
- **Editor / session noise** — e.g., `.vscode/settings.json` from a different session. Option B (stash) keeps the merge clean.
- **Actual in-progress work** — option C (abort) lets the operator finish or roll back deliberately.

**Codified from**: home-os PR #26 (2026-05-16). Phase 5.8 subagent wrote Audit-2 to `review.md` but didn't commit; `/ak-go-live` Step 2's `gh pr merge --squash --delete-branch` failed mid-checkout AFTER the GitHub-side merge + branch deletion already shipped. The local error message read like the merge hadn't happened. Two-fix combo: `/ak-build` Phase 5.8.3 now commit-or-surfaces (be0535d on devshop), AND this step now pre-checks the tree before invoking `gh pr merge` so the next class of leftover-artifact never reaches the failure path.

### Step 2.1: Invoke `/land-and-deploy`

Invoke `/land-and-deploy` via Skill tool.

gstack's `/land-and-deploy`: checks CI green, merges PR, waits for deploy, verifies
production health. If CI is failing, it stops (does not merge).

## Step 2.5: Rewrite PR-body image URLs to merge SHA

PR body image embeds use the form `https://github.com/<owner>/<repo>/raw/<feature-branch>/<path>` per `/ak-build § PR body conventions § Image embeds — private-repo safe`. The `<feature-branch>` ref renders fine at PR-review time, then 404s the moment Step 2b runs `git push origin --delete` / `gh pr merge --delete-branch` removes the branch ref. This step rewrites every such URL in the PR body to repoint at the squash-merge commit SHA — a **permanent** ref that survives branch deletion. Order is load-bearing: this step runs **after** Step 2's merge produces a SHA but **before** Step 2b's branch cleanup so the URLs in the body are re-anchored before the branch they currently point at goes away.

The rewrite logic lives in a tiny sourceable helper at `/devshop/kit/scripts/lib/rewrite-pr-body-urls.sh` so the same `rewrite_pr_body_urls()` function is shared with `kit/scripts/backfill-pr-image-urls.sh` (the one-time per-project backfill that catches up the existing surface) — single source of truth, no behavior drift.

```bash
# shellcheck source=/devshop/kit/scripts/lib/rewrite-pr-body-urls.sh
source /devshop/kit/scripts/lib/rewrite-pr-body-urls.sh

if [ -z "${PR:-}" ]; then
  # Step 1's pre-flight populates $PR; only enter this fallback when this
  # step is invoked directly (e.g., resume mid-pipeline). Re-derive it from
  # the latest merged PR pointing at this commit, NOT from the local
  # working-tree branch — matches D2's "PR-derived is the canonical source
  # of truth" rule applied below to HEAD_REF.
  PR=$(gh pr list --state merged --search "$(git rev-parse HEAD)" --json number --jq '.[0].number // empty')
fi
if [ -z "$PR" ]; then
  echo "Step 2.5: no merged PR found for current commit — skipping body rewrite"
else
  # PR-derived branch name is the canonical source of truth (D2) — robust
  # against working-tree state if any prior step accidentally checked out main.
  HEAD_REF=$(gh pr view "$PR" --json headRefName --jq .headRefName)

  # mergeCommit.oid is the canonical permanent reference (D3). Squash merge
  # produces a single new commit on main; branch-tip SHAs may be GC'd after
  # --delete-branch.
  MERGE_SHA=$(gh pr view "$PR" --json mergeCommit --jq '.mergeCommit.oid // empty')

  OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

  if [ -z "$MERGE_SHA" ]; then
    # D5: null mergeCommit.oid means the operator did something out-of-band
    # (rebase merge, manual). Don't halt their flow; just don't rewrite URLs
    # we can't anchor to a permanent SHA.
    echo "⚠ Step 2.5: no mergeCommit.oid — skipping body rewrite"
  else
    BODY_TMP=$(mktemp)
    BODY_REWRITTEN=$(mktemp)
    gh pr view "$PR" --json body --jq .body > "$BODY_TMP"

    # Exact-match on /raw/<HEAD_REF>/ scoped to OWNER_REPO (D4). Other
    # /raw/<x>/ URLs (other branches, tags, main, third-party repos) are
    # preserved verbatim — the helper regex-escapes HEAD_REF so slashed
    # branch names like `feat/foo` work without spurious matches on
    # sibling URLs like `/raw/featXfoo/`.
    rewrite_pr_body_urls "$BODY_TMP" "$BODY_REWRITTEN" "$OWNER_REPO" "$HEAD_REF" "$MERGE_SHA"

    # If zero matches, helper printed `no /raw/${HEAD_REF}/ URLs in body —
    # nothing to rewrite` to stderr (D6 silent attesting pass) and copied
    # the body verbatim. Skip the gh pr edit call in that case so we don't
    # bump updatedAt without a real change.
    if ! cmp -s "$BODY_TMP" "$BODY_REWRITTEN"; then
      # Use --body-file (file on disk) not --body (shell-arg, which adds a
      # trailing newline) so byte-identical whitespace is preserved EXCEPT
      # for the URL substitutions.
      gh pr edit "$PR" --body-file "$BODY_REWRITTEN"
    fi

    rm -f "$BODY_TMP" "$BODY_REWRITTEN"
  fi
fi
```

This step is purely additive in the pipeline — failure paths warn-and-continue, never halt the deploy. Track B's one-time backfill (`kit/scripts/backfill-pr-image-urls.sh`) catches up existing closed PRs that pre-date Step 2.5; per-PR Track A coverage applies forward from this version.

## Step 2b: Branch cleanup + PLAN.md / BUILD-LOG sanity check

After merge, clean up the feature branch locally and prune stale remote refs. `PLAN.md` + `BUILD-LOG.md` are closed by `/ak-build` Phase 4.0 on the feature branch **before `/ship` pushes** (with Phase 5.6 as a verify-only fallback), so by this point main already has the ship entry in `BUILD-LOG.md` and no longer references `$FEATURE_BRANCH` in `PLAN.md § Active`. This step is branch hygiene only — no commits on main, no second PR.

```bash
FEATURE_BRANCH=$(git branch --show-current)
git checkout main
git pull
git branch -D "$FEATURE_BRANCH"
git remote prune origin
```

### Sanity check — did Phase 4.0 / 5.6 fallback run?

Verify that `PLAN.md § Active` no longer references `$FEATURE_BRANCH`. If it does, both Phase 4.0 (the common path) and Phase 5.6's verify-only fallback were skipped — legacy build, manual PR that didn't use `/ak-build`, or both phases silently failed. Do NOT auto-commit the close-out — Claude can't commit to main, and the whole point of the feature-branch bookkeeping is to avoid a second PR.

```bash
if awk '/^## Active/,/^## Planned/' PLAN.md | grep -qF "$FEATURE_BRANCH"; then
  echo "⚠  PLAN.md still shows $FEATURE_BRANCH under ## Active."
  echo "   /ak-build Phase 4.0 (and 5.6 fallback) appears to have skipped."
  echo "   Ask the user to manually:"
  echo "     1. Edit PLAN.md — remove the $FEATURE_BRANCH row from ## Active"
  echo "     2. Edit BUILD-LOG.md — add the ship entry for $FEATURE"
  echo "     3. Commit on main as 'chore: close $FEATURE' (human-initiated commits to main are allowed)"
  echo ""
  echo "   Continuing /ak-go-live; the cleanup is non-blocking for deploy verification."
fi
```

The sanity check surfaces the issue; it does not block or auto-fix. A clean Phase 4.0 run leaves this check a silent pass.

## Step 3: Canary monitoring

Invoke `/canary` via Skill tool.

~15 min post-deploy monitoring: console errors, performance regressions, page failures.

### Firewall-IP-rotation fallback (if canary can't reach prod)

If `/canary`'s curl reports `HTTP 000` with `Failed to connect ... No route to host`, this is an in-container firewall issue, not a prod issue. Run the **tri-state HTTP 000 classifier from Step 1.5** to route to the right next-action (Mode A: paste + rebuild; Mode B: rebuild; Mode C: `sudo /usr/local/bin/refresh-allowed-ips.sh`). As Step 1.5 now spells out, the first move is just `sudo /usr/local/bin/refresh-allowed-ips.sh` + re-probe — the script resolves the host on its own and usually clears the 000 in one shot (edge-IP rotation can recur post-merge when the fresh deploy is served from new IPs). The Mode A in-session escape hatch from Step 1.5 also applies, but its `/etc/` write is best-effort (the `sudo tee` can fail harmlessly) — the refresh script is what actually unblocks the canary run. If neither the tri-state recovery nor the escape hatch reaches prod (genuinely rare), produce an operator-side `! curl <PROD_URL>` paste or a "open in browser and tell me what you see" ad-hoc to complete canary verification.

Codified from lalista PR 26 (2026-04-26): `/ak-go-live` Step 3 hit `No route to host` on `lalista-ten.vercel.app` because Vercel rotated edge IPs since container start. The refresh-script recovery (added 2026-05-09) closes this gap in-session; the operator-side fallback above is the escape hatch if the script can't help.

**If canary fails**: STOP. Do NOT auto-rollback. Post rollback info and notify user:

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)
PR=$(gh pr list --state merged --head "$(git branch --show-current)" --json number --jq '.[0].number')

gh pr comment "$PR" --body "## Canary FAILED — action needed

@${GITHUB_USER} Canary detected issues after deploy.

**Issues found:** <summary from canary output>

**Rollback checkpoint:**
- Vercel deployment: \`vercel ls --meta\` (revert with \`vercel rollback\`)
- Migration version: <latest file in supabase/migrations/>
- Git SHA: $(git rev-parse HEAD)

**Recommended action:** \`vercel rollback\` then investigate on the branch.
See kit/docs/guide/ § When Things Go Wrong."
```

**If canary passes**: continue.

## Step 4: Rollback checkpoint

Record for future reference (even on success):

```bash
echo "Rollback checkpoint:"
echo "  Vercel: $(vercel ls --meta 2>/dev/null | head -2 || echo 'run vercel ls')"
echo "  Migration: $(ls -1 supabase/migrations/ 2>/dev/null | tail -1 || echo 'none')"
echo "  Git SHA: $(git rev-parse HEAD)"
```

## Step 5: Structured reflection

The natural reflection moment — the work just shipped, learnings are fresh. Two distinct categories of capture, both required:

### 5a: Project-side reflection

Ask yourself and route learnings to **committed files** (not memory):

- New conventions, gotchas, calibration updates → project `CLAUDE.md`
- Troubleshooting entries (date, symptom, cause, fix) → `kit/docs/guide/ § Troubleshooting`
- Decision log entries ("chose X over Y because Z, date") → `kit/docs/guide/ § Decision Log`
- Confidence calibration adjustments → project `CLAUDE.md § Confidence Calibration`

Commit (project repo): `docs: post-deploy reflection for <feature-name>`. **If the project enforces PR-only main** (branch protection / pre-push hook blocking direct pushes — most production projects do), open a small focused PR with just this docs commit (e.g., `docs/<feature>-reflection`). The reflection is small enough that the PR overhead is acceptable; merging it through the same gates the feature went through keeps main's history clean. Don't try to bundle the reflection into the original feature PR retroactively (already merged) or skip it (loses the capture moment).

If nothing project-specific to capture (the bug + commit message + spec docs already carry the context), skip this sub-step. Don't add CLAUDE.md noise for self-evident lessons — see today's prompt: _"the next time this kind of issue hits, the 500 itself is the signal."_

### 5b: Devshop-side generalization (catches lessons that should leave this project)

Did this PR's investigation surface anything that would generalize **beyond this project**? Most sessions produce 0; some produce many. Examples in order of typical leverage:

- **Skill amendment** — a rule that should fire in `/ak-build` / `/ak-go-live` / `/ak-spec` / `/ak-implement` / `/ak-tests-review` / `/ak-pre-ship`. Add to the SKILL.md where the action happens, not just to a guide doc — guide docs are Tier 3 and don't auto-load. Pattern: operational copy in the skill, one-line stub in the guide.
- **Template fix** — boilerplate in `template/` (or referenced from `/ak-new-project Step <N>` if scaffolded inline). Other projects scaffolding from the template inherit on next setup.
- **New convention or extension to an existing one** — `kit/docs/guide/conventions.md` (Tier 3 reference; pair with a skill amendment that actually fires the rule).
- **`/devshop/CLAUDE.md` Tier 1 entry** — for cross-cutting principles that need to be always-loaded.
- **`kit/ROADMAP.md § v0 / v1`** — work that's bigger than an inline edit and worth filing for later, OR an audit/sweep that needs a focused session.

For each lesson, present: _what was learned, proposed devshop placement, effort estimate_. The user picks which to ship now vs file vs skip.

If nothing this session, just say so — explicitly. Don't fish for lessons; most sessions don't produce them. The signal is high but the rate is low.

**Don't wait to be prompted.** Surfacing devshop-generalizable lessons is the agent's job, not the user's. Lalista PR 26 produced 8 generalizations (firewall closure rule, trace.zip discipline, conventions audit + reviewer-reads-conventions ROADMAP entries, prod-curl probe, firewall-IP-rotation fallback, .trim() defense convention, CSP scheme handling, Realtime publication, WebKit hydration race, edge-runtime retry — all shipped to devshop within the same session). Without this prompt earlier in the session, only 0-1 would have surfaced via ad-hoc memory or a follow-up "anything else?" from the user.

Commit (devshop repo, separate from project commit): per-concept atomic commits per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` and `/ak-build § Phase 4.0 step 4` (if any tracker entries close as part of the lessons surfaced).

## Step 6: Notify

The deployed-to-prod comment is the celebration moment — the operator
may copy-paste / screenshot it to share with stakeholders, Slack, or a
customer-facing changelog. Lead with the **Headline blurb** from
`spec.md § Product update § Headline` verbatim (marketing-grade, zero
eng terms — the right voice for that audience). Follow with the
**Detail blurb** as a second paragraph for the on-PR reader who wants
team-facing context.

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)
PR=$(gh pr list --state merged --head "$(git branch --show-current)" --json number --jq '.[0].number')

# Resolve the merged PR's feature dir — Step 2 keeps $FEATURE_DIR in scope.
FEATURE_DIR="${FEATURE_DIR:-specs/$(git branch --show-current | sed 's|^feat/||;s|^fix/||;s|^docs/||;s|^chore/||')}"

# Pull both blurbs from spec.md verbatim. Falls back to the combined
# shape if the spec used `### Headline + Detail (combined)`.
HEADLINE_BLURB=$(awk '/^### Headline \(user-facing\)/,/^###|^## /' "$FEATURE_DIR/spec.md" 2>/dev/null | sed '1d;$d')
DETAIL_BLURB=$(awk '/^### Detail \(team-facing\)/,/^###|^## /' "$FEATURE_DIR/spec.md" 2>/dev/null | sed '1d;$d')
if [ -z "$HEADLINE_BLURB" ] && [ -z "$DETAIL_BLURB" ]; then
  COMBINED=$(awk '/^### Headline \+ Detail \(combined\)/,/^###|^## /' "$FEATURE_DIR/spec.md" 2>/dev/null | sed '1d;$d')
  HEADLINE_BLURB="$COMBINED"
  DETAIL_BLURB="$COMBINED"
fi

gh pr comment "$PR" --body "## Deployed to production

@${GITHUB_USER} Deploy complete. Canary passed.

${HEADLINE_BLURB}

${DETAIL_BLURB}

**Production URL:** <from deploy config>
**Rollback SHA:** $(git rev-parse HEAD)
**Reflection:** committed in $(git log --oneline -1)"
```

If `spec.md § Product update` is missing (pre-convention spec), fall
back to a minimal `Deploy complete. Canary passed.` shape with no
product blurbs and emit a one-line warning that the spec predates the
Product update convention — don't halt; older specs ship as-is.
