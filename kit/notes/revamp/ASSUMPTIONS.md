# Assumptions register

The revamp's biggest risk isn't a bug in a task — it's building on an assumption
that turns out false. REVIEW-1 found three such (the git proxy restricts branches;
"owner approves" is enforceable; `--bare` works in cloud), all **before** any code
was built on them. This register keeps doing that deliberately.

Rule ([PROCESS.md § Assumptions first](PROCESS.md#assumptions-first)): before an
epic builds on an assumption marked `untested`, the cheapest experiment that could
falsify it runs first. A falsified assumption triggers replanning, not a workaround.

Status: `untested` · `validated` (how, when) · `falsified` (what changed) · `accepted risk` (owner decision).

| ID   | Assumption                                                                                                               | Load-bearing for           | Cheapest test                                                             | Status                                 |
| ---- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------- | ------------------------------------------------------------------------- | -------------------------------------- |
| A-01 | Cloud git proxy restricts pushes to the session branch                                                                   | old D-03/D-04              | read docs                                                                 | **falsified** 2026-10-08 (REVIEW-1 E1) |
| A-02 | "Owner approves PR" is enforceable while the agent uses the owner's identity                                             | old D-04                   | `gh api user` + PR author check                                           | **falsified** 2026-10-08 (REVIEW-1 E2) |
| A-03 | `claude -p --bare` works for a headless reviewer in cloud/subscription                                                   | old W1.2.2                 | one call in a cloud session                                               | **falsified** 2026-10-08 (REVIEW-1 E3) |
| A-04 | Non-bare locked-down `claude -p` returns reliable structured verdicts                                                    | W1.2, W6.1.3               | one call in cloud (done) + 20 calls on fixed inputs for stability         | partly validated (1 call)              |
| A-05 | A cloud session can run under a GitHub identity other than the owner's                                                   | D-13 A, W0.6.3             | `/web-setup` with a machine-user token in a test session; check PR author | untested                               |
| A-06 | No-bypass rulesets reject direct/force pushes from the agent's credentials (incl. admin) and from the contents API       | D-04, W0.6                 | apply on the fixture repo; attempt each path                              | untested                               |
| A-07 | A cloud session can push `.github/workflows/` changes (or can't — either way we need to know)                            | W3.1.1, D-04               | push a workflow edit to a scratch branch of the fixture                   | untested                               |
| A-08 | Single-repo cloud sessions apply committed `.claude/settings.json` hooks + permissions                                   | D-01, W4.2                 | commit a trivial hook in the fixture; observe in a cloud session          | validated by docs; not yet observed    |
| A-09 | A cloud setup script can fetch a pinned devshop from a public source and user-scope (`~/.claude`) skills/hooks then load | D-01 D                     | spike W4.2.0                                                              | untested                               |
| A-10 | Project-level / claude.ai-synced plugins can be pinned to a version                                                      | D-01 C                     | spike W4.2.0                                                              | untested                               |
| A-11 | Local services (Supabase via Docker) start in a cloud session fast enough to use per change                              | W4.3.2                     | `supabase start` on the fixture in cloud; time it                         | Docker validated; Supabase untested    |
| A-12 | An LLM conformance reviewer can reach ≥0.8 precision and recall on seeded spec violations                                | W6.1.3–4 (blocking or not) | eval set W3.4.3 (≥5 seeded + ≥5 honest), before building the full gate    | untested                               |
| A-13 | Upstream gstack ≥1.91.13 runs in our environment (proxy, Bun, locked settings) without forking                           | W7, D-07                   | install in a cloud scratch session; run `/review` + `/qa` on the fixture  | untested                               |
| A-14 | Owner capacity covers the review load (~47 PRs, ~15 decisions) at the planned pace                                       | whole plan                 | owner states hours/week (W0.2.3); compare after M0                        | untested                               |
| A-15 | A thin devshop (D-14 B) still delivers the artifact chain + guardrails the owner wants                                   | D-14                       | walking skeleton (W3.5) run on the fixture — owner judges the experience  | untested                               |
| A-16 | Moving enforcement to CI keeps the feedback loop fast enough for autonomous work (CI minutes per change)                 | D-04, D-06, W6.4           | measure CI duration on the walking skeleton                               | untested                               |

Add rows whenever a design choice rests on something not yet observed. Prefer
running a 30-minute experiment over writing a paragraph of reasoning.
