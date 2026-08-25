"use client";
import { ErrorState } from "@/components/ErrorState";

/** Root-level boundary: error.js does not wrap the layout.js in its own segment, so this is what
 *  actually catches failures thrown inside app/(app)/layout.tsx's getViewer() call (and any other
 *  nested layout). app/(app)/error.tsx and app/join/error.tsx still cover their own page-level throws. */
export default function Error({
  error,
  reset,
  retry,
}: {
  error: Error & { digest?: string };
  reset: () => void;
  retry?: () => void;
}) {
  return <ErrorState error={error} reset={reset} retry={retry} />;
}
