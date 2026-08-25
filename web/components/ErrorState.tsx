"use client";
import { Card, MicroLabel, PrimaryButton } from "@/components/ui";

/** Shared error-boundary UI for route segments (Next 16 error.tsx convention: error + reset). */
export function ErrorState({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <Card className="p-5">
        <MicroLabel>Something went wrong</MicroLabel>
        <p className="mt-2 text-sm text-ink2">{error.message}</p>
        <PrimaryButton type="button" onClick={reset} className="mt-4">Try again</PrimaryButton>
      </Card>
    </main>
  );
}
