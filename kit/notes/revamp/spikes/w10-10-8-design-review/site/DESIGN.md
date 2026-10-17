---
# gstack: design-md-format=spec
name: Example app
description: A calm household task list. Neutral cool-gray ground, one blue for actions, the system font stack, a 4 px spacing scale.
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
  destructive: "oklch(0.52 0.2 27)"
  border: "oklch(0.9 0.01 255)"
  ring: "oklch(0.6 0.17 262)"
  dark-background: "oklch(0.17 0.015 260)"
  dark-foreground: "oklch(0.96 0.005 250)"
  dark-card: "oklch(0.21 0.018 260)"
  dark-primary: "oklch(0.72 0.14 262)"
  dark-muted-foreground: "oklch(0.74 0.02 255)"
  dark-border: "oklch(0.3 0.02 260)"
typography:
  body:
    fontFamily: "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"
    fontSize: 1rem
    lineHeight: 1.5
  heading:
    fontFamily: "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"
    fontWeight: 650
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

A calm, practical task list for a household. Nothing decorative: the content is the interface.

## Colors

Only the tokens above, light and dark. `primary` is the one action colour; there is no second
accent hue. No other colour appears on a page.

## Typography

The system font stack only, for body and headings; no web fonts. Monospace only for code.

## Layout

Spacing comes only from the scale above (4, 8, 12, 16, 24 and 32 px), through the `--space-*`
tokens. One column at 375 px, wider from 768 px.

## Do's and Don'ts

- Do use the `--space-*`, colour and `--radius` tokens.
- Don't introduce a font, colour or spacing value outside this file.
