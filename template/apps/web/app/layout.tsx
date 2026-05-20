// What: Root App Router layout — wraps every route, sets html/body, and
//       provides the document-level theme tokens loaded from globals.css.
// Why: Next.js App Router requires exactly one root layout per app; this
//       one stays minimal so per-feature work doesn't fight font / theme /
//       provider scaffolding.
// Does NOT: Ship per-feature providers (auth, query client, etc.) — those
//           belong in route-group layouts or `app/providers.tsx` if a
//           project introduces them.
//
// File-doc exemption: `layout.tsx` is on the test-coverage exempt list
// per `kit/docs/guide/conventions.md § Test Presence` (entry-point).

import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'PROJECT_NAME_PLACEHOLDER',
  description: 'A devshop project.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
