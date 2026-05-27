# Docs Review — Audit 1

**Range**: `origin/main..HEAD`
**Mode**: devshop
**Commits**: 2

- `c6bd25d` feat(release): add PROPAGATION.md review step between file generation and commit
- `e636b74` docs(conventions): add responsive overflow + elevated surface text color traps

---

## Section A — Coverage

**`c6bd25d`** touches `kit/scripts/release.sh` (triggers `kit/scripts/**.sh` surface) and `.claude/skills/devshop/release-devshop/SKILL.md` (triggers `.claude/skills/**/SKILL.md` surface). Both surfaces require a guide doc or CLAUDE.md update. A `Docs-Coverage-Bypass:` trailer is present with per-file rationale — evaluated in Section D. No coverage gap.

**`e636b74`** touches `kit/docs/guide/conventions.md` only. This is a `kit/docs/**` file — carve-out applies (guide-only commits are self-documenting). No coverage gap.

**Existing-project migration block**: `c6bd25d` touches `kit/scripts/release.sh` — a propagation-relevant surface (`kit/scripts/**`). No formal `**Existing projects:**` block in the commit body. However, `release.sh` is a devshop-internal script that never propagates to project repos (it is not in `kit/manifest.txt`, not copied by `from-devshop.sh`, not referenced by any project-side file). The trigger table row says "**Yes** if behavior changes require project-side follow-up" — and these changes (new `--no-push`/`--finalize` flags) have zero project-side impact. No finding.

**`e636b74`** touches `kit/docs/guide/conventions.md` — `kit/docs/**` carve-out applies. No migration block required.

No Section A findings.

---

## Section B — Adequacy

**`.claude/skills/devshop/release-devshop/SKILL.md`** — Phase 2 updated to show `--no-push`, Phase 2.5 added for PROPAGATION.md review, Phase 3 updated to show `--finalize`. Claims verified:

- "release.sh --no-push generates all release files and stages them, then stops before committing" — verified against `release.sh:220-231`. Correct.
- "release.sh --finalize re-stages PROPAGATION.md, commits with CLAUDECODE= unset, tags, pushes, and creates the GitHub release" — verified against `release.sh:62-94`. Correct.
- Phase 2.5 step 2 cites `git diff $LAST_TAG..HEAD -- template/ kit/scripts/ kit/docs/guide/` — valid command.

**`kit/docs/guide/conventions.md`** — two new entries under `### Responsive + Theme`:

- `whitespace-nowrap + shrink-0` entry: names symptom (horizontal overflow), root cause (flex row can't compress below intrinsic width), and fix (flex-col on mobile / let text wrap). Adequate.
- `Text on elevated surfaces` entry: names symptom (washed-out text), root cause (token mismatch between surface and page background), and fix (match text token to its surface). Adequate.

**`kit/scripts/release.sh`** — the `--no-push` output message (lines 225-229) describes manual steps 2-4 (commit, tag, push) as the caller's responsibility, but the SKILL.md Phase 3 tells the caller to use `release.sh --finalize` instead. The output is technically correct (it describes what needs to happen, not how), but could mention `--finalize` as the recommended path. This is runtime output, not documentation — noting as informational only, not a finding.

No Section B findings.

---

## Section C — Cross-doc coherence

**`kit/docs/OVERVIEW.md` lines 192-196** describe `release.sh` as:

```
release.sh (devshop version bump)
  └─ Bump + commit + tag + push
```

With the new `--no-push` flag, the script can now stop before commit. However, the OVERVIEW.md description covers the default flow (without `--no-push`), which still does bump + commit + tag + push. The `--no-push` + `--finalize` split is internal to the skill workflow. No contradiction — the conceptual model is unchanged.

No renamed or deleted files in the range. No stale references detected.

No Section C findings.

---

## Section D — Bypass trailer audit

One `Docs-Coverage-Bypass:` trailer found in `c6bd25d`:

| File in trailer                                   | Claim                                               | Verdict                                                                                                   |
| ------------------------------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `.claude/skills/devshop/release-devshop/SKILL.md` | AFFECTED — skill phases updated                     | **VERIFIED** — diff confirms new Phase 2.5 + Phase 3 rewrite                                              |
| `kit/scripts/release.sh`                          | AFFECTED — `--no-push` and `--finalize` flags added | **VERIFIED** — diff confirms both flags                                                                   |
| `kit/tests/propagation-entry.bats`                | AFFECTED — 5 new structural tests                   | **VERIFIED** — diff confirms 5 new `@test` blocks                                                         |
| `kit/docs/guide/workflow.md`                      | NOT-AFFECTED — no release.sh flag/phase content     | **VERIFIED** — `grep` confirms zero release.sh mentions in workflow.md                                    |
| `CLAUDE.md`                                       | NOT-AFFECTED — references skill by name only        | **VERIFIED** — CLAUDE.md line 63 shows `release.sh --bump patch\|minor\|major` only; no flag-level detail |
| All other guide docs                              | NOT-AFFECTED                                        | **VERIFIED** — none contain release.sh content                                                            |

Note: `kit/docs/OVERVIEW.md` is not enumerated in the trailer. OVERVIEW.md does mention `release.sh` (lines 192-196) but the description remains accurate for the default flow. No escalation needed.

All bypass claims **VERIFIED**.

---

## Section E — CLAUDE.md hygiene

Skipped — devshop mode.

---

## Summary

Clean — no docs findings.
