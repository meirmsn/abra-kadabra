# Roadmap

What the owner decided will happen to the devshop, in their words. The table's order is the
priority: the top `Open` entry is the next task. What Claude noticed but nobody decided is in
[FINDINGS.md](FINDINGS.md). The rules are in the template,
[runtime/templates/roadmap.md](runtime/templates/roadmap.md) ([spec](specs/findings-and-roadmap.md)).

R-1 to R-9 came from the revamp's task list on 2026-10-16, in an order Claude proposed and the
owner reorders. For each, the owner's words, the detail and the done-when stay on the linked task
line in [kit/notes/revamp/workstreams/](kit/notes/revamp/workstreams/), where its status is kept
too; an entry is `Done` when its task is `[x]`.

| ID | Added | What | Status |
| --- | --- | --- | --- |
| R-1 | 2026-10-16 | Close the website's first change: its record (the spec's question count, cost per change, weekly-limit percentage, the owner's touchpoints) — [W10.10.1](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, PR #133 |
| R-2 | 2026-10-16 | Approval ships: show it on a real PR merged on the owner's approval with no "merge" message — [W10.9.1](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each) | Done, PR #142 |
| R-3 | 2026-10-16 | The Cloudflare stack home, written from what the website shipped — [W10.10.2](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, PR #144 |
| R-4 | 2026-10-16 | The canary as a CI record: production's health checked before the merge and after the deploy, with the read-only token — [W10.10.5](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, in the website |
| R-5 | 2026-10-16 | Build runs gstack's `/design-review` on the preview for every UI change, before `ship`; on a local run, since the preview exists only after `ship` (owner, 2026-10-17: "1. A") — [W10.10.8](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, PR #145 |
| R-6 | 2026-10-16 | The reviewer gets a browser and judges a local run against `DESIGN.md` — [W10.10.4](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, PR #146 |
| R-7 | 2026-10-16 | M3: the first real app, the pilot web app on v2, with its React stack home decision — [M3](kit/notes/revamp/workstreams/W10-v2.md#m3--the-pilot-web-app-on-cloudflare), [W10.8.3](kit/notes/revamp/workstreams/W10-v2.md#w108-ui-design-baseline--p1--m) | Open |
| R-8 | 2026-10-16 | M4: the iOS stack and the Mac; retire v1, with the owner's deferred credential and archive steps — [M4](kit/notes/revamp/workstreams/W10-v2.md#m4--coarse-detailed-when-next), [W0.5, W0.6](kit/notes/revamp/workstreams/W0-groundwork.md) | Open |
| R-9 | 2026-10-16 | After the revamp: the air-gapped adversarial reviewer as a required check — [PLAN.md § After the revamp](kit/notes/revamp/PLAN.md#after-the-revamp) | Open |
| R-10 | 2026-10-16 | Every repo keeps a roadmap and a findings log — [W10.9.8](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each), [spec](specs/findings-and-roadmap.md) | Done, PR #125 |
| R-11 | 2026-10-16 | Devshop releases: Conventional Commit titles, a release button only the owner can press, projects pin release tags — [spec](specs/devshop-releases.md) | Done, PRs #128, #134, #137 (v2.0.0 released) |
| R-13 | 2026-10-20 | One project contract: what every project must provide, in one file the devshop checks at session start and in `fast`; the duplicates collapsed; the manifest covers what the upgrade claims to re-copy; R-12 is its first entry — [spec](specs/project-contract.md) | Done, PR #151 |
| R-12 | 2026-10-19 | Projects' PR titles carry a Conventional Commit prefix too, placed by the devshop: a `pr-title-check.py` in the project files, checked in `fast` and by `ship.sh` — [spec](specs/project-contract.md) | Done, PR #151 (the contract's first entry) |
| R-14 | 2026-10-20 | The session-start hook reads the wrong directory after a restart and runs without the project's pin, silently (F-NEW-77): root cause and fix, before the pilot web app adopts v2 — [W10.11.12](kit/notes/revamp/workstreams/W10-v2.md#w1011-the-first-real-app--p0--l) | Done (W10.11.12) |
| R-15 | 2026-10-30 | The metrics comment names the model(s) and splits the tokens (input, output, cache reads, cache writes) beside the dollars, and says which window of the session they cover — [spec](specs/metrics-model-and-tokens.md) | Done, PR #169 |
| R-20 | 2026-11-06 | The runtime's skills load again on Claude Code 2.1.318 and later (F-NEW-147), and the plugin is named `ak`, so they read `ak:intent`, `ak:build` and so on (owner, 2026-11-06: "Yeah, do it with AK and fix them.") — [spec](specs/ak-plugin.md) | Done, PR #187 |
| R-21 | 2026-11-10 | Pinned tools survive a release-host outage: cached for the session, a sanctioned repair, and a session that can't push says so up front (F-NEW-158, F-NEW-159) | Done, PR #191 |
| R-22 | 2026-11-10 | Parallel branches stop conflicting on shared lists and counters: lists derived from one manifest, tests that count from it, finding IDs that can't collide (F-NEW-161) | Open |
| R-23 | 2026-11-10 | Shared changes and flaky-test fixes land first, in their own small PR; a flake seen twice gets that PR, not a re-run (F-NEW-164) | Open |

## R-14: The session-start hook reads the wrong directory after a restart

Asked 2026-10-20, in chat, answering "roadmap or keep watching?" on F-NEW-77 (five sightings), whose
option (a) was "put it on the roadmap and find the root cause", done before the pilot web app moves to v2:

```text
F-NEW-77: a
```

The finding, as logged: after a worker restart, the SessionStart hook read the home directory
instead of the repo and said "no .devshop-version · project user" in a repo that pins one; the
CI-tier, project-files and git-hooks checks were skipped without a word. Root cause unknown: the
line names the directory it read, the clue to find it. Sightings: 2026-10-15 (website session;
devshop roadmap session), 2026-10-16 (W10.9.8; R-1), 2026-10-17 (R-3), each after a restart.

## R-21: Pinned tools survive a release-host outage

Asked 2026-11-10, in chat in a devshop session, after Claude ranked the 2026-11-09 findings from a games-site project's 11 parallel sessions and named three as the costly ones: the tool downloads at setup (F-NEW-158 with F-NEW-159), the shared-file conflicts (F-NEW-161) and the flake and shared-change rule (F-NEW-164). The owner's answer covers R-21, R-22 and R-23:

```text
Would it make sense to fix the three of them on the same PR or different PRs? Regardless, show me the task suggestion. Or I guess on the mobile you cannot do that, so just, you know, just start 1, 2, or 3 sessions that you need to fix those three.
```

### Claude's notes

The findings, as logged:

- F-NEW-158: The bootstrap downloads its pinned tools from GitHub releases at setup: a lasting outage (a 504) leaves a tool missing for the whole session, and nothing sanctioned repairs it. Without `dcg` the pre-bash hook blocks every Bash command, git included; without `gitleaks` the pre-push hook stops every push (rightly, `--no-verify` is barred), and a session's own reinstall is refused by the permission classifier, so the owner approves it by hand. Seen as `gitleaks` missing in at least five sessions and `dcg` in one. Root cause: a network fetch at setup with no cache; a retry with backoff (4 tries) now covers a brief outage, a mitigation. Candidates: the pinned binaries cached in the environment image or setup script; a checksum-verified repair command; a plain "this session can't push, start a new one" when setup still fails.
- F-NEW-159: A session whose bootstrap broke can't ship by any path: with Bash blocked it pushed its commit through the GitHub API, then the review guard refused `create_pull_request` because a PR needs `ship.sh`, which needs Bash. A fresh session was started to open one docs PR. Nothing tells the session up front that it can't ship. Same root cause as F-NEW-158; a degraded path (open the PR, let CI and the reviewer run there) or an early "start a new session" are the candidates.

## R-22: Parallel branches stop conflicting on shared files

Asked 2026-11-10, in chat in a devshop session, after Claude ranked the 2026-11-09 findings from a games-site project's 11 parallel sessions and named three as the costly ones: the tool downloads at setup (F-NEW-158 with F-NEW-159), the shared-file conflicts (F-NEW-161) and the flake and shared-change rule (F-NEW-164). The owner's answer covers R-21, R-22 and R-23:

```text
Would it make sense to fix the three of them on the same PR or different PRs? Regardless, show me the task suggestion. Or I guess on the mobile you cannot do that, so just, you know, just start 1, 2, or 3 sessions that you need to fix those three.
```

### Claude's notes

The findings, as logged:

- F-NEW-161: Parallel branches of one project conflict with `main` after every merge, always in the same shared files: the landing page's tile list, a site test that hard-codes the tile count (and acceptance tests that assert it, so each new item breaks older tests and leaves older specs' wording stale), the service worker's version and shell list, the README's list line, one append-only decisions log, and FINDINGS.md's sequential IDs (four branches each took the same next ID). Root cause: shared lists and counters edited by hand on every branch. Candidates: one manifest the tiles, shell list and tests derive from; a version from a hash; collision-free finding IDs (date plus slug); a decisions file per item. Hit every branch of the ten.

## R-23: Shared changes and flake fixes land first

Asked 2026-11-10, in chat in a devshop session, after Claude ranked the 2026-11-09 findings from a games-site project's 11 parallel sessions and named three as the costly ones: the tool downloads at setup (F-NEW-158 with F-NEW-159), the shared-file conflicts (F-NEW-161) and the flake and shared-change rule (F-NEW-164). The owner's answer covers R-21, R-22 and R-23:

```text
Would it make sense to fix the three of them on the same PR or different PRs? Regardless, show me the task suggestion. Or I guess on the mobile you cannot do that, so just, you know, just start 1, 2, or 3 sessions that you need to fix those three.
```

### Claude's notes

The findings, as logged:

- F-NEW-164: Shared changes and fixes to shared or flaky tests ride inside unrelated feature PRs: a shell prompt every item uses shipped inside one item's PR, so every other branch adapted its tests; a fix for a flaky test (a size measured mid-animation) sat in a branch near the end of the queue while that flake failed CI on at least three other PRs; two more flakes stayed unfixed. No devshop rule says a change to shared code or a shared flake fix goes first in its own small PR, or that a session seeing an unrelated flake twice proposes that PR instead of re-running.
