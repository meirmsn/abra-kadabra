// What: Reference E2E for sign-up — exercises the auto-confirm shape
//       against the local Supabase stack (Mailpit + bare-/verify rewrite
//       via `helpers/inbucket.ts`). Projects extend this with project-
//       specific assertions after the magic-link redirect.
// Why: Ships as a worked example of the WebKit controlled-input fill
//       pattern (lesson 3) and the helper-driven mail polling pattern
//       (lessons 1+2). Delete + rewrite when your project ships a real
//       sign-up page; keep the patterns intact.
// Does NOT: Cover the no-enumeration prod shape (`enable_confirmations:
//           true` returns `{ user: { identities: [] }, session: null }`
//           on existing-account second-signup). That's a unit-level mock
//           per `kit/docs/guide/conventions.md § Supabase auth E2E
//           patterns`. This E2E covers the auto-confirm path only —
//           local stack defaults to `enable_confirmations: false`.

import { expect, test } from '@playwright/test';

import {
  extractMagicLink,
  fetchEmailBody,
  waitForLatestEmail,
} from './helpers/inbucket';

test.describe('sign-up', () => {
  test('new email → confirmation link arrives + completes auth', async ({
    page,
  }) => {
    const email = `signup-${Date.now()}@test.local`;
    const password = 'Sup3rSecret!';

    await page.goto('/sign-up');

    // WebKit controlled-input fill pattern — `pressSequentially` gives
    // React time to settle the controlled-input value attribute. Plain
    // `fill()` resolves before React syncs and the form submits with
    // empty fields on WebKit. See `kit/docs/guide/conventions.md §
    // Playwright + controlled inputs on WebKit`.
    const emailInput = page.locator('#email');
    await emailInput.click();
    await emailInput.pressSequentially(email, { delay: 10 });
    await expect(emailInput).toHaveValue(email);

    const passwordInput = page.locator('#password');
    await passwordInput.click();
    await passwordInput.pressSequentially(password, { delay: 10 });
    await expect(passwordInput).toHaveValue(password);

    await page.getByRole('button', { name: /sign up/i }).click();

    const summary = await waitForLatestEmail(email);
    const body = await fetchEmailBody(email, summary.id);
    const link = extractMagicLink(body);

    await page.goto(link);

    // Project-specific: replace with the assertion that proves auth
    // landed (e.g., signed-in nav, /home redirect, profile element).
    await expect(page).toHaveURL(/\/(home|onboarding|$)/);
  });
});
