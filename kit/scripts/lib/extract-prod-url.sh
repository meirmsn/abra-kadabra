#!/usr/bin/env bash
# kit/scripts/lib/extract-prod-url.sh
#
# Tiny, sourceable helper exposing extract_prod_url() for `/ak-go-live`:
#   - Step 1.5 (production health probe)
#   - Step 1.5 Mode A in-session escape hatch
#   - Step 3 reuses Step 1.5's result, so no third call site.
#
# Single source of truth — the two call sites previously carried identical
# inline `sed` pipelines, so a parse bug broke BOTH. home-os PR #39's
# /ak-go-live run hit exactly this: home-os's CLAUDE.md writes the URL
# mid-sentence —
#   Production URL: `https://home-os-nu-two.vercel.app`. Full deploy config: ...
# The old `sed 's/^[^:]*:[[:space:]]*//'` took the rest of the line, then
# the global space-strip glued the host to the trailing prose
# (`home-os-nu-two.vercel.app.Fulldeployconfig...`), failing DNS validation
# and silently skipping the probe.
#
# This file does NOT execute anything when sourced — it only defines the
# `extract_prod_url` function. Safe to `source` without `set -euo pipefail`
# interactions.

# extract_prod_url <claude-md-path>
#
# Echo the bare production hostname (no scheme, no path, no trailing dot)
# parsed from the first `Production URL` line of <claude-md-path>, or echo
# nothing (empty) when no valid host is found.
#
# Tolerates the URL appearing anywhere on the line, and the `Production URL:`
# label appearing either at line start or mid-sentence (after a `. ` boundary),
# in any of the shapes seen in the wild:
#   Production URL: https://app.vercel.app
#   Production URL: `https://app.vercel.app`. More prose here.
#   Production URL: app.vercel.app                  (scheme-less)
#   - **Production URL:** https://app.vercel.app/path  (path stripped)
#   Vercel auto-on-push (...). Production URL: `https://app.vercel.app`.  (mid-sentence label)
#
# Returns the host only; the caller is responsible for re-adding `https://`
# and for DNS-label validation (the validation regex stays at the call site
# so the "configured but malformed" vs "not configured" messaging is local).
#
# Exit code: 0 always — "no host found" is a valid outcome (caller treats
# empty as "not configured" and skips the probe).
extract_prod_url() {
  local claude_md="$1"
  [ -z "$claude_md" ] || [ ! -f "$claude_md" ] && return 0

  local raw_line host tail
  # Anchor on the canonical `Production URL:` label. The label may appear
  # either at line start (after optional Markdown bullet / blockquote / bold
  # wrappers) OR after a sentence boundary (`. `) so a project that writes the
  # URL mid-sentence still matches — e.g. home-os's
  #   Vercel auto-on-push (...). Production URL: `https://...`. Full config: ...
  # where the line STARTS with "Vercel auto-on-push", not the label. The
  # trailing `:` is load-bearing: it keeps a bare prose mention like
  # "see the production url docs before deploying" (no colon) from matching,
  # preserving the guard that an earlier prose line can't win over the real
  # config line. `grep -i 'production.*url'` (unanchored) matched those words
  # anywhere, picking the wrong line → silent skip / wrong host.
  raw_line=$(grep -iE '(^|[.][[:space:]])[[:space:]]*[-*+>_ ]*production url[*_ ]*:' "$claude_md" 2>/dev/null | head -1)
  [ -z "$raw_line" ] && return 0

  # Trim everything up to and including the label so any prose — and any stray
  # http(s) URL — BEFORE the label on the same line can't be picked as the
  # host. Without this, the mid-sentence shape "See https://docs.x. Production
  # URL: https://real.x" would let the first-token grab return the docs host.
  # Case classes spelled out (not a `sed` `I` flag) to match the scheme-strip
  # style below and stay portable to BSD sed.
  tail=$(printf '%s' "$raw_line" \
    | sed -E 's/^.*[Pp][Rr][Oo][Dd][Uu][Cc][Tt][Ii][Oo][Nn][[:space:]][Uu][Rr][Ll][*_ ]*://')

  # Preferred: grab the first explicit http(s) URL token. The character
  # class stops at the first non-URL char (backtick, period+space, closing
  # paren, quote), so trailing prose and Markdown punctuation are excluded.
  # A path is dropped because `/` is not in the class. A trailing dot
  # (URL ending a sentence: `...app.`) is stripped after the fact.
  host=$(printf '%s' "$tail" \
    | grep -oiE 'https?://[a-zA-Z0-9.-]+' | head -1 \
    | sed -E 's|^[Hh][Tt][Tt][Pp][Ss]?://||; s/[.]+$//')

  # Fallback for scheme-less configs (`Production URL: app.vercel.app`):
  # strip leading whitespace + Markdown wrappers from the post-label tail,
  # then take the first hostname-shaped token.
  if [ -z "$host" ]; then
    host=$(printf '%s' "$tail" \
      | sed -E 's/^[[:space:]]*//; s/[`<>"'\'']+//g' \
      | grep -oE '[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+' \
      | head -1)
  fi

  printf '%s' "$host"
}
