// What: Root landing page — minimal "hello" shell for a fresh project so
//       `pnpm dev` boots into a recognizable but content-empty page.
// Why: Replaces the create-next-app boilerplate splash; projects override
//       this immediately when they have a real landing surface.
// Does NOT: Load any data or render anything project-specific — that's
//           per-feature work.
//
// File-doc exemption: `page.tsx` is on the test-coverage exempt list per
// `kit/docs/guide/conventions.md § Test Presence` (entry-point).

export default function HomePage() {
  return (
    <main className="page">
      <h1>PROJECT_NAME_PLACEHOLDER</h1>
      <p>A devshop project. Replace this page with your landing surface.</p>
    </main>
  );
}
