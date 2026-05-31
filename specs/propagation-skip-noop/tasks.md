# Tasks: propagation-skip-noop

## Task: Generator tag parse + filter + render

**Hat**: BE
**Depends on**: none
**Blocks**: bats, all-auto collapse
**Done when**: `propagation-entry.sh` parses leading `[auto]`/`[manual]`/`[conditional]` tag; drops `[auto]`; renders `[manual]` plain and `[conditional]` with `(conditional)` label (tag stripped); keeps+warns untagged. `bash -n` clean.
**Risk**: medium
**Status**: done

## Task: All-[auto] collapse confirmation + comment

**Hat**: BE
**Depends on**: Generator tag parse
**Blocks**: bats
**Done when**: confirmed empty-ENTRIES → `(no manual steps)` covers all-`[auto]`; "actionable entries only" comment added at line 62.
**Risk**: low
**Status**: done

## Task: Hygiene gate tag validation

**Hat**: BE
**Depends on**: none
**Blocks**: bats
**Done when**: `adversarial-review.sh` computes `PROP_BLOCK_TAGGED=yes/no/n-a`, injects a `$CONTEXT` data line, extends NOTE-3 to FAIL present-but-untagged. No hard `exit 1`. `bash -n` clean.
**Risk**: medium
**Status**: done

## Task: bats coverage

**Hat**: BE
**Depends on**: Generator, all-auto collapse, gate
**Blocks**: docs
**Done when**: 5 generator cases + 2 gate-precompute cases appended; both target bats files green.
**Risk**: low
**Status**: done

## Task: Docs

**Hat**: PM
**Depends on**: Generator, gate
**Blocks**: backfill
**Done when**: conventions.md tag vocabulary + shape line + enforcement layer 1; merge-devshop SKILL.md § 0.3 tag mention; PROPAGATION.md header note.
**Risk**: low
**Status**: done

## Task: v1.37.0 backfill

**Hat**: PM
**Depends on**: Docs
**Blocks**: none
**Done when**: v1.37.0 section collapsed to one `(conditional)` CSP entry + the auto-propagate line.
**Risk**: low
**Status**: done

## Decisions

- Generator tag parse: an existing bats test ("no warn when a propagation-surface commit HAS an Existing-projects block") asserted the OLD "present block → never warn" contract; its block was untagged, so the new keep-and-warn-on-untagged behavior would warn. Retagged its block `[auto]` so it now tests "tagged block suppresses warn" — preserving the test's intent under the new contract. Folded into Task 1's commit since Task 1 changes the behavior it encodes.
- Docs-coverage gate: each kit/scripts commit (Tasks 1, 2, 3) uses the documented `devshop.docsCoverageReason` bypass because the owning doc (conventions.md § Existing-Project Migration Block) lands as the atomic Task 5 commit on the same branch (spec § Gotchas: branch net-diff carries both code + doc).
