# Guide — Table of Contents

Operational reference for the devshop. Read the relevant section before making decisions.

For the conceptual model (start here if new): [`../MODEL.md`](../MODEL.md)
For orientation and file map: [`../OVERVIEW.md`](../OVERVIEW.md)
For design rationale ("why X?"): [`../FAQ.md`](../FAQ.md)

## Sections

| Guide                              | What it covers                                                                            | When to read                                         |
| ---------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| [workflow.md](workflow.md)         | Pipeline steps 1–6, skill maps, new project setup                                         | Planning or running a feature end-to-end             |
| [conventions.md](conventions.md)   | Testing, metrics, responsive/PWA, code structure, confidence calibration, backlog routing | Before implementing or reviewing code                |
| [hooks.md](hooks.md)               | Claude Code hooks, git pre-commit chain, commit flow, bypass mechanism                    | When a commit is blocked or hook behavior is unclear |
| [security.md](security.md)         | Security model, root-owned files, DCG, known gaps                                         | Modifying security-related code or devshop guards    |
| [architecture.md](architecture.md) | Two-repo model, file lifecycle, init-devshop.sh, sync, doc structure                      | Understanding how devshop and project connect        |
| [ops.md](ops.md)                   | Where things happen, stack, env vars, local dev, quotas, rollback, troubleshooting        | Day-to-day development, debugging, emergencies       |
