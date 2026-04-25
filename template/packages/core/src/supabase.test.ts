// What: Unit tests for createClient + assertNotProdUrlInTestEnv
// Why: Lock down the prod-URL guard's behavior — fires only in test env, only
//      against the configured prod project ref, no-ops everywhere else.
// Does NOT: Hit a real Supabase instance (createClient builds the client object
//           but never issues a network request in this suite).

import { describe, it, expect, vi, afterEach } from 'vitest';
import { createClient, assertNotProdUrlInTestEnv } from './supabase';
import type { CoreConfig } from './supabase';

// Substituted at scaffold time by /ak-new-project Step 10 alongside the
// PRODUCTION_PROJECT_REF constant in supabase.ts. While the placeholder is
// unsubstituted, the guard self-disables (see supabase.ts), so the
// "throws on prod URL" tests are skipped.
const PROD_REF = 'PROJECT_REF_PLACEHOLDER';
const guardActive = PROD_REF !== 'PROJECT_REF_PLACEHOLDER';
const PROD_URL = `https://${PROD_REF}.supabase.co`;

describe('createClient', () => {
  it('returns a Supabase client with the given config', () => {
    const config: CoreConfig = {
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'test-anon-key',
    };

    const client = createClient(config);

    expect(client).toBeDefined();
    expect(typeof client.from).toBe('function');
    expect(typeof client.auth).toBe('object');
  });

  it.skipIf(!guardActive)(
    'throws when test env tries to dial the production project',
    () => {
      // NODE_ENV is 'test' by vitest default — the guard fires on the prod URL.
      const config: CoreConfig = {
        supabaseUrl: PROD_URL,
        supabaseAnonKey: 'prod-anon-key',
      };

      expect(() => createClient(config)).toThrow(/production project/);
    }
  );
});

describe('assertNotProdUrlInTestEnv', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it.skipIf(!guardActive)(
    'throws in test env when URL points at the production project ref',
    () => {
      expect(() => assertNotProdUrlInTestEnv(PROD_URL)).toThrow(
        /NODE_ENV=test/
      );
    }
  );

  it('no-ops in test env for non-production URLs (localhost, staging, fake)', () => {
    expect(() =>
      assertNotProdUrlInTestEnv('http://127.0.0.1:54321')
    ).not.toThrow();
    expect(() =>
      assertNotProdUrlInTestEnv('https://staging.supabase.co')
    ).not.toThrow();
    expect(() =>
      assertNotProdUrlInTestEnv('https://test.supabase.co')
    ).not.toThrow();
  });

  it.skipIf(!guardActive)(
    'no-ops in production env even for the production URL',
    () => {
      vi.stubEnv('NODE_ENV', 'production');
      expect(() => assertNotProdUrlInTestEnv(PROD_URL)).not.toThrow();
    }
  );

  it.skipIf(!guardActive)(
    'no-ops in development env (preserves dev-against-prod workflow)',
    () => {
      vi.stubEnv('NODE_ENV', 'development');
      expect(() => assertNotProdUrlInTestEnv(PROD_URL)).not.toThrow();
    }
  );
});
