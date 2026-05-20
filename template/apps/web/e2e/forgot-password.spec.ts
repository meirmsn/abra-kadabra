// What: Reference E2E for forgot-password — requests a recovery email,
//       polls Mailpit via the helper, follows the link, sets a new
//       password, then verifies sign-in with the new password works.
// Why: Worked example of the recovery flow against the local stack
//       (Pattern 10's host-anchored redirect is what makes `/auth/callback`
//       land on the same host as the cookie was set on; the helper's
//       bare-/verify rewrite is what stops the 404 on the verify link).
// Does NOT: Test prod-shape behaviors (rate limits, deliverability) —
//           that's a manual / canary concern.

import { expect, test, type Page } from '@playwright/test';

import {
  extractMagicLink,
  fetchEmailBody,
  waitForLatestEmail,
} from './helpers/inbucket';

test.describe('forgot-password', () => {
  test('email arrives → reset link sets new password → sign-in works', async ({
    page,
  }) => {
    const email = `reset-${Date.now()}@test.local`;
    const oldPassword = 'OldPassword1!';
    const newPassword = 'NewPassword1!';

    // Seed: sign up so the account exists. Projects with a service-role
    // admin client may prefer to seed via `admin.createUser` for speed.
    await page.goto('/sign-up');
    await fillControlled(page, '#email', email);
    await fillControlled(page, '#password', oldPassword);
    await page.getByRole('button', { name: /sign up/i }).click();
    const seedEmail = await waitForLatestEmail(email);
    const seedLink = extractMagicLink(
      await fetchEmailBody(email, seedEmail.id)
    );
    await page.goto(seedLink);

    // Request a recovery email.
    await page.goto('/sign-in');
    await page.getByRole('link', { name: /forgot password/i }).click();
    await fillControlled(page, '#email', email);
    await page.getByRole('button', { name: /reset|send/i }).click();

    // Follow the recovery link.
    const resetSummary = await waitForLatestEmail(email, { minCount: 2 });
    const resetLink = extractMagicLink(
      await fetchEmailBody(email, resetSummary.id)
    );
    await page.goto(resetLink);

    // Set the new password on the project's reset-password page.
    await fillControlled(page, '#password', newPassword);
    await page.getByRole('button', { name: /update|save/i }).click();

    // Verify sign-in with the new password.
    await page.goto('/sign-in');
    await fillControlled(page, '#email', email);
    await fillControlled(page, '#password', newPassword);
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/(home|$)/);
  });
});

/**
 * WebKit controlled-input fill — `pressSequentially` gives React time
 * to settle the controlled-input value attribute. Plain `fill()` resolves
 * before React syncs the DOM value and the form submits empty fields on
 * WebKit. Locator-by-selector keeps the helper short; projects can swap
 * in role-based locators.
 */
async function fillControlled(page: Page, selector: string, value: string) {
  const locator = page.locator(selector);
  await locator.click();
  await locator.pressSequentially(value, { delay: 10 });
  await expect(locator).toHaveValue(value);
}
