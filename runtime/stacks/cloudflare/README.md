# Cloudflare

The home for a project on Cloudflare Workers: what the owner's website shipped (W10.10.1, the first
real project) and what the M1 fixture (Workers + D1) proved before it. It loads when the project has a
wrangler config ([`detect`](detect)). Everything here was read from those two repos' files, PRs and
specs; a rule with no project behind it says so. The project's own `CLAUDE.md` wins on conflict; say
so in the PR.

## The shape of a project

- **One Worker, named in `wrangler.jsonc`**, deployed only from `main` by CI. The website is a static
  site: `scripts/build.sh` copies `site/` into `dist/` and writes `dist/build.txt` (the commit), and
  the Worker serves `dist/` as static assets (`"assets": { "directory": "./dist" }`); no framework
  was picked, because the first change didn't need one (its spec says the first change that does
  picks it). The fixture was a Worker with code (`"main"`) and one D1 database.
- **The config holds no identifiers:** no account id, no `routes`, no hosts. `workers_dev: true`,
  `preview_urls: false` (no per-version preview URLs on the production account),
  `observability: { "enabled": true }` (Workers Logs), a `compatibility_date`. Account id and token
  come from the GitHub environment at deploy time.
- **Pinned tools:** `wrangler` in `package.json` (the website: 4.149.0), Node in `.nvmrc` (22),
  Playwright for the slow tier. `scripts/setup.sh` is `npm ci --no-audit --no-fund`; CI's three
  jobs run it after `actions/setup-node` with `node-version-file: .nvmrc` and `cache: npm` (the
  template's "stack tool installs" lines). `.gitignore`: `node_modules/`, `.wrangler/`, `dist/`,
  `.dev.vars*`, `.env*`, and the generated preview config `wrangler.preview.json`.
- **Routes:** every page is in `quality/routes.json`; a change that adds a page adds its path, so the
  quality bar and the deploy's checks cover it (the fixture's `traffic/routes.json`, same rule). The
  fixture gave each route synthetic traffic; a static site gets a smoke check instead, and
  W10.10.5's canary fetches every listed path after the deploy.

## Deploy, with the day-one rollback

The template's `deploy` job (`runtime/templates/ci.yml`) runs the project's `scripts/deploy.sh` on
`main` after `fast` and `slow`, in the `production` environment, concurrency group `production`
without cancelling. The website's `scripts/deploy.sh` is the reference; a new project copies it and
its test (`tests/deploy.test.sh`, fake `wrangler` and `curl`, no network), and the preview scripts
below, from the website until the devshop carries them as tested templates (deferred with TARGET
Reach 5; FINDINGS F-NEW-100). A session is attached to its own repo, so it asks the owner to attach
the website's repo read-only for that change (the owner agrees per TARGET Safety 9; this home was
written the same way), names the files it copied and their source commit in the PR, and writes
nothing there. What `deploy.sh` does, in order, and why:

1. **Refuses the wrong Worker.** It reads the config's `name` with wrangler's own reader and exits 2
   unless it equals `$DEPLOY_NAME` (default `website`). The production account also holds a Worker
   that isn't the site's; nothing in CI may deploy, roll back or delete it.
2. **Builds** with `BUILD_SHA` (the commit CI checked out), so `dist/build.txt` names the build the
   smoke check must find live.
3. **Records the version live now, before anything changes:** `wrangler deployments status --json`;
   a Worker that doesn't exist yet (error 10007) or has no deployment is a first deploy
   (`previous_version=none`); any other failure stops the run with nothing deployed, because a deploy
   that can't be rolled back isn't made. It writes `previous_version` and the `rollback` line to
   `$GITHUB_OUTPUT` first: `npx wrangler rollback <version id> --name <worker>` (or the dashboard,
   Workers → the Worker → Deployments) when one version was at 100%; a split deployment is recorded
   whole and restored in the dashboard. The owner runs the rollback, never a session (below).
4. **Deploys:** `wrangler deploy --config <config>` with `WRANGLER_OUTPUT_FILE_PATH`, from which it
   reads the `workers.dev` URL and the new `version_id`; `deployed=yes` goes out the moment the upload
   happened, so a later failure's comment can say "may be live". The fixture applied its D1
   migrations here first (`wrangler d1 migrations apply <db> --remote`), before the new code.
