# The metrics comment shows hours and minutes from an hour up

**Go:** "the 221 min should have been hours and min (you can do just minutes if less than 60)" (owner, 2026-10-16)

## Intent

PR 136's metrics comment read "request to live **221 min**". The owner (2026-10-16): "wait, the
221 min should have been hours and min (you can do just minutes if less than 60)".

## Decisions

- **From 60 minutes up, a time shows hours and minutes:** "3 h 41 min", or "2 h" for a whole hour;
  10 to 59 minutes stay whole minutes ("27 min"), and under 10 minutes keep their seconds ("3 min 31
  s", from `specs/deploy-and-metrics-comments.md`). Minutes are rounded first, so 59.6 minutes is
  "1 h" (owner, 2026-10-16)

## Acceptance items

- **AC-1** `change-metrics.py` writes a time of 60 minutes or more as "<h> h <m> min", or "<h> h" when
  the minutes are 0, everywhere it writes a time; times from 10 to 59 minutes and under 10 minutes
  are unchanged

## Out of scope

- Re-posting the metrics comments already posted
