// What: Typed Supabase client factory + test-env prod-URL guard
// Why: Framework-agnostic factory — each app passes config in, no env var reads here.
//      Guard catches NODE_ENV=test callers that would accidentally dial prod (e.g.
//      a unit test reading GH Secrets that still point at the production project).
// Does NOT: Read environment variables itself, manage auth state, handle SSR/client split.

import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import type { Database } from './supabase.types';

/** Configuration required to create a Supabase client. */
export interface CoreConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
}

/**
 * Project ref of the production Supabase instance. Hard-coded as a safety
 * landmark — not a secret (the URL is public, the anon key is public).
 * Substituted at scaffold time by /ak-new-project Step 10 from $SUPABASE_URL
 * in .devcontainer/.env. Matched by `assertNotProdUrlInTestEnv` to catch
 * tests that would dial prod.
 *
 * Two distinct literals on purpose: the assignment string below gets
 * substituted by Step 10; the self-disable check compares against the
 * sentinel `UN` + `SCAFFOLDED` (written so the placeholder regex never
 * matches it). If both literals matched the substitution pattern, the
 * global sed would rewrite the check into `if (<ref> === <ref>) return;`
 * — silently disabling the guard in every scaffolded project. Widening to
 * `: string` keeps the post-substitution comparison legal under TS
 * literal-type narrowing.
 */
const PRODUCTION_PROJECT_REF: string = 'PROJECT_REF_PLACEHOLDER';

/**
 * Throw when a test-env caller would instantiate a Supabase client pointing
 * at the production project. Protects the fast-job CI path where GitHub
 * Variables/Secrets may still carry prod values — a unit test that calls
 * `.from()` / `.rpc()` would otherwise silently hit prod. Dev + production
 * runtimes skip the guard on purpose: dev may point at prod for QA walks,
 * prod must talk to prod.
 */
export function assertNotProdUrlInTestEnv(url: string): void {
  if (process.env.NODE_ENV !== 'test') return;
  if (PRODUCTION_PROJECT_REF === 'UNSCAFFOLDED') return;
  if (!url.includes(`${PRODUCTION_PROJECT_REF}.supabase.co`)) return;
  throw new Error(
    `Refusing to instantiate a Supabase client pointing at the production ` +
      `project (${PRODUCTION_PROJECT_REF}) from NODE_ENV=test. Unit tests ` +
      `must mock the client or point at http://127.0.0.1:54321 (local ` +
      `Supabase). URL seen: ${url}`
  );
}

/** Creates a typed Supabase client from the given config. */
export function createClient(config: CoreConfig) {
  assertNotProdUrlInTestEnv(config.supabaseUrl);
  return createSupabaseClient<Database>(
    config.supabaseUrl,
    config.supabaseAnonKey
  );
}
