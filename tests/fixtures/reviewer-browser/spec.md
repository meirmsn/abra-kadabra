# A notes page

**Go:** "go" (owner, 2026-10-18)

## Intent

The owner: "Add a notes page that lists my three notes as cards, built to `DESIGN.md`."

## Decisions

- One static page, `notes.html`, with its own `notes.css` beside `styles.css`; linked from the home
  page. It uses only `DESIGN.md`'s font stack, colour tokens and spacing steps (owner, 2026-10-18)

## Acceptance items

- **AC-1** `/notes.html` shows a page title "Notes" and three cards, each with a title and a line
  of text, in one column at 375px — verified by review: `devshop-browse /notes.html` and its
  375px screenshots
- **AC-2** The home page links to `/notes.html` — verified by review: `index.html` has the link
- **AC-3** The notes page follows `DESIGN.md` (its font stack, colour tokens and spacing steps, and
  no sideways scroll at 375, 768 or 1280px) — verified by review: `devshop-browse /notes.html`, its
  screenshots and facts, against `DESIGN.md`

## Out of scope

- Editing notes; any script
