# Devshop TODOs

Devshop friction, bugs, and small fixes — things to do soon.
Strategic capabilities go in `ROADMAP.md`. Project issues go in root `TODOS.md`.

---

<!-- Items discovered during use. Tag with [v0.2], [v1] etc. to schedule into ROADMAP versions. -->

- [ ] Review plan gaps after Phase 1: `notes/bootstrap/v0-gaps.md` — 11 structural holes + minor gaps identified during plan review (2026-04-05). Includes: missing dep scanning, no staging DB, no validation library, no state management architecture, no i18n decision, pre-ship pipeline too heavy, context pressure, no local dev docs, mirror complexity, no a11y automation, no structured logging. [post-Phase-1]
- [ ] Uncomment mirror sync tests in `ci.yml` when public mirror is implemented [v1]
- [ ] Investigate scoping node user's sudo access — base image gives full passwordless sudo, which means Claude could bypass root-owned file protections via `sudo chown`. See `.devshop/notes/sudo-hardening.md` for analysis and approach. [post-Phase-1]
- [ ] Public clone UX: project repos have `CLAUDE.project.md` (not `CLAUDE.md`). For public contributors without the devshop, add a note to the project README: rename `CLAUDE.project.md` → `CLAUDE.md`. Update `/ak-init` and/or `init-devshop.sh` to auto-inject this note into the project README during setup. [post-separation]
- [ ] Upgrade root ESLint from v9 to v10 — blocked by `eslint-config-next` which depends on `eslint-plugin-react@7.x` (uses `getFilename()` API removed in ESLint 10). **Trigger**: when Next.js ships an `eslint-config-next` version that supports ESLint 10, bump root `eslint` + `@eslint/js` to `^10` across all projects. Check: `npm info eslint-config-next peerDependencies` for eslint range. [blocked-upstream]
