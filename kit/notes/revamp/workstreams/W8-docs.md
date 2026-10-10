# W8 — Documentation restructure

> **Superseded by D-14 (2026-10-09).** The devshop is rewritten lean in a new repo
> ([W10-v2.md](W10-v2.md)); these v1 tasks are **not executed** (`[-]`). They stay as
> reference: each finding below is dispositioned by the lessons harvest **W10.3.3**
> (v2 requirement, not applicable, or won't fix — v1 retired). Security exposure that is
> live today is handled in W0.5–W0.7.

One entry point, hierarchical, one fact one home. Rule from M1 onward: any task
that changes behaviour updates the docs in the same commit, even before W8 lands.
Findings: F-DOC-01..03, F-DOC-07, F-PIPE-18.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

Target tree:

```
README.md (≤600w)        entry: what it is · workflow tiers · "read next" ladder
kit/docs/OVERVIEW.md     concept only: layers, pinned install, the ONE pipeline diagram, artifact chain
kit/docs/WORKFLOWS.md    one section per tier; gate table referenced (generated)
kit/docs/guide/          one topic per file (≤4k w), purpose box on top
   README.md (human ToC) · routing.md (Claude's index) · non-negotiables.md (canonical)
   testing · metrics · commit-pr-style · trackers · hooks · security · ops · architecture · skills.md
kit/docs/FAQ.md          rationale only
kit/notes/               historical, not authoritative (banner)
CLAUDE.md (≤2k w)        session protocol, link to non-negotiables, footguns = symptom + first action + link
recipes/*/SKILL.md       service-specific guidance (from W5)
```

## W8.1 Single entry README — P2 · M5 · S

- [-] **W8.1.1** Rewrite README as the only entry; others link up to it — V1

## W8.2 OVERVIEW concept-only + WORKFLOWS.md — P2 · M5 · M

- [-] **W8.2.1** Move event-flow → hooks.md, workspace tree → architecture.md, glossary trimmed — V1
- [-] **W8.2.2** Write WORKFLOWS.md from W6.3 tiers; merge the two pipeline diagrams into one — V1

## W8.3 Guide split, routing separated, canonical homes — P2 · M5 · M

- [-] **W8.3.1** `guide/README.md` = human ToC; routing table → `guide/routing.md` (update routing bats) — V2
- [-] **W8.3.2** Canonical homes: Non-negotiables, Confidence Calibration, Root-cause-over-bandaid, specs layout — one file each; replace copies with links — V1
- [-] **W8.3.3** Split `conventions.md` (13.5k words) into topical files ≤4k — V1

## W8.4 Generated counts — P2 · M5 · S

- [-] **W8.4.1** Gate count, hook steps, skill list generated from source (W6.4.1) or asserted by a test (F-DOC-02) — V2

## W8.5 Link lint + fix broken links — P1 · M1 · S

- [-] **W8.5.1** Extend routing link test to all relative links + anchors in `kit/docs`, `README.md`, `CLAUDE.md`, skills; fix the known broken ones (F-DOC-03) — V2

## W8.6 CLAUDE.md ≤2k; skills procedure-only — P2 · M5 · M

- [-] **W8.6.1** CLAUDE.md: keep session protocol + pointers; recipes out; footguns compressed — V1 + measured
- [-] **W8.6.2** Skills: procedure only; incident narratives → BUILD-LOG/notes; per-file ≤4k words (with W6.4.3) (F-PIPE-18) — V1 + measured

## W8.7 Template/project docs public-safe — P2 · M4 · S

- [-] **W8.7.1** No `kit/` or `/devshop` references in project-facing docs; architecture.md public-contributor claims match W4.2.4 (F-DOC-07) — V2 grep test
