---
# gstack: design-md-format=spec
name: Ledger (fixture)
description: >
  A household ledger. Cool-gray ground, one blue for actions, a warm copper for the figure that
  matters, a serif display voice over a system body. A test fixture with synthetic values.
colors:
  background: "#fafafa"            # the ground
  foreground: "#1f2328"
  card: "#ffffff"
  card-foreground: "{colors.foreground}"
  primary: "oklch(0.5 0.19 262)"
  primary-foreground: "#ffffff"
  muted-foreground: "#5d6670"
  highlight: "oklch(0.62 0.16 48)"
  highlight-foreground: "oklch(0.99 0.005 60)"
  border: "#e1e4e8"
  dark-background: "#15181c"
  dark-foreground: "#f0f2f4"
  dark-card: "#1c2026"
  dark-card-foreground: "{colors.dark-foreground}"
  dark-primary: "oklch(0.72 0.14 262)"
  dark-primary-foreground: "#15181c"
  dark-muted-foreground: "#a5adb8"
  dark-highlight: "oklch(0.76 0.13 55)"
  dark-highlight-foreground: "oklch(0.2 0.03 50)"
  dark-border: "#2c323a"
typography:
  display:
    fontFamily: "'Instrument Serif', Georgia, 'Times New Roman', serif"
    fontWeight: 400
    letterSpacing: "-0.01em"
  body:
    fontFamily: "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"
    fontSize: 1rem
    lineHeight: 1.5
  mono:
    fontFamily: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
spacing:
  "1": 0.25rem
  "2": 0.5rem
  "4": 1rem
  "8": 2rem
rounded:
  default: 0.75rem
  sm: 0.25rem
---

## Overview

A household ledger: what came in, what went out, what is left. Calm and exact. The one place the
page raises its voice is a figure that matters, set in copper.

## Colors

The tokens above, light and dark. `primary` is the action colour. `highlight` (copper) is for the
one figure a section is about. No other colour appears.

## Typography

Headings are the display face; body and controls the system stack; monospace for code.

## Decisions

- 2026-11-01: a fixture for the shape check, with a display face, `{path}` references and `var()`
  aliases in its theme (specs/design-md-check.md).
