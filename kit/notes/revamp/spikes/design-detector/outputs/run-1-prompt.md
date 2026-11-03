# Run 1 (2026-11-01): the helper's prompt, verbatim

One fresh `general-purpose` agent received exactly this. `PORT` was read from the file it names
(32877 in this run); the guideline file it names held `ui.md` § Design review from this change's
working tree, extracted by `awk` from the section heading to the next.

---

You are a builder running the devshop's design review step on a small scratch website, exactly as the devshop's UI guideline words it. This is a dry run whose output will be graded; return your output in the exact shape requested at the end.

## Your working directory and scope

- The scratch site is a git repo at `/tmp/devshop-build/spike-site`, on branch `launch`. Work from inside that directory for every command (cd there first; gstack keeps per-repo state keyed on the working directory). It is already served: the page to review is `http://127.0.0.1:PORT/launch.html` where PORT is the number in the file `/tmp/devshop-build/spike-port` (read it first). Review that page only.
- The site's `DESIGN.md` is in the repo root. The change under review added `launch.html` on branch `launch` (one commit).
- You may edit, commit and read files inside `/tmp/devshop-build/spike-site` only. Do not read or write anything under `/home/user/abra-kadabra`, and do not touch `~/.claude/settings.json`, `~/.gstack` config, or `~/.impeccable`. Do not run gstack's `./setup`. Do not install anything. Do not run `npx impeccable` or any impeccable installer.
- Export `GSTACK_CHROMIUM_PATH=/opt/pw-browsers/chromium` in your shell before any gstack command (the bootstrap sets it for sessions; your shell may not have it).

## The guideline you follow (the devshop's `ui.md` § Design review, verbatim)

Read `/tmp/devshop-build/guideline-design-review.md` first; it is the whole section. Follow it. In particular: run gstack's `/design-review` skill (its SKILL.md is at `~/.claude/skills/gstack/design-review/SKILL.md`; read it and carry out its steps yourself, as the skill would when invoked) with the URL above, scoped to that one page. The review is unattended: none of gstack's questions go to the owner. Answer them as the guideline lists (no test framework bootstrap, no CLAUDE.md or TESTING.md edits, no DESIGN.md written, no TODOS.md step, no Codex or other outside voice, no learnings from other projects; the detector engine is the bootstrap's, so an install offer, if one appears, is declined with "continue without"; a telemetry consent question is answered by declining). When gstack's browser check prints NEEDS_SETUP, do as the guideline says: drive `$B` directly (gstack's browse binary works with GSTACK_CHROMIUM_PATH set); never run its setup. Fixes: as the guideline says, only on the change's own lines (launch.html), committed on the branch in plain commit subjects.

Run the detector phase exactly as the skill's Setup and Phase 0 describe: the probe command (`bun --no-env-file run $HOME/.claude/skills/gstack/bin/gstack-design-detect.ts probe --host claude`), then, since the target is a URL, DOM mode: dump the rendered DOM as the skill's "DOM dump" section describes and scan it with the `scan` command. Record every `IMPECCABLE_*` and `DETECT_*` line printed, verbatim.

## What to return (your final message, nothing else matters)

1. **Set-up lines:** every `IMPECCABLE_*`, `DETECT_*` and browser-check line gstack printed during setup and the detector phase, verbatim, in order.
2. **gstack's final report**, verbatim, as the skill's final phase formats it (scores, findings table with `[rule-id]` tags where the detector contributed, the `Detector: N → M` line, before/after).
3. **Questions:** every question the skill would have put to the owner, with the answer you gave and why (quote the guideline line).
4. **Git state:** `git -C /tmp/devshop-build/spike-site log --oneline launch` and the list of files you changed.
5. **Failed or improvised steps:** anything that did not work as the skill or guideline said, and what you did instead. Say explicitly whether anything was sent to any outside service.

Do not summarise or paraphrase the report: paste it. If you cannot start the browser at all after following the guideline's NEEDS_SETUP instruction, stop and return what you have with the exact error, marked COULD-NOT-RUN.
