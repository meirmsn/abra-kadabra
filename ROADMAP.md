# Roadmap

What the owner decided will happen to the devshop, in their words. The table's order is the
priority: the top `Open` entry is the next task. What Claude noticed but nobody decided is in
[FINDINGS.md](FINDINGS.md). The rules are in the template,
[runtime/templates/roadmap.md](runtime/templates/roadmap.md) ([spec](specs/findings-and-roadmap.md)).

R-1 to R-9 came from the revamp's task list on 2026-10-16, in an order Claude proposed and the
owner reorders. For each, the owner's words, the detail and the done-when stay on the linked task
line in [kit/notes/revamp/workstreams/](kit/notes/revamp/workstreams/), where its status is kept
too; an entry is `Done` when its task is `[x]`.

| ID   | Added      | What                                                                                                                                                                                                                                                                    | Status                                       |
| ---- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| R-1  | 2026-10-16 | Close the website's first change: its record (the spec's question count, cost per change, weekly-limit percentage, the owner's touchpoints) — [W10.10.1](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                    | Done, PR #133                                |
| R-2  | 2026-10-16 | Approval ships: show it on a real PR merged on the owner's approval with no "merge" message — [W10.9.1](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each)                                                                                           | Done, PR #142                                |
| R-3  | 2026-10-16 | The Cloudflare stack home, written from what the website shipped — [W10.10.2](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                                               | Done, PR #144                                |
| R-4  | 2026-10-16 | The canary as a CI record: production's health checked before the merge and after the deploy, with the read-only token — [W10.10.5](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                         | Done, in the website                         |
| R-5  | 2026-10-16 | Build runs gstack's `/design-review` on the preview for every UI change, before `ship`; on a local run, since the preview exists only after `ship` (owner, 2026-10-17: "1. A") — [W10.10.8](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m) | Done, PR #145                                |
| R-6  | 2026-10-16 | The reviewer gets a browser and judges a local run against `DESIGN.md` — [W10.10.4](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                                         | Done, PR #146                                |
| R-7  | 2026-10-16 | M3: the first real app, the pilot web app on v2, with its React stack home decision — [M3](kit/notes/revamp/workstreams/W10-v2.md#m3--the-pilot-web-app-on-cloudflare), [W10.8.3](kit/notes/revamp/workstreams/W10-v2.md#w108-ui-design-baseline--p1--m)                | Open                                         |
| R-8  | 2026-10-16 | M4: the iOS stack and the Mac; retire v1, with the owner's deferred credential and archive steps — [M4](kit/notes/revamp/workstreams/W10-v2.md#m4--coarse-detailed-when-next), [W0.5, W0.6](kit/notes/revamp/workstreams/W0-groundwork.md)                              | Open                                         |
| R-9  | 2026-10-16 | After the revamp: the air-gapped adversarial reviewer as a required check — [PLAN.md § After the revamp](kit/notes/revamp/PLAN.md#after-the-revamp)                                                                                                                     | Open                                         |
| R-10 | 2026-10-16 | Every repo keeps a roadmap and a findings log — [W10.9.8](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each), [spec](specs/findings-and-roadmap.md)                                                                                                  | Done, PR #125                                |
| R-11 | 2026-10-16 | Devshop releases: Conventional Commit titles, a release button only the owner can press, projects pin release tags — [spec](specs/devshop-releases.md)                                                                                                                  | Done, PRs #128, #134, #137 (v2.0.0 released) |
| R-13 | 2026-10-20 | One project contract: what every project must provide, in one file the devshop checks at session start and in `fast`; the duplicates collapsed; the manifest covers what the upgrade claims to re-copy; R-12 is its first entry — [spec](specs/project-contract.md)     | Done, PR #151                                |
| R-12 | 2026-10-19 | Projects' PR titles carry a Conventional Commit prefix too, placed by the devshop: a `pr-title-check.py` in the project files, checked in `fast` and by `ship.sh` — [spec](specs/project-contract.md)                                                                   | Done, PR #151 (the contract's first entry)   |
| R-14 | 2026-10-20 | The session-start hook reads the wrong directory after a restart and runs without the project's pin, silently (F-NEW-77): root cause and fix, before the pilot web app adopts v2 — [W10.11.12](kit/notes/revamp/workstreams/W10-v2.md#w1011-the-first-real-app--p0--l)  | Done (W10.11.12)                             |

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
