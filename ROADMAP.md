# Roadmap

What the owner decided will happen to the devshop, in their words. The table's order is the
priority: the top `Open` entry is the next task. What Claude noticed but nobody decided is in
[FINDINGS.md](FINDINGS.md). The rules are in the template,
[runtime/templates/roadmap.md](runtime/templates/roadmap.md) ([spec](specs/findings-and-roadmap.md)).

R-1 to R-9 came from the revamp's task list on 2026-10-16, in an order Claude proposed and the
owner reorders. For each, the owner's words, the detail and the done-when stay on the linked task
line in [kit/notes/revamp/workstreams/](kit/notes/revamp/workstreams/), where its status is kept
too; an entry is `Done` when its task is `[x]`.

| ID   | Added      | What                                                                                                                                                                                                                                           | Status                                       |
| ---- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| R-1  | 2026-10-16 | Close the website's first change: its record (the spec's question count, cost per change, weekly-limit percentage, the owner's touchpoints) — [W10.10.1](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)           | Done, PR #133                                |
| R-2  | 2026-10-16 | Approval ships: show it on a real PR merged on the owner's approval with no "merge" message — [W10.9.1](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each)                                                                  | Done, PR #142                                |
| R-3  | 2026-10-16 | The Cloudflare stack home, written from what the website shipped — [W10.10.2](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                      | Done, PR #144                                |
| R-4  | 2026-10-16 | The canary as a CI record: production's health checked before the merge and after the deploy, with the read-only token — [W10.10.5](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                | Open                                         |
| R-5  | 2026-10-16 | Build runs gstack's `/design-review` on the preview for every UI change, before `ship` — [W10.10.8](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                | Open                                         |
| R-6  | 2026-10-16 | The reviewer gets a browser and judges a local run against `DESIGN.md` — [W10.10.4](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                | Open                                         |
| R-7  | 2026-10-16 | M3: the first real app, lalista web on v2, with its React stack home decision — [M3](kit/notes/revamp/workstreams/W10-v2.md#m3m4--coarse-detailed-when-next), [W10.8.3](kit/notes/revamp/workstreams/W10-v2.md#w108-ui-design-baseline--p1--m) | Open                                         |
| R-8  | 2026-10-16 | M4: the iOS stack and the Mac; retire v1, with the owner's deferred credential and archive steps — [M4](kit/notes/revamp/workstreams/W10-v2.md#m3m4--coarse-detailed-when-next), [W0.5, W0.6](kit/notes/revamp/workstreams/W0-groundwork.md)   | Open                                         |
| R-9  | 2026-10-16 | After the revamp: the air-gapped adversarial reviewer as a required check — [PLAN.md § After the revamp](kit/notes/revamp/PLAN.md#after-the-revamp)                                                                                            | Open                                         |
| R-10 | 2026-10-16 | Every repo keeps a roadmap and a findings log — [W10.9.8](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each), [spec](specs/findings-and-roadmap.md)                                                                         | Done, PR #125                                |
| R-11 | 2026-10-16 | Devshop releases: Conventional Commit titles, a release button only the owner can press, projects pin release tags — [spec](specs/devshop-releases.md)                                                                                         | Done, PRs #128, #134, #137 (v2.0.0 released) |
