import './globals.css';
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        {/* eslint-disable-next-line @next/next/no-sync-scripts -- the theme must be on <html> before the first paint (ui.md) */}
        <script src="/theme.js" />
      </head>
      <body>{children}</body>
    </html>
  );
}
