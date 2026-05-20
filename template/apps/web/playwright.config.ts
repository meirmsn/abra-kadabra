// What: Playwright config for apps/web E2Es — boots `pnpm dev` via the
//       `webServer` block so `pnpm test:e2e` runs end-to-end without
//       requiring an out-of-band dev server. Runs at mobile (375px) and
//       desktop (1440px) per the Responsive + Theme convention.
// Why: Home-os PR #15 hit the missing-webServer trap — Gate 9 `/qa`
//       couldn't run locally without the operator managing a dev server
//       in another shell. Including the block here closes that friction
//       and makes a fresh `pnpm test:e2e` self-contained.
// Does NOT: Configure WebKit project — many devshop containers don't ship
//           WebKit binaries by default. Projects that need WebKit coverage
//           add it explicitly + ensure `playwright install webkit` runs
//           in their CI bootstrap.

import { defineConfig, devices } from '@playwright/test';

const PORT = Number(process.env.PORT ?? 3000);
const BASE_URL = process.env.E2E_BASE_URL ?? `http://127.0.0.1:${PORT}`;

export default defineConfig({
  testDir: './e2e',
  testIgnore: ['**/helpers/**'],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
  ],
  webServer: {
    command: 'pnpm dev',
    port: PORT,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
