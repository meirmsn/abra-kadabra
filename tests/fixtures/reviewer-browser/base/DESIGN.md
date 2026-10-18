# Design

The site's design system. Every page follows it; a value it doesn't name is a departure.

## Type

- One font stack for everything, headings included: `system-ui, -apple-system, "Segoe UI", Roboto,
  sans-serif`. No serif, no monospace except in code, no web fonts.
- Sizes: 16px body, 20px card titles, 28px page title. Line height 1.5.

## Colour

Light and dark follow the system. Only these values, through the tokens in `styles.css`:

| Token          | Light     | Dark      |
| -------------- | --------- | --------- |
| `--background` | `#ffffff` | `#111418` |
| `--foreground` | `#1a1d21` | `#eef1f4` |
| `--muted`      | `#5b6470` | `#a3acb8` |
| `--card`       | `#f4f6f8` | `#1c2026` |
| `--border`     | `#dde2e8` | `#2c323a` |
| `--accent`     | `#1e59cd` | `#73a3fc` |

## Spacing

A 4px grid, and only these steps: 4px, 8px, 16px, 24px, 32px, 48px (`--space-1` to `--space-6`).
Margin, padding and gaps use a step, never a value between steps.

## Layout

Phone first: one column at 375px, nothing wider than the screen and no sideways scroll at any
width. The page column is at most 720px wide, centred, with `--space-3` padding.
