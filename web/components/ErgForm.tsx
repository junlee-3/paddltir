"use client";
import { useActionState } from "react";
import { submitErg, type ErgState } from "@/app/(app)/actions";
import { MicroLabel, PrimaryButton } from "./ui";

export function ErgForm({ today }: { today: string }) {
  const [state, action, pending] = useActionState<ErgState, FormData>(submitErg, { status: "idle" });
  return (
    <form action={action} className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3">
        <label className="flex flex-col gap-1"><MicroLabel>Metres (1 min)</MicroLabel>
          <input name="metres" type="number" inputMode="numeric" min={1} max={2000} step={1} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 text-lg font-semibold focus:border-accent focus:outline-none" /></label>
        <label className="flex flex-col gap-1"><MicroLabel>Date</MicroLabel>
          <input name="tested_at" type="date" max={today} defaultValue={today} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 focus:border-accent focus:outline-none" /></label>
      </div>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      {state.status === "saved" && <p role="status" className="text-sm text-good">Saved {state.metres} m.</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Saving…" : "Log erg test"}</PrimaryButton>
    </form>
  );
}
