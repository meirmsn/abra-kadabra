// What: Setup file Vitest loads before every test run — registers
//       jest-dom matchers (`toBeInTheDocument`, `toHaveTextContent`, etc.)
//       so React component tests can assert on user-visible output per the
//       Test Assertion Depth convention.
// Why: `@testing-library/jest-dom/vitest` import has to fire ONCE per
//       worker; doing it at the top of each test file is repetitive and
//       inviting drift. Project-wide setup keeps every test using the
//       same matcher surface without re-importing.
// Does NOT: Mock fetch / Supabase / clipboard — tests own those locally.

import '@testing-library/jest-dom/vitest';
