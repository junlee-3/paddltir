"use client";
import { Card, MicroLabel, PrimaryButton } from "@/components/ui";

/**
 * Shared error-boundary UI for route segments (Next 16 error.tsx convention).
 * "Try again" must call `retry()` — it re-fetches and re-renders the failed
 * Server Component segment. Bare `reset()` only clears the boundary's local
 * error state and re-renders the SAME already-failed RSC payload, so it can
 * never actually recover from a server-side throw (e.g. getViewer()'s
 * transient query-error case). `reset` is kept as a fallback for older type
 * definitions that don't expose `retry`.
 */
export function ErrorState({
  error,
  reset,
  retry,
}: {
  error: Error & { digest?: string };
  reset: () => void;
  retry?: () => void;
}) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <Card className="p-5">
        <MicroLabel>Something went wrong</MicroLabel>
        <p className="mt-2 text-sm text-ink2">{error.message}</p>
        <PrimaryButton type="button" onClick={() => (retry ?? reset)()} className="mt-4">Try again</PrimaryButton>
      </Card>
    </main>
  );
}
