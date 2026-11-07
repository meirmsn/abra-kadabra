import { Button } from '@/components/ui/button';
export default function Home() {
  return (
    <main className="mx-auto max-w-[var(--page-max)] p-4 md:p-8">
      <h1 className="text-2xl font-semibold">Spike</h1>
      <p className="text-muted-foreground dark:text-foreground">A page on the baseline tokens.</p>
      <div className="mt-4 flex gap-2">
        <Button>Save</Button>
        <Button variant="outline">Cancel</Button>
        <Button variant="outline" data-theme-toggle suppressHydrationWarning>Theme: system</Button>
      </div>
    </main>
  );
}