5. **Smoke-checks** the `workers.dev` URL, then `$SITE_URL` (the domain, a `production` environment
   variable; unset skips it and says so): `/build.txt` equals the commit and `/` has a `<title>`,
   **twice in a row** within 10 tries 6 s apart, because a new `workers.dev` route reaches the edges
   one by one and one request can pass while the next 404s (fixture run 2). A failure exits 1 with
   the rollback line. The fixture's check was `/healthz` (the Worker reaches D1) plus the page's
   `<h1>`.
6. **Writes the record:** a job-summary table (commit, new version, previous version, URL, how to
   undo) and the outputs the deploy comment reads: `url`, `version`, `previous_version`, `rollback`,
   `deployed`, `site_url`, `site_smoke` (`passed`, `failed`, `skipped`). The merged PR's comment then
   says "Live in production", the version it replaced and that the domain serves this build.

The deploy step's `env` in `ci.yml`: `CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}`,
`CLOUDFLARE_ACCOUNT_ID: ${{ vars.CLOUDFLARE_ACCOUNT_ID || secrets.CLOUDFLARE_ACCOUNT_ID }}`,
`BUILD_SHA: ${{ github.sha }}`, `SITE_URL: ${{ vars.SITE_URL }}`. Nothing else; the comment steps
get the job's GitHub token only.

**Rules a session keeps** (the website's and the fixture's `CLAUDE.md`):

- Deploys happen only from `main`, in CI. Never run `wrangler deploy`, `wrangler rollback`,
  `wrangler delete` or a `--remote` migration from a session. Rollback is the owner's call (TARGET
  Ship 6): the session prepares the revert PR and names the platform rollback from the deploy record.
- No account ids, database ids, tokens or deploy hosts in the repo's config. The site's public domain
  may appear in page content when its spec says so (the website: the email, `og:url`, `og:image`).
- **Migrations are append-only and backward-compatible** (expand / contract): add a file under
  `migrations/`, never edit or delete one that is on `main`; the previous app version must keep
  working, so a code rollback never needs a data rollback (D-17 item 2). They run in the deploy job,
  before the new code, resolved by database name from the config. A destructive step (dropping a
  column or table, rewriting data) is a later, separate change with a reverse migration tested in CI
  or a D1 Time Travel restore point taken just before the deploy, and the PR says which (TARGET
  Ship 3). The CI job that runs the previous version's tests against the new schema is built when a
  project ships its first destructive migration, not before (F-NEW-44). The website holds no data
  yet.

## Previews: one Worker per PR, in a separate account

`.github/workflows/preview.yml` runs in the `preview` environment on `pull_request` opened,
synchronize, reopened and closed, and on `workflow_dispatch` with a PR number to clear leftovers.
`scripts/preview.sh deploy <pr>` writes `wrangler.preview.json` from the main config
(`scripts/preview-config.mjs`: the name becomes `website-pr-<n>`) and runs `scripts/deploy.sh` with
`WRANGLER_CONFIG`, `DEPLOY_NAME=website-pr-<n>` and `SMOKE_TRIES=20` (a new Worker's route takes
about two minutes to reach every edge), so a preview also records the version it replaces.
`scripts/preview-comment.mjs` keeps one PR comment with the preview's URL, updated on every push,
and `pr-body-check.py` accepts that comment as the PR's **Preview** line. On close,
`preview.sh delete <pr>` deletes the Worker through the API (`DELETE …/workers/scripts/<name>?force=true`,
the token passed on stdin, never as an argument): `wrangler delete` also reads KV namespaces, a
permission the preview token doesn't have and shouldn't need (fixture PR 4). The cleanup job checks
out `main`'s scripts, not the closed PR's, so a fix covers every later close. The fixture's preview
also created and deleted a D1 database per PR.

