# A change the session starts on its own is timed from the previous merge

**Go:** "Do the small PR." on the proposal to start the clock at the previous merge when no owner message comes before the PR's merge (owner, 2026-10-16)

## Intent

PR 135's metrics comment read "request to live **unknown**" and "unknown answers in chat". The
session started that fix on its own right after PR 131 merged, and the owner's next message came
after PR 135 merged, so the clock had no start (`specs/deploy-and-metrics-comments.md`: the first
owner message after the session's previous merge). The owner asked whether that is a small fix, then:
"Do the small PR."

## Decisions

- **With no owner message between the session's previous merge and this PR's merge, the clock
  starts at that previous merge:** the session began the change then. Answers in chat count 0, not
  unknown. With an owner message in that window, nothing changes; with no previous merge and no owner
  message, the clock still has no start (owner: "Do the small PR.", 2026-10-16, on Claude's proposal)

## Acceptance items

- **AC-1** `change-metrics.py` starts the clock at the session's previous merge when no owner
  message falls between it and this PR's merge, and then shows times and "0 answers in chat"
- **AC-2** With an owner message in that window the clock starts there, as before; with neither a
  previous merge nor an owner message the numbers stay unknown

## Out of scope

- Re-posting PR 135's metrics comment
