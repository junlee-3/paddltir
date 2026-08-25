"use client";
import { updateDisplayName } from "@/app/(app)/actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function DisplayNameForm({ initial }: { initial: string }) {
  return (
    <form action={updateDisplayName} className="flex items-end gap-2">
      <label className="flex flex-1 flex-col gap-1"><MicroLabel>Display name</MicroLabel>
        <input name="display_name" defaultValue={initial} maxLength={80} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 focus:border-accent focus:outline-none" /></label>
      <PrimaryButton type="submit">Save</PrimaryButton>
    </form>
  );
}