**Why two accounts:** the PR workflow runs code the agent can edit, so a preview token that could
reach production would let any PR overwrite the live site. The preview account's token sees only its
own account (production answers 401 to it, fixture PR 4), and the production token is never in
`preview`. W10.10.1's first draft put the preview token in the production account; the adversarial
review caught it (LOG #72).

## The quality bar, in the slow tier

`scripts/check-slow.sh` builds the site and serves it with `wrangler dev` on a free local port (the
same Worker that deploys), waits until `/build.txt` is the commit, then on every page in
`quality/routes.json`:

- the render check (`scripts/ui/render-check.mjs`, the devshop's copy, unchanged; UI guideline);
- the page check (`scripts/quality/page-check.mjs`): a non-empty title and description and an
  `og:image` that answers 200 with an image type; axe-core with no serious or critical violation at
  375 and 1280 px in light and dark; the byte budget per page in `quality/budget.json`, decoded
  bytes per kind (`js`, `css`, `images`, `fonts`), so the number is the same locally and from the
  edge;
- the page's own browser test (the website's `tests/home.e2e.mjs`): content and order, links, 44 px
  targets, screen-reader text, no request leaving the origin;
- Lighthouse (`scripts/quality/lighthouse.mjs`): mobile defaults, 3 runs, the **median** per
  category must reach performance 90 and accessibility, best practices and SEO 95. On a PR it runs
  against the PR's preview (`LIGHTHOUSE_ON=preview`): `scripts/quality/preview-url.mjs` reads the
  repo's `preview` deployments (the job needs `deployments: read`) and takes the newest whose
  `/build.txt` is this commit, waiting up to 15 minutes for the preview workflow; on `main` and in a
  session it runs against the local server.

Then it proves the checks still catch a broken page: the home page without its viewport meta must fail
the render check, and without its description the page check; a pass there is exit 2, never a pass.
The slow job installs the browser with `npx playwright install --with-deps chromium`. Lowering a bar
or a budget is the owner's decision, recorded in a spec. The byte budget is written into the first
spec that loads the bytes (the website's home page: js 4 000, css 20 000, images 60 000, fonts
80 000).

## Set-up

The owner's steps, with how the session checks each from outside (the agent's Write access reads
GitHub's repo settings, workflow runs and deployments, but not the environments, which answer 403:
those are checked by what they refuse or produce). The GitHub steps every project has first
([the new-project steps](../../templates/new-project-steps.md)); these come with the first change that
names this stack, and were done for the website in one sitting from a checklist the session filled
in.

