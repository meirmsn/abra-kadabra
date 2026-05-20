// What: Tiny helper for fetching emails from the local Supabase mail relay
//       (Mailpit; previously Inbucket pre-CLI v2.x) and parsing the most
//       recent magic-link URL out of the message body.
// Why: Sign-up confirmation, forgot-password, magic-link, and invite E2Es
//      need to follow the magic-link the way a real user would. Mailpit
//      exposes a JSON API at port 54324 (default) that we poll until the
//      message lands.
// Does NOT: Talk to hosted Supabase (email-template rendering happens on
//           Supabase's mail relay there; specs gate on the local stack
//           via isLocalSupabase()).
//
// Naming: file is `inbucket.ts` for historical reasons — Supabase CLI swapped
// inbucket for mailpit in v2.x and never updated the env var name (it still
// surfaces as INBUCKET_URL in `supabase status -o env`). The relay is mailpit;
// the helper name preserves the env-var naming for grep continuity.
//
// Canonical source: kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 9.
// Any improvements here should also land there so future scaffolds copy
// the latest shape verbatim.

/**
 * Derive mailpit's host from SUPABASE_URL so the helper works in both:
 *   - Workspace devcontainer (test SKIPS here — `isLocalSupabase()` only
 *     trues for 127.0.0.1/localhost shapes, not the workspace's
 *     `host.docker.internal` URL).
 *   - GitHub Actions slow-job: SUPABASE_URL=http://127.0.0.1:54321 (Supabase
 *     binds directly to the runner's localhost; mailpit listens on 54324
 *     on the same host).
 */
function deriveMailpitBase(): string {
  const supabaseUrl = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
  try {
    const host = new URL(supabaseUrl).hostname;
    return `http://${host}:54324`;
  } catch {
    return 'http://127.0.0.1:54324';
  }
}

const MAILPIT_BASE = deriveMailpitBase();

interface MailpitSummary {
  ID: string;
  From: { Name: string; Address: string };
  To: { Name: string; Address: string }[];
  Subject: string;
  Snippet: string;
  Created: string;
}

interface MailpitListResponse {
  total: number;
  messages_count: number;
  start: number;
  messages: MailpitSummary[];
}

interface MailpitMessage {
  HTML?: string;
  Text?: string;
}

export interface EmailSummary {
  id: string;
  subject: string;
  to: string;
  date: string;
}

/**
 * Wait until mailpit has at least `minCount` messages addressed to `address`,
 * then return the latest summary. Polls every 500ms up to the given timeout.
 *
 * We use mailpit's search endpoint (`/api/v1/search?query=to:<addr>`) so
 * cross-test mailbox pollution from other parallel specs doesn't trip us up.
 */
export async function waitForLatestEmail(
  address: string,
  options: { minCount?: number; timeoutMs?: number } = {}
): Promise<EmailSummary> {
  const minCount = options.minCount ?? 1;
  const timeoutMs = options.timeoutMs ?? 30_000;
  const start = Date.now();
  let lastErr: unknown = null;
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(
        `${MAILPIT_BASE}/api/v1/search?query=${encodeURIComponent(`to:${address}`)}&limit=50`
      );
      if (res.ok) {
        const data = (await res.json()) as MailpitListResponse;
        if (data.messages.length >= minCount) {
          const m = data.messages[0]!;
          return {
            id: m.ID,
            subject: m.Subject,
            to: m.To[0]?.Address ?? address,
            date: m.Created,
          };
        }
      }
    } catch (err) {
      lastErr = err;
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(
    `mailpit: no message for ${address} after ${timeoutMs}ms (expected at least ${minCount}; base=${MAILPIT_BASE}; lastErr=${lastErr instanceof Error ? lastErr.message : String(lastErr)})`
  );
}

/** Fetch the full body for a given mailpit message. */
export async function fetchEmailBody(
  _address: string,
  id: string
): Promise<{ body?: { html?: string; text?: string } }> {
  const res = await fetch(`${MAILPIT_BASE}/api/v1/message/${id}`);
  if (!res.ok) {
    throw new Error(
      `mailpit: failed to fetch message ${id} (status ${res.status}; base=${MAILPIT_BASE})`
    );
  }
  const data = (await res.json()) as MailpitMessage;
  return { body: { html: data.HTML, text: data.Text } };
}

/**
 * Pull the magic-link URL out of an email body. HTML body carries the
 * rendered template (anchor href); text body carries the plain-text link.
 * Try HTML first, fall back to text.
 *
 * Link path shape depends on Supabase's flow:
 *   - Token-hash flow (default `{{ .ConfirmationURL }}`):
 *     `{SiteURL}/auth/v1/verify?token=<hash>&type=<type>&redirect_to=<...>`
 *   - Direct PKCE flow: link points at redirect_to with `?code=<...>` appended.
 * Either is fine for E2E — `page.goto(link)` follows redirects — so the
 * regex matches both.
 */
export function extractMagicLink(message: {
  body?: { html?: string; text?: string };
}): string {
  const html = message.body?.html ?? '';
  const text = message.body?.text ?? '';
  const re =
    /https?:\/\/[^\s"'<>]*(?:\/auth\/v1\/verify|\/verify|\/auth\/callback|[?&](?:code|token|token_hash)=)[^\s"'<>]*/i;
  const fromHtml = html.match(re)?.[0];
  if (fromHtml) return rewriteBareVerify(decodeHtmlEntities(fromHtml));
  const fromText = text.match(re)?.[0];
  if (fromText) return rewriteBareVerify(decodeHtmlEntities(fromText));
  throw new Error(
    `mailpit: no auth-flow URL found in email body (html=${html.slice(0, 400)}…, text=${text.slice(0, 400)}…)`
  );
}

/**
 * Some Supabase CLI versions render `{{ .ConfirmationURL }}` with a bare
 * `/verify?...` path on the auth host (`http://127.0.0.1:54321/verify?...`)
 * instead of the Kong-prefixed `/auth/v1/verify?...`. The bare path 404s
 * because Kong only proxies `/auth/v1/*`. We rewrite to the Kong path so
 * the recovery flow exercises end-to-end. Production hosted Supabase
 * doesn't have this issue (the external URL includes /auth/v1 by default).
 */
function rewriteBareVerify(url: string): string {
  return url.replace(
    /^(https?:\/\/[^/]+)\/verify(\?|$)/,
    '$1/auth/v1/verify$2'
  );
}

/**
 * Decode the handful of HTML entities that show up in an `href`. Supabase's
 * email template renders `{{ .ConfirmationURL }}` into an HTML-escaped href,
 * so `?token=foo&type=recovery` becomes `?token=foo&amp;type=recovery`.
 * Passing that to `page.goto` would treat `&amp;` as a literal query
 * separator and Supabase 400s with "Verify requires a verification type."
 */
function decodeHtmlEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}
