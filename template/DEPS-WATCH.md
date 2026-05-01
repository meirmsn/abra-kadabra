# DEPS-WATCH

Parked dependency upgrades waiting on upstream ecosystem readiness. Each row's
`recheck-on` date is when the session-start hook surfaces it as overdue (loud
🚨 banner in the briefing). Tell Claude "push X by 1 month" to defer; tell
Claude "park X for N weeks because Y" to add a row.

When upstream catches up, post `@dependabot unignore this dependency` on the
relevant PR — dependabot recreates the bump.

| recheck-on | dep | block | how-to-unignore |
| ---------- | --- | ----- | --------------- |

_No parked dependencies._
