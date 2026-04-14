# Devshop TODOs

Devshop friction, bugs, and small fixes — things to do soon.
Strategic capabilities go in `ROADMAP.md`. Project issues go in root `TODOS.md`.

---

<!-- Items discovered during use. Tag with [v0.2], [v1] etc. to schedule into ROADMAP versions. -->

- [x] Review plan gaps after Phase 1: `notes/bootstrap/v0-gaps.md` — reviewed 2026-04-13 after devshop separation. 3 resolved by separation (#8 local dev docs, #9 mirror, minor gaps), 2 fixed (#1 dependabot, minor check-file-headers), 3 project decisions routed (#3 Zod, #4 state mgmt, #5 i18n), 3 added to ROADMAP (#2 staging v1, #10 axe-core v1, #11 logging v+), 2 already in ROADMAP (#6 tiered pre-ship, #7 subagent).
- [ ] Investigate scoping node user's sudo access — base image gives full passwordless sudo, which means Claude could bypass root-owned file protections via `sudo chown`. See `.devshop/notes/sudo-hardening.md` for analysis and approach. [post-Phase-1]
- [x] **RESOLVED: settings.json symlink fragility.** Fixed: settings.json and .dcg.toml are now root-owned copies (not symlinks). Sticky bit on `.claude/` prevents deletion. Freshness check (`check-security-files-freshness.sh`) runs at session start and pre-commit to detect staleness. [critical, 2026-04-14]
- [x] **RESOLVED: CLAUDE.md simplification.** Eliminated `CLAUDE.project.md` — project repo now has `CLAUDE.md` (tracked, project-only). Devshop conventions live in devshop repo root `CLAUDE.md`, auto-loaded via `additionalDirectories`. No assembly, no freshness checks. Public clones just work. [post-separation, 2026-04-14]
- [ ] Session-start uncommitted changes check: `session-start.sh` should check both `/workspace` and `/devshop` for uncommitted changes and warn. Currently the cross-repo check only fires at commit time — if only the devshop has changes and no project commit happens, nothing reminds Claude to commit there. [post-separation]
- [ ] Make `check-pr-description.sh` blocking: currently PostToolUse (advisory) — Claude can ignore it. Move to PreToolUse on `Bash(git push*)` with exit 2, or add a PreToolUse companion. Needs bypass mechanism for pushes where PR description is intentionally deferred. [post-separation]
- [ ] Make `check-dirty-after-commit.sh` blocking: currently PostToolUse (advisory) — Claude can ignore the cross-repo reminder after bypassing check 4. Consider a PreToolUse companion on the next `Bash(git *)` command that blocks until the other repo is committed. [post-separation]
- [x] Rename `/devshop:*` to `/ak-*` in user-facing docs — CLAUDE.md glossary, README.md glossary, GUIDE.md init heading, templates/README.md.tmpl. Skill-to-skill invocations left as `/devshop:*` (fully qualified name) — both forms work at runtime. [minor]
- [ ] Upgrade root ESLint from v9 to v10 — blocked by `eslint-config-next` which depends on `eslint-plugin-react@7.x` (uses `getFilename()` API removed in ESLint 10). **Trigger**: when Next.js ships an `eslint-config-next` version that supports ESLint 10, bump root `eslint` + `@eslint/js` to `^10` across all projects. Check: `npm info eslint-config-next peerDependencies` for eslint range. [blocked-upstream]
