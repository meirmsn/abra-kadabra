---
# gstack: design-md-format=spec
name: Ledger (scratch)
description: A household ledger. Cool-gray ground, one blue for actions, a warm copper for figures that matter, a serif display voice over a system body.
colors:
  background: "oklch(0.99 0.003 250)"
  foreground: "oklch(0.21 0.02 260)"
  card: "oklch(1 0 0)"
  primary: "oklch(0.5 0.19 262)"
  primary-foreground: "oklch(0.985 0.005 250)"
  secondary: "oklch(0.955 0.008 255)"
  muted: "oklch(0.955 0.008 255)"
  muted-foreground: "oklch(0.47 0.02 260)"
  accent: "oklch(0.94 0.025 262)"
  highlight: "oklch(0.62 0.16 48)"
  highlight-foreground: "oklch(0.99 0.005 60)"
  destructive: "oklch(0.52 0.2 27)"
  border: "oklch(0.9 0.01 255)"
  ring: "oklch(0.6 0.17 262)"
  dark-background: "oklch(0.17 0.015 260)"
  dark-foreground: "oklch(0.96 0.005 250)"
  dark-card: "oklch(0.21 0.018 260)"
  dark-primary: "oklch(0.72 0.14 262)"
  dark-highlight: "oklch(0.76 0.13 55)"
  dark-highlight-foreground: "oklch(0.2 0.03 50)"
  dark-muted-foreground: "oklch(0.74 0.02 255)"
  dark-border: "oklch(0.3 0.02 260)"
typography:
  display:
    fontFamily: "'Instrument Serif', Georgia, 'Times New Roman', serif"
    fontWeight: 400
    letterSpacing: "-0.01em"
  body:
    fontFamily: "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"
    fontSize: 1rem
    lineHeight: 1.5
  mono:
    fontFamily: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
spacing:
  "1": 0.25rem
  "2": 0.5rem
  "3": 0.75rem
  "4": 1rem
  "6": 1.5rem
  "8": 2rem
rounded:
  default: 0.75rem
---

## Overview

A household ledger: what came in, what went out, what is left. Calm and exact. The one place the
page raises its voice is a figure that matters, set in copper.

## Colors

The tokens above, light and dark. `primary` is the action colour. `highlight` (copper) is for the
one figure a section is about, never for chrome or text at large. No other colour appears.

## Typography

Headings and section titles are the display face, `Instrument Serif`, regular weight, slightly
tightened; the fallbacks are in its stack. Body and controls are the system stack. Monospace only
for code. The display face is self-hosted when it ships; until then the stack's fallbacks draw it.

## Layout

Spacing from the scale above (4, 8, 12, 16, 24 and 32 px) through the `--space-*` tokens; one
radius; cards as in the baseline.

## Decisions

- 2026-10-31: scratch file for the design-guideline dry run; synthetic values throughout.
