"use client";
import { useActionState } from "react";
import { updateDisplayName, type NameState } from "@/app/(app)/actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function DisplayNameForm({ initial }: { initial: string }) {
  const [state, action, pending] = useActionState<NameState, FormData>(updateDisplayName, { status: "idle" });
  return (
    <form action={action} className="flex flex-col gap-2">
      <div className="flex items-end gap-2">
        <label className="flex flex-1 flex-col gap-1"><MicroLabel>Display name</MicroLabel>
          <input name="display_name" defaultValue={initial} maxLength={80} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 focus:border-accent focus:outline-none" /></label>
        <PrimaryButton type="submit" disabled={pending}>{pending ? "Saving…" : "Save"}</PrimaryButton>
      </div>
      {state.status === "saved" && <p role="status" className="text-sm text-ink">Saved.</p>}
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
    </form>
  );
}
