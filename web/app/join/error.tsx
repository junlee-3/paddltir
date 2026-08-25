"use client";
import { ErrorState } from "@/components/ErrorState";

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