1. **A production Cloudflare account and its deploy token:** an API token with **Workers Scripts
   Edit** only (add **D1 Edit** only when a change needs a database; the fixture needed no more than
   those two), kept as `CLOUDFLARE_API_TOKEN` in a GitHub environment named `production`, with
   `CLOUDFLARE_ACCOUNT_ID` as a variable or secret beside it, and the environment's deployment
   branch rule set to `main` alone. Check: a workflow job on a branch that asks for `production` is
   refused by GitHub before any step runs (the website's PR 2 probe), and the deploy job on `main`
   succeeds.
2. **A separate, preview-only Cloudflare account**, whose token (same scopes) is the only one in a
   GitHub environment named `preview`, with its own `CLOUDFLARE_ACCOUNT_ID`. Check: the first PR's
   preview comment names a `workers.dev` host under that account's subdomain, not production's; the
   preview token gets 401 from the production account (the owner confirms; the session can't read
   the environments).
3. **The custom domain, by hand in the dashboard, after the first deploy from `main`:** Workers &
   Pages → the Worker → Settings → Domains & Routes → Custom domain (Cloudflare writes the DNS
   record and the certificate); a proxied `AAAA` record `www` → `100::` and a Redirect Rule from the
   "Redirect from WWW to root" template (301, path and query kept); then, **last**, the variable
   `SITE_URL=https://<domain>` in the `production` environment, which turns on the deploy's domain
   check (set earlier it would fail every deploy after the upload). The deploy token needs no zone
   permission, and with no `routes` in the config a deploy neither adds nor removes the domain
   (wrangler 4.149 never calls the route or custom-domain APIs then; the website's spec checked this
   by a static read and keeps the per-deploy check anyway). Check: the next deploy's summary and
   comment say the domain serves this build, and `curl -sI https://www.<domain>/` answers 301 to the
   apex.
4. **A read-only Cloudflare token (analytics and logs only)** as a secret the deploy workflow will
   use for the post-deploy canary and the pre-merge health check (D-17 item 7, W10.10.5). Nothing
   reads it yet; the session names the secret when W10.10.5 builds the job.
5. **The cloud environment's network allowlist:** besides the registries and GitHub, the production
   host and the preview account's `workers.dev` subdomain, and the domain. They are known after the
   first deploy; the session names them then. Check: from a session, `curl -sI` on each answers.

Claude's part, with the first change that names the stack: `wrangler.jsonc`, `package.json` and
`.nvmrc`, `scripts/build.sh`, `scripts/deploy.sh` and its test, `scripts/preview.sh`,
`scripts/preview-config.mjs`, `scripts/preview-comment.mjs` and `.github/workflows/preview.yml`,
the template's `ci.yml` with its tool-install and deploy `env` lines filled, `quality/routes.json`,
`quality/budget.json` and `scripts/quality/`, `scripts/check-slow.sh` as above, and the project's
`CLAUDE.md` conventions (this page's rules, in the project's words).

## Platform controls in use (TARGET Safety 12)

| Control                               | How it is set                                                                                                                      |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Token scopes                          | Workers Scripts Edit (+ D1 Edit when needed); no zone rights (the domain is attached by hand); a read-only token for observability |
| Two accounts                          | production token only in `production`; preview-only account's token only in `preview`                                              |
| Branch-limited secrets                | the `production` environment's deployment branch rule: `main` only                                                                 |
| The deploy gate                       | GitHub can't hold a private repo's deploy for approval, so the owner's PR approval plus main-only deploys is it                    |
| Versions and rollback                 | every deploy records the version it replaces; `wrangler rollback <version> --name <worker>` or the dashboard                       |
| One deploy at a time                  | `concurrency: production`, `cancel-in-progress: false`                                                                             |
| No version preview URLs on production | `preview_urls: false`; previews are separate Workers in the preview account                                                        |
| Logs                                  | `observability.enabled` (Workers Logs); analytics and logs read with the read-only token (W10.10.5)                                |
| Only the site's Worker                | `scripts/deploy.sh` refuses a config naming any other Worker                                                                       |

## Cloud-session facts

Seen in the fixture's and the website's sessions (F-NEW-55, F-NEW-68, F-NEW-71; REVIEW-2 § 2):

- `gh auth status` says "The token in GH_TOKEN is invalid" while `gh api` works as the agent
  identity. Don't read that status as a reason to skip `pr-assets.sh` or `ship.sh`.
- The clone is shallow: anything that walks history (a pinned-SHA check, `release.py`) needs the
  history fetched first (`git fetch --unshallow`, or a bounded `--deepen`), or fails with "shallow
  update not allowed".
- The clone has no tags: `git fetch --tags` on demand before anything reads one (the fixture's
  fast tier named a baseline tag and exited 2 until then; CI fetches tags and passes). The session's
  git proxy refuses tag pushes (F-NEW-22): the owner tags.
- `wrangler dev` runs the Worker locally (the slow tier does this); nothing else of Cloudflare's is
  reached from a session, and the network allowlist holds only the hosts in Set-up step 5.

## Tests are named by spec and item

Every test that proves an acceptance item names it: `AC-<n>` in the test's name or description, so
`scripts/spec-check.py --tests` (CI's fast tier) finds it (F-NEW-49). `spec-check.py` matches
numbers per spec, so a second spec's `AC-1` is already "named" by the first spec's tests
(F-NEW-92): the website labels them `<spec> AC-<n>` (`font-fallback AC-1`, `projects AC-2`), and the
reviewer reads those labels. Script tests run from `tests/run.sh`, which changes into `tests/`, so a
test using repo-relative paths does `cd "$repo_root"` itself (F-NEW-89). Fast tests need no
browser; a test that needs one is slow and runs from `check-slow.sh`.

## What the website's first changes taught

Fixed in the website; a new project starts with them (the root `FINDINGS.md` rows):

- **Broken-page proofs remove whole tags:** Prettier wraps a `<meta>` over lines, so a line-wise
  `sed` can't delete it and the proof can't run; use a multi-line match
  (`perl -0pi -e 's/<meta\s[^>]*name="viewport"[^>]*>//s'`) and check the tag is gone before
  judging (F-NEW-80).
- **`og:image` is resolved against the site under test**, never fetched from the production host: an
  absolute URL fails locally and on previews before the domain is live, and on a preview it tests
  production's image (F-NEW-81).
- **Fonts are a byte-budget kind** beside JS, CSS and images; a page that self-hosts fonts sets
  `perPage.fonts` (F-NEW-82).
- **The blocked-fonts state is proven, not assumed** (F-NEW-90): read `document.fonts` after
  `document.fonts.ready`: `error` with the files blocked, `loaded` with them served, `loading` while
  the responses are held back with the text still visible; each `@font-face` declares
  `font-display: swap`, and each font token names a generic family after its web face, so a failed
  face never leaves the browser's default serif.
- Body text in the system font stack and the display faces as one Latin-subset woff2 each,
  self-hosted with their licence file and preloaded, kept the home page inside the performance bar.

## Not here yet

- Tested templates of `deploy.sh`, `preview.sh` and `check-slow.sh` in this directory, and a scaffold
  proven by the devshop's CI on a fresh project (TARGET Reach 5), wait until a second Cloudflare
  project exists (W10.10.2's task line).
- The post-deploy canary and the pre-merge health check (W10.10.5); the reviewer's browser
  (W10.10.4); a framework, when a change needs one.
