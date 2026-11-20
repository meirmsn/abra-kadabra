# Add a --shout flag

**Go:** pending

## Intent

The owner: "Add a --shout flag to cli.js that prints the greeting in upper case."

## Decisions

- **Position:** the flag works before or after the name; rejected: first argument only (owner, 2026-01-01)

## Acceptance items

- **AC-1** `node cli.js --shout Ada` prints `HELLO, ADA!`.

## Out of scope

- Other flags.
