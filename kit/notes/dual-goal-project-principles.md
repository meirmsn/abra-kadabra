# Dual-goal project principles

Principles for projects where building the product and hardening the devshop are **both goals of the same effort** — not "build product fast, fix devshop later." Every gap the product surfaces is an opportunity to refine devshop so the next project inherits the fix.

**Origin**: distilled from the lalista v0 Swift → Web migration (2026-03 to 2026-04), which was the devshop's first real user. Preserved here as a reference for any future dual-goal project that deliberately uses the product as a devshop stress test.

**When this applies**: explicit dual-goal framing at kickoff. "We're building X AND hardening the devshop in the same sprint." Rare — most projects build the product and file devshop issues without using the product as a devshop-evolution forcing function.

**When this does NOT apply**: a routine project that just uses the devshop. Report friction via `kit/TODOS.md` / `kit/ROADMAP.md` normally; no need for the triage ceremony below.

---

## 1. Triage every finding at discovery time

Every finding has exactly one origin. Classify at the moment it surfaces:

- **A. Pure project** — product feature or UX decision (design tokens, specific layouts, business-logic-unique-to-this-product). **Always fix inline**; no devshop implication.
- **B. Pure devshop** — QA gap, tooling missing, reusable convention that spans projects. **Always route to devshop**; don't patch the project ad-hoc.
- **C. Both** — the most common case for auth / deploy / data / testing patterns. Needs an entry in both homes.

## 2. For Category C: ASK the user before choosing

On every Category C finding, stop and ask:

> "This is Category C. Implement the devshop fix now (slower, proves devshop works on this project), or capture in ROADMAP + fix the project inline (faster but accrues verification debt)?"

**Bias toward "implement now."** Deferring is a real choice with a real cost — the devshop helper stays untested until a future project surfaces the same gap. The point of a dual-goal project is to close those gaps now, while the product is actively forcing them.

## 3. Time-box rule (default for ambiguous cases)

- Devshop fix **< 1 day** → implement devshop FIRST, then apply to the project (adopt the new helper/convention). This is the preferred path.
- Devshop fix **≥ 1 day** → capture in ROADMAP with shape + trigger + prior-art references; fix the project inline; **verification debt is owed** (see principle 4).

## 4. Verification = refactor-to-adopt (NOT rebuild-from-scratch)

When a Category C finding is fixed inline (principle 3's ≥1 day branch), the devshop implementation still needs to be validated. The verification isn't rebuilding the project from scratch — it's refactor-to-adopt:

1. A future devshop session implements the convention/helper per the ROADMAP entry
2. A future project session **replaces** the inline code with imports from the new helper (delete the inline version)
3. Verify identical behavior: existing unit tests pass, QA walk passes, manual UX check matches
4. If identical → devshop is proven; any future project using the same helper gets the same behavior for free
5. If different → the devshop implementation is wrong; iterate until identical

This is how each ROADMAP entry gets discharged — not "we wrote the helper," but "the project successfully adopted it with no regression."

Track verification debt in the project's `TODOS.md` tagged `[verification-debt]` with a pointer to the devshop ROADMAP entry.

## 5. Stop criterion — when to let devshop be

Tied to milestones, not calendar time. Don't over-optimize devshop for problems the project hasn't hit yet.

Heuristic: if you're still finding >1 devshop gap per PR after the project's core milestones land, devshop isn't done. If you find zero per PR for two PRs in a row, you're done. Post-milestone findings go to ROADMAP with trigger = "next project surfaces this again."

---

## How to ASK (principle 2) — exact phrasing

When a Category C finding surfaces mid-session, present it like this:

> "Category C finding: `<description>`. Options:
>
> **A.** Implement devshop now (shape: `<1-line>`, est: `<hours/days>`). Paired project change: `<what adopts it>`. Proves the devshop helper works.
> **B.** Capture in ROADMAP + fix the project inline (est: `<hours>`). Fastest today; verification debt owed (devshop side untested until the refactor-to-adopt step).
>
> Bias is toward A unless you tell me otherwise. Which?"

This forces the triage to be explicit and auditable, rather than drifting to inline fixes by default.
