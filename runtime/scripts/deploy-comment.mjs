#!/usr/bin/env node
// The merged PR's deploy comment, one comment edited in place as the deploy goes: merged → deploying →
// live or failed; when the deploy never happens, report ends it in another final state
// (specs/deploy-and-metrics-comments.md; lifted from the website's first version). Run by the jobs of the
// devshop's ci.yml template on pushes to main; a project keeps an identical copy (runtime/project-files.txt).
// Usage: node scripts/deploy-comment.mjs merged | deploying | deployed | failed | report
// Env: GITHUB_TOKEN, GITHUB_REPOSITORY (owner/name), DEPLOY_SHA (the run's commit); RUN_ID, RUN_ATTEMPT
//   and RUN_URL (the workflow run; deployed and failed work without them, as the website's first version
//   called them); GITHUB_API_URL (default https://api.github.com).
//   deployed, and report when the deploy succeeded, from scripts/deploy.sh's outputs: URL, VERSION,
//   PREVIOUS, ROLLBACK, SITE_URL, SITE_SMOKE (passed | failed | skipped); NONE=yes when the project has
//   no deploy script. failed: DEPLOYED ("yes" once the new version was uploaded), PREVIOUS, ROLLBACK,
//   SITE_URL, SITE_SMOKE. report: FAST, SLOW, DEPLOY, the jobs' results (success | failure | cancelled |
//   skipped).
//   DEPLOYING_AS and LIVE_AS (optional): the bold words of those headlines, by default "Deploying to
//   production" and "Live in production".
//   Settings for tests: LOOKUP_TRIES (default 7) and LOOKUP_WAIT_MS (default 5000) for finding the merged
//   PR (merged and report: it may not be findable in the first seconds), API_TIMEOUT_MS (default 10000).
// The comment's second line records its state: <!-- state:<state> run:<id>/<attempt> at:<UTC time> -->.
// Writes only move forward: a higher run attempt replaces any state; within an attempt a state never
// replaces a later one; a lower attempt never writes. Only comments by github-actions[bot] that start
// with the marker are ever edited or deleted; of several, the oldest is kept and the others deleted.
// Exit 0 = written, nothing to write, or no merged PR to write on; 1 = GitHub API error or timeout;
// 2 = bad arguments or settings (checked before any call to GitHub).
const MARK = '<!-- devshop-deploy -->';
const BOT = 'github-actions[bot]';
const FINAL = ['live', 'failed', 'not-deployed', 'superseded'];
const RANK = { merged: 0, deploying: 1 };
const RESULTS = ['success', 'failure', 'cancelled', 'skipped'];
const env = process.env;
const die = (code, msg) => {
  console.error(`deploy-comment: FAIL: ${msg}`);
  process.exit(code);
};
const https = (v) => /^https:\/\/[^\s<>()]+$/.test(v ?? '');

const [cmd] = process.argv.slice(2);
if (!['merged', 'deploying', 'deployed', 'failed', 'report'].includes(cmd))
  die(
    2,
    `usage: deploy-comment.mjs merged|deploying|deployed|failed|report (got ${cmd})`
  );
for (const v of ['GITHUB_TOKEN', 'GITHUB_REPOSITORY', 'DEPLOY_SHA'])
  if (!env[v]) die(2, `${v} is not set`);
if (!/^[\w.-]+\/[\w.-]+$/.test(env.GITHUB_REPOSITORY))
  die(2, 'GITHUB_REPOSITORY is not owner/name');
const sha = env.DEPLOY_SHA;
if (!/^[0-9a-f]{40}$/.test(sha)) die(2, `DEPLOY_SHA is not a commit: ${sha}`);
const legacy = !env.RUN_ID && ['deployed', 'failed'].includes(cmd);
if (!legacy) {
  if (!/^\d+$/.test(env.RUN_ID ?? ''))
    die(2, `RUN_ID is not a run id: ${env.RUN_ID}`);
  if (!/^\d+$/.test(env.RUN_ATTEMPT ?? ''))
    die(2, `RUN_ATTEMPT is not a number: ${env.RUN_ATTEMPT}`);
}
// The first version's calls (no run id) may also lack RUN_URL; when given, it must be https.
if ((!legacy || env.RUN_URL) && !https(env.RUN_URL))
  die(2, `${cmd} needs RUN_URL, an https URL`);
const none = env.NONE === 'yes';
if (cmd === 'report')
  for (const v of ['FAST', 'SLOW', 'DEPLOY'])
    if (!RESULTS.includes(env[v]))
      die(2, `${v} is not a job result (${RESULTS.join(', ')}): ${env[v]}`);
