# /screenshots

Dev-context screenshots — drop anything here that you want to share with Claude
or the team without committing it to git.

**What belongs here:**

- Screenshots you're attaching to a conversation ("look at this layout issue")
- Visual context for a bug report
- Reference inspiration ("make it look like this")
- Any other ephemeral visual artifact

**What does NOT belong here:**

- Per-feature product screenshots → `specs/<feature>/hero/` (tracked, captured
  by `/ak-pre-ship` or a QA-walk spec; embedded in PR bodies as evidence)
- Pre-ship gate evidence → `specs/<feature>/screenshots/` (tracked, regenerable)
- README banners / marketing / landing-page imagery → TBD when the project has
  public-facing content to showcase

## Why a separate folder

macOS (and humans) like to drop screenshots at the repo root. Those get caught
by `.gitignore`'s root-anchored `/Screenshot*.png` rule but leave the root
cluttered. This folder is the designated dumping ground — contents are fully
gitignored (except this README), so you can pile as much as you want without
polluting `git status`.
