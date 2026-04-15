# Abra-Kadabra Devshop — Conceptual Model

A transparent, opinionated workshop for building software. You bring the product
idea and taste. The devshop handles everything technical — from planning through
production — following industry-standard practices. You can always open the hatch
to see and improve the inner workings.

## Three Layers

```
┌─────────────────────────────────┐
│           Project               │  Your code. Clean repo.
│         /workspace/             │
├─────────────────────────────────┤
│        Workshop (ak)            │  Process, orchestration, quality
│         /devshop/               │
├─────────────────────────────────┤
│        Toolbox (gstack)         │  Building-block skills
│       (third-party)             │
└─────────────────────────────────┘
```

**Toolbox (gstack)** — Third-party toolkit. Individual skills: browse, review,
plan, qa, ship, canary, etc. Devshop consumes it; gstack doesn't know devshop
exists. Evolves independently — when gstack adds a capability devshop was doing
custom, devshop adopts it.

**Workshop (ak)** — What devshop adds on top. Orchestrates toolbox skills into
end-to-end workflows (ak-build, ak-go-live), enforces quality gates (ak-pre-ship),
and maintains conventions, hooks, and security. Opinionated defaults reusable
across projects.

**Project** — The software being built. Clean repo — code, tests, CI. A public
contributor sees normal commits, PRs, and workflows. No devshop artifacts.

## Two Repos

|                     | Devshop                        | Project                 |
| ------------------- | ------------------------------ | ----------------------- |
| Contains            | Tools, process, docs, template | Product code, tests, CI |
| Source of truth for | How to build                   | What to build           |
| Git visibility      | Private                        | Public-friendly         |
| Mount               | `/devshop/`                    | `/workspace/`           |

They meet inside the **container**. At startup, the devshop injects itself into the
project workspace — skills become available, hooks activate, docs are reachable.
The project repo stays clean.

## The Pipeline

```
idea → /office-hours → /autoplan → /ak-spec → /ak-build → you review → /ak-go-live
       product         plan         spec        build+test   approval     deploy+monitor
       conversation    architecture             +quality                  +canary
```

You participate at product conversations and review. Everything else is autonomous.
Engineering insights flow upward — implementation details that the product stage
didn't anticipate inform the roadmap.

## File Lifecycle

Every file in the project falls into one of three categories:

| Category            | How it works                 | When changes take effect | Examples                     |
| ------------------- | ---------------------------- | ------------------------ | ---------------------------- |
| **Project-owned**   | Normal git files             | Immediately              | `src/`, `CLAUDE.md`          |
| **Devshop-linked**  | Symlink to `/devshop/`       | Immediately              | `.devshopkit/`, skills       |
| **Security-locked** | Root-owned copy from devshop | Next container start     | `settings.json`, `.dcg.toml` |

When something isn't working, this tells you where to look and what to expect.

## Security

One principle: **Claude cannot weaken its own guardrails.**

- **Firewall** — allowlisted outbound traffic only
- **Root-owned files** — settings, configs, scripts can't be modified by Claude's user
- **Pre-commit hooks** — enforce conventions before code enters git
- **DCG** — blocks destructive commands

## Kit Layout

The devshop's operational files live in `kit/` (devshop repo) / `.devshopkit`
(project workspace, via symlink):

```
kit/
├── docs/          documentation (MODEL, OVERVIEW, FAQ, guide/)
├── scripts/       injection, checks, sync
├── hooks/         pre-commit
├── notes/         historical design decisions
├── manifest.txt   sync manifest (which files sync between repos)
└── version        current devshop version
```

## Where to Learn More

| Doc                        | When to read it                                    |
| -------------------------- | -------------------------------------------------- |
| `kit/docs/OVERVIEW.md`     | Orientation — file map, glossary, key conventions  |
| `kit/docs/guide/README.md` | Before making decisions — index to detailed guides |
| `kit/docs/FAQ.md`          | "Why did we do X?" — design rationale              |
| `kit/notes/`               | Historical — bootstrap records, design decisions   |
