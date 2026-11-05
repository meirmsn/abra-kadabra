import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
export default function Home() {
  return (
    <main className="mx-auto max-w-[var(--page-max)] p-4 md:p-8">
      <h1 className="text-2xl font-semibold">Home</h1>
      <p className="text-muted-foreground">A page on the baseline tokens.</p>
      <div className="mt-4 flex gap-2">
        <Button>Save</Button>
        <Button variant="destructive">Delete</Button>
        <Dialog>
          <DialogTrigger asChild><Button variant="outline">Open</Button></DialogTrigger>
          <DialogContent><DialogTitle>Dialog</DialogTitle></DialogContent>
        </Dialog>
      </div>
    </main>
  );
}
