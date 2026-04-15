# External Framework Review: Agentic Coding Flywheel Setup (ACFS)

**Repo**: https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup  
**Verdict**: Extract 4 specific insights. Do not adopt.

## What ACFS Is

A single-command bootstrap that provisions a fresh Ubuntu VPS with 80+ tools and a multi-agent coordination system (Claude Code + Codex CLI + Gemini CLI running in parallel). The "flywheel": detailed markdown planning → task dependency graphs ("beads") → PageRank-based task routing → Agent Mail coordination (file reservations) → session memory feeding future projects → loop repeats.

It solves: multi-agent deadlocks, duplicate effort across parallel agents, context loss between sessions, VPS provisioning. Active (4 months old, 1,355 stars), well-engineered (checksummed installers, idempotent setup, CI matrix tests).

## Why Not to Adopt

1. **Wrong environment**: Targets Ubuntu VPS. Our user is on Mac + devcontainer.
2. **Wrong scale**: Multi-agent coordination solves conflicts between 3+ parallel agents. We have 1 Claude Code session.
3. **Wrong simplicity bar**: 10+ custom coordination CLIs. Contradicts "simple, standard, boring" principle.
4. **Multi-provider**: Requires Anthropic + OpenAI + Google. We use only Claude Code.
5. **Too new**: 4 months old, documented known limitations.

## 4 Insights Extracted (Applied in devshop plan)

**1. Mechanical safety hooks** (from DCG: Destructive Command Guard)
ACFS blocks dangerous bash commands at execution time via `PreToolUse` hooks — not just warns. Applied: DCG (Destructive Command Guard) installed in Dockerfile + hook in `.claude/settings.json`. DCG handles this properly — correct stdin JSON parsing, 49+ packs, heredoc scanning, fail-open design — replacing what would have been a fragile homegrown bash script.

**2. Structured TASKS.md with dependencies + sub-agent resume** (from Beads)
Explicit dependency fields per task prevent agents from starting blocked work. Sub-agent resume pattern keeps main session context clean. Applied: TASKS.md format and resume pattern in .devshop/GUIDE.md.

**3. SPEC quality principle**
"Models are far smarter when reasoning about a plan that is detailed but fits in context." Their ratio: 85% planning, 15% coding. Applied: SPEC interview step (step 4 in workflow) + SPEC quality checklist in .devshop/GUIDE.md.

**4. Post-feature memory extraction** (from CASS Memory)
After each feature ships, run structured reflection → update memory files + confidence calibration. Applied: step 11 in workflow (post-merge); prompt documented above.
