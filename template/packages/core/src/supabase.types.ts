// What: Generated TypeScript types for the project's Supabase schema
// Why: Keeps client queries type-safe against the live schema. Regenerated via
//      `supabase gen types typescript --project-id <ref>` after every migration.
// Does NOT: Hand-author types — overwritten by the generator. Add helper types
//           in a separate file (e.g. src/models/index.ts) if needed.

/**
 * Placeholder Database type. Replace by running:
 *   supabase gen types typescript --project-id <ref> > supabase.types.ts
 * after the first migration lands. CI's slow-job script `ci-type-drift.sh`
 * (added in /ak-new-project Phase B) blocks merges that drift from the live
 * schema.
 */
export type Database = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
