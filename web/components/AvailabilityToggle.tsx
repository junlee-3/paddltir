"use client";
import { useState, useTransition } from "react";
import { setAvailability } from "@/app/(app)/actions";
import type { AvailabilityStatus } from "@/lib/event";
import { SegmentedControl } from "./ui";

const OPTIONS = [{ value: "in", label: "In" }, { value: "maybe", label: "Maybe" }, { value: "out", label: "Out" }] as const;

/**
 * `useState(value)` only seeds the initial render — a later server value (e.g. a coach-side
 * change re-rendered by `router.refresh()`) is silently ignored unless the caller remounts
 * this component. Callers MUST pass `key={`${sessionId}:${value ?? "none"}`}` so a changed
 * server value forces a fresh mount (optimistic updates still work fine between refreshes,
 * since they only touch this instance's own state).
 */
export function AvailabilityToggle({ sessionId, value, label }: { sessionId: string; value: AvailabilityStatus | null; label: string }) {
  const [current, setCurrent] = useState(value);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <div>
      <SegmentedControl label={label} options={[...OPTIONS]} value={current} disabled={pending}
        onChange={(next) => { const prev = current; setCurrent(next); setError(null);
          start(async () => { const r = await setAvailability(sessionId, next); if (!r.ok) { setCurrent(prev); setError(r.message); } }); }} />
      {error && <p role="alert" className="mt-2 text-sm text-danger">{error}</p>}
    </div>
  );
}
