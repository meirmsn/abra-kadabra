# Roadmap

What the owner decided will happen to the devshop, in their words. The table's order is the
priority: the top `Open` entry is the next task. What Claude noticed but nobody decided is in
[FINDINGS.md](FINDINGS.md). The rules are in the template,
[runtime/templates/roadmap.md](runtime/templates/roadmap.md) ([spec](specs/findings-and-roadmap.md)).

R-1 to R-9 came from the revamp's task list on 2026-10-16, in an order Claude proposed and the
owner reorders. For each, the owner's words, the detail and the done-when stay on the linked task
line in [kit/notes/revamp/workstreams/](kit/notes/revamp/workstreams/), where its status is kept
too; an entry is `Done` when its task is `[x]`.

| ID   | Added      | What                                                                                                                                                                                                                                                                                                         | Status                                       |
| ---- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| R-1  | 2026-10-16 | Close the website's first change: its record (the spec's question count, cost per change, weekly-limit percentage, the owner's touchpoints) — [W10.10.1](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                         | Done, PR #133                                |
| R-2  | 2026-10-16 | Approval ships: show it on a real PR merged on the owner's approval with no "merge" message — [W10.9.1](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each)                                                                                                                                | Done, PR #142                                |
| R-3  | 2026-10-16 | The Cloudflare stack home, written from what the website shipped — [W10.10.2](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                                                                                    | Done, PR #144                                |
| R-4  | 2026-10-16 | The canary as a CI record: production's health checked before the merge and after the deploy, with the read-only token — [W10.10.5](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                              | Done, website PR #10                         |
| R-5  | 2026-10-16 | Build runs gstack's `/design-review` on the preview for every UI change, before `ship`; on a local run, since the preview exists only after `ship` (owner, 2026-10-17: "1. A") — [W10.10.8](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                      | Done, PR #145                                |
| R-6  | 2026-10-16 | The reviewer gets a browser and judges a local run against `DESIGN.md` — [W10.10.4](kit/notes/revamp/workstreams/W10-v2.md#w1010-the-first-real-project--p0--m)                                                                                                                                              | Done, PR #146                                |
| R-7  | 2026-10-16 | M3: the first real app, lalista web on v2, with its React stack home decision — [M3](kit/notes/revamp/workstreams/W10-v2.md#m3m4--coarse-detailed-when-next), [W10.8.3](kit/notes/revamp/workstreams/W10-v2.md#w108-ui-design-baseline--p1--m)                                                               | Open                                         |
| R-8  | 2026-10-16 | M4: the iOS stack and the Mac; retire v1, with the owner's deferred credential and archive steps — [M4](kit/notes/revamp/workstreams/W10-v2.md#m3m4--coarse-detailed-when-next), [W0.5, W0.6](kit/notes/revamp/workstreams/W0-groundwork.md)                                                                 | Open                                         |
| R-9  | 2026-10-16 | After the revamp: the air-gapped adversarial reviewer as a required check — [PLAN.md § After the revamp](kit/notes/revamp/PLAN.md#after-the-revamp)                                                                                                                                                          | Open                                         |
| R-10 | 2026-10-16 | Every repo keeps a roadmap and a findings log — [W10.9.8](kit/notes/revamp/workstreams/W10-v2.md#w109-m1-close-out--p0--s-each), [spec](specs/findings-and-roadmap.md)                                                                                                                                       | Done, PR #125                                |
| R-11 | 2026-10-16 | Devshop releases: Conventional Commit titles, a release button only the owner can press, projects pin release tags — [spec](specs/devshop-releases.md)                                                                                                                                                       | Done, PRs #128, #134, #137 (v2.0.0 released) |
| R-13 | 2026-10-20 | One project contract: what every project must provide, in one file the devshop checks at session start and in `fast`; the duplicates collapsed; the manifest covers what the upgrade claims to re-copy; R-12 is its first entry — [R-13](#r-13-one-project-contract-what-every-project-must-provide-checked) | Open                                         |
| R-12 | 2026-10-19 | Projects' PR titles carry a Conventional Commit prefix too, placed by the devshop: a `pr-title-check.py` in the project files, checked in `fast` and by `ship.sh` — [R-12](#r-12-projects-pr-titles-carry-a-conventional-commit-prefix-too)                                                                  | Open                                         |

## R-12: Projects' PR titles carry a Conventional Commit prefix too

Asked 2026-10-18, as a comment on the website's PR #10:

```text
how come the PR title did not get the prefix?
```

Sharpened with the owner (2026-10-19, "do it" on the proposed wording): today the title rule
([spec](specs/devshop-releases.md)) applies to the devshop repo only, since `ship.sh` checks a title
only where `scripts/pr-title-check.py` exists and projects have none. The entry: the devshop places
a `pr-title-check.py` in the project files, checked in `fast` and by `ship.sh`.

## R-13: One project contract: what every project must provide, checked

Asked 2026-10-19 and 2026-10-20, in chat, after the R-6 session surveyed every name the devshop
relies on finding in a project (39 of them; 9 written down, the rest a hard-coded path or a
sentence; the website and the fixture already differ in ways nothing catches):

```text
i think we should think really hard if the devshop will work or not to work on different
projects and be cionsistent across them
```

```text
the project can be cloned by otuside collaborators and should work (they can run locally, submit
PRs) without access to devshop
```

```text
the generic tooling lives on devshop, and the particular lives in each project
```

On the proposed shape below, "yes", then "do step 0" (2026-10-20). Placed before R-12 at the
owner's acceptance of "the next task, before R-12", so R-12's title check enters through the
contract rather than beside it.

### Claude's notes

The proposal the owner accepted: one file in `runtime/` lists every name the devshop relies on in
a project, with its owner (`devshop` copy, seed, project-owned, optional), what it must do and who
relies on it; one check reads that file at session start and in the project's `fast` tier,
required items red when missing or malformed, optional ones named as absent, never silent; the
duplicates collapse while writing it down (one way to start the site locally, used by the
reviewer, the design review and `check-slow.sh`; lint in the template or out of the spec; one
routes-list name; one AC-naming rule); the manifest grows to cover what `runtime/guidelines/ui.md`
already says the upgrade re-copies; a stack home declares which optional items it supplies.
R-12's `pr-title-check.py` is the first entry done this way. Then one short PR per project
(website, fixture) from what the check reports. The survey behind it is
[the audit of 2026-10-19](kit/notes/revamp/project-contract-audit-2026-10-19.md); F-NEW-104 and F-NEW-105 are this entry (rows deleted here); F-NEW-103 closes with it.