// deploy.sh's outputs never stop the comment reaching a final state: a missing one shows as unknown,
// and a URL that isn't https (or a site URL that isn't an https origin) is left out.
// The bold words of the deploying and live headlines (the devshop: "Releasing on `main`", "Released on
// `main`"); one line of at most 60 characters, no `*`.
const words = (v, d) => {
  const w = env[v] || d;
  if (w.length > 60 || /[\n\r*]/.test(w))
    die(2, `${v} must be one line of at most 60 characters, no *`);
  return w;
};
const deployingAs = words('DEPLOYING_AS', 'Deploying to production');
const liveAs = words('LIVE_AS', 'Live in production');
const url = https(env.URL) ? env.URL : null;
const siteUrl = /^https:\/\/[A-Za-z0-9.-]+$/.test(env.SITE_URL ?? '')
  ? env.SITE_URL
  : null;
const num = (v, d) =>
  v === undefined || v === ''
    ? d
    : /^\d+$/.test(v)
      ? Number(v)
      : die(2, `not a number: ${v}`);
const tries = num(env.LOOKUP_TRIES, 7);
const waitMs = num(env.LOOKUP_WAIT_MS, 5000);
const timeoutMs = num(env.API_TIMEOUT_MS, 10000);
const attempt = legacy ? 0 : Number(env.RUN_ATTEMPT);
const run = legacy ? '0/0' : `${env.RUN_ID}/${attempt}`;

const short = (s) => `\`${s.slice(0, 7)}\``;
const runLink = env.RUN_URL ? `[run](${env.RUN_URL})` : '';
const undo = env.ROLLBACK ? `- To undo: ${env.ROLLBACK}` : '';
const domain =
  {
    passed: siteUrl && `- Domain: ${siteUrl} serves this build`,
    failed: siteUrl && `- Domain: ${siteUrl} did not serve this build`,
    skipped: '- Domain: not checked (`SITE_URL` is not set)',
  }[env.SITE_SMOKE] || '';
const notDeployed = (reason) => ({
  state: 'not-deployed',
  lines: [
    `**Not deployed** · ${short(sha)} · ${reason}; production is unchanged · ${runLink}`,
  ],
});
const texts = {
  merged: () => ({
    state: 'merged',
    lines: [
      `**Merged** · ${short(sha)} · checks running on \`main\`, then the deploy · ${runLink}`,
    ],
  }),
  deploying: () => ({
    state: 'deploying',
    lines: [`**${deployingAs}** · ${short(sha)} · ${runLink}`],
  }),
  deployed: () =>
    none
      ? notDeployed('this project has no deploy step yet')
      : {
          state: 'live',
          lines: [
            `**${liveAs}** · ${short(sha)} · ${url || 'URL unknown'}`,
            '',
            `- New version: \`${env.VERSION || 'unknown'}\``,
            `- Replaced: \`${env.PREVIOUS || 'unknown'}\``,
            ...[domain, undo].filter(Boolean),
          ],
        },
  failed: () => ({
    state: 'failed',
    lines:
      env.DEPLOYED === 'yes'
        ? [
            `**Production deploy of ${short(sha)} failed its checks:** the new version may be live. See the ${runLink || 'run'}.`,
            '',
            `- Replaced: \`${env.PREVIOUS || 'unknown'}\``,
            ...[domain, undo].filter(Boolean),
          ]
        : [
            `**Production deploy of ${short(sha)} failed;** production is unchanged. See the ${runLink || 'run'}.`,
          ],
  }),
};

