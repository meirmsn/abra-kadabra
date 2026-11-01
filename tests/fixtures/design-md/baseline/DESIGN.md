---
# gstack: design-md-format=spec
name: The baseline
description: The devshop's UI baseline (runtime/templates/ui/base.css), written down as a DESIGN.md so the baseline is shown derivable. A test fixture; every value is base.css's.
colors:
  background: "oklch(0.99 0.003 250)"
  foreground: "oklch(0.21 0.02 260)"
  card: "oklch(1 0 0)"
  card-foreground: "oklch(0.21 0.02 260)"
  popover: "oklch(1 0 0)"
  popover-foreground: "oklch(0.21 0.02 260)"
  primary: "oklch(0.5 0.19 262)"
  primary-foreground: "oklch(0.985 0.005 250)"
  secondary: "oklch(0.955 0.008 255)"
  secondary-foreground: "oklch(0.27 0.03 260)"
  muted: "oklch(0.955 0.008 255)"
  muted-foreground: "oklch(0.47 0.02 260)"
  accent: "oklch(0.94 0.025 262)"
  accent-foreground: "oklch(0.32 0.09 262)"
  destructive: "oklch(0.52 0.2 27)"
  destructive-foreground: "oklch(0.985 0.005 250)"
  border: "oklch(0.9 0.01 255)"
  input: "oklch(0.82 0.012 255)"
  ring: "oklch(0.6 0.17 262)"
  dark-background: "oklch(0.17 0.015 260)"
  dark-foreground: "oklch(0.96 0.005 250)"
  dark-card: "oklch(0.21 0.018 260)"
  dark-card-foreground: "oklch(0.96 0.005 250)"
  dark-popover: "oklch(0.21 0.018 260)"
  dark-popover-foreground: "oklch(0.96 0.005 250)"
  dark-primary: "oklch(0.72 0.14 262)"
  dark-primary-foreground: "oklch(0.18 0.03 262)"
  dark-secondary: "oklch(0.27 0.02 260)"
  dark-secondary-foreground: "oklch(0.96 0.005 250)"
  dark-muted: "oklch(0.27 0.02 260)"
  dark-muted-foreground: "oklch(0.74 0.02 255)"
  dark-accent: "oklch(0.3 0.05 262)"
  dark-accent-foreground: "oklch(0.92 0.03 262)"
  dark-destructive: "oklch(0.66 0.19 25)"
  dark-destructive-foreground: "oklch(0.17 0.02 25)"
  dark-border: "oklch(0.3 0.02 260)"
  dark-input: "oklch(0.4 0.02 260)"
  dark-ring: "oklch(0.68 0.14 262)"
typography:
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

The baseline every devshop web app starts from: a neutral cool-gray ground, one blue for actions,
the system font stack, a 4 px spacing scale, one radius. Not a brand: the design-direction slice
replaces it.

## Colors

Only the tokens above, light and dark. `primary` is the one action colour. The shadow
(`--shadow`) is the theme's own, not a colour token.

## Typography

The system stack for body and headings; monospace only for code.

## Layout

Spacing from the scale above through the `--space-*` tokens; `--tap`, `--measure` and
`--page-max` are the baseline's layout constants.

## Decisions

- 2026-11-01: written as the shape check's fixture (specs/design-md-check.md); the values are
  base.css's, so a change to base.css changes this file too.
