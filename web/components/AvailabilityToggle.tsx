"use client";
import { useState, useTransition } from "react";
import { setAvailability } from "@/app/(app)/actions";
import type { AvailabilityStatus } from "@/lib/event";
import { SegmentedControl } from "./ui";

const OPTIONS = [{ value: "in", label: "In" }, { value: "maybe", label: "Maybe" }, { value: "out", label: "Out" }] as const;

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