const api = (env.GITHUB_API_URL || 'https://api.github.com').replace(/\/$/, '');
async function gh(method, path, payload) {
  let res;
  try {
    res = await fetch(path.startsWith('http') ? path : `${api}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${env.GITHUB_TOKEN}`,
        accept: 'application/vnd.github+json',
        'content-type': 'application/json',
      },
      body: payload && JSON.stringify(payload),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (e) {
    die(
      1,
      `${method} ${path.replace(api, '')}: ${e.name === 'TimeoutError' ? `no answer in ${timeoutMs} ms` : e.message}`
    );
  }
  if (!res.ok) die(1, `${method} ${path.replace(api, '')}: HTTP ${res.status}`);
  const text = await res.text();
  return {
    data: text ? JSON.parse(text) : null,
    next: /<([^>]+)>;\s*rel="next"/.exec(res.headers.get('link') || '')?.[1],
  };
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const repo = `/repos/${env.GITHUB_REPOSITORY}`;
async function mergedPr() {
  const n = ['merged', 'report'].includes(cmd) ? tries : 1;
  for (let i = 0; i < n; i++) {
    if (i) await sleep(waitMs);
    const { data } = await gh('GET', `${repo}/commits/${sha}/pulls`);
    const pr = (Array.isArray(data) ? data : []).find(
      (p) => p.merged_at && p.base?.ref === 'main' && p.merge_commit_sha === sha
    );
    if (pr) return pr;
  }
  return null;
}

// The comment's recorded state: {state, attempt}; a marker comment with no state line is final and
// never replaced (written before state lines existed).
function parse(body) {
  const m = /^<!-- state:([a-z-]+) run:(\d+)\/(\d+) at:\S+ -->$/m.exec(
    body.split('\n')[1] || ''
  );
  return m
    ? { state: m[1], attempt: Number(m[3]) }
    : { state: 'live', attempt: Infinity };
}
const rank = (s) => (FINAL.includes(s) ? 2 : RANK[s]);
const ahead = (a, b) => a.attempt - b.attempt || rank(a.state) - rank(b.state);
// May `next` replace `cur`? A higher attempt replaces anything; within an attempt only a move forward
// (rewriting the same not-final state is allowed); a final state is never replaced within its attempt.
const mayWrite = (next, cur) =>
  next.attempt > cur.attempt ||
  (next.attempt === cur.attempt &&
    !FINAL.includes(cur.state) &&
    rank(next.state) >= rank(cur.state));

// What report writes, from the jobs' results and the comment as it stands (null: nothing).
async function reportText(cur) {
  const same = cur && cur.attempt === attempt;
  if (same && FINAL.includes(cur.state)) return null;
  if (cur && cur.attempt > attempt) return null;
  const { FAST: fast, SLOW: slow, DEPLOY: deploy } = env;
  if (deploy === 'success') return texts.deployed();
  const state = same ? cur.state : null;
  if (state === 'deploying')
    return notDeployed("the deploy didn't finish; production may have changed");
  if (fast === 'failure' || slow === 'failure')
    return notDeployed('checks failed on `main`');
  if (fast === 'cancelled' || slow === 'cancelled')
    return notDeployed('checks were cancelled or timed out');
  if (deploy === 'cancelled') {
    // Superseded only when the checks passed and the deploy never started (the comment still merged,
    // or none at all): GitHub's production concurrency group dropped it for a newer merge's deploy.
    const waiting =
      fast === 'success' &&
      slow === 'success' &&
      (state === null || state === 'merged');
    const newer = waiting && (await newerRun());
    if (newer)
      return {
        state: 'superseded',
        lines: [
          `**Not deployed on its own** · ${short(sha)} · it ships with ${short(newer)}'s deploy · ${runLink}`,
        ],
      };
    return notDeployed('the run was cancelled');
  }
  if (deploy === 'failure')
    return notDeployed('the deploy job failed before it started');
  return notDeployed("the deploy didn't run");
}
// The commit of the newest later run of this workflow on main, or null.
async function newerRun() {
  const { data: me } = await gh('GET', `${repo}/actions/runs/${env.RUN_ID}`);
  const { data } = await gh(
    'GET',
    `${repo}/actions/workflows/${me.workflow_id}/runs?branch=main&event=push&per_page=20`
  );
  const later = (data?.workflow_runs || []).filter(
    (r) => r.run_number > me.run_number
  );
  later.sort((a, b) => b.run_number - a.run_number);
  return later[0]?.head_sha || null;
}

const pr = await mergedPr();
if (!pr) {
  console.log(
    `deploy-comment: ${sha.slice(0, 12)} is no merged PR's merge commit; no comment`
  );
  process.exit(0);
}
let page = `${repo}/issues/${pr.number}/comments?per_page=100`;
const mine = [];
while (page) {
  const { data, next } = await gh('GET', page);
  mine.push(
    ...(data || []).filter(
      (c) => c.user?.login === BOT && c.body?.startsWith(MARK)
    )
  );
  page = next;
}
mine.sort((a, b) => a.id - b.id);
const keep = mine[0];
// The comment as it stands: the furthest ahead of the marker comments.
const lead = mine.reduce(
  (a, c) => (!a || ahead(parse(c.body), parse(a.body)) > 0 ? c : a),
  null
);
const cur = lead && parse(lead.body);

const text = cmd === 'report' ? await reportText(cur) : texts[cmd]();
const next = text && { state: text.state, attempt };
let body = null;
if (next && (!cur || mayWrite(next, cur))) {
  const lines = [
    MARK,
    `<!-- state:${next.state} run:${run} at:${new Date().toISOString().replace(/\.\d+Z$/, 'Z')} -->`,
    ...text.lines,
  ];
  body = lines.filter((l, i, a) => l !== '' || a[i + 1]).join('\n');
} else if (lead && lead !== keep) body = lead.body; // nothing new, but the duplicates still fold into the oldest

if (body !== null) {
  if (keep) await gh('PATCH', `${repo}/issues/comments/${keep.id}`, { body });
  else await gh('POST', `${repo}/issues/${pr.number}/comments`, { body });
}
for (const c of mine.slice(1))
  await gh('DELETE', `${repo}/issues/comments/${c.id}`);
const did = body === null ? 'unchanged' : keep ? 'updated' : 'created';
console.log(
  `deploy-comment: ${cmd} on PR #${pr.number}: ${next && body !== null && body !== lead?.body ? next.state : 'no new state'} (${did}${mine.length > 1 ? `, ${mine.length - 1} duplicate(s) deleted` : ''})`
);
