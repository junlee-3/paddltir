"use client";
import { useActionState } from "react";
import { joinClub, lookupInvite, type JoinState } from "./actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function JoinForm() {
  const [state, action, pending] = useActionState<JoinState, FormData>(lookupInvite, { status: "idle" });
  if (state.status === "choose") {
    return (
      <form action={joinClub} className="flex flex-col gap-3">
        <input type="hidden" name="code" value={state.code} />
        <MicroLabel>Which one is you?</MicroLabel>
        {state.candidates.length === 0 && <p className="text-ink2">No unclaimed names match this code. Join anyway — if your coach entered your email, you&apos;ll be linked automatically.</p>}
        <div role="radiogroup" aria-label="Your name" className="flex flex-col gap-2">
          {state.candidates.map((c, i) => (
            <label key={c.id} className="flex min-h-touch items-center gap-3 rounded-ctl border border-border bg-surface px-3 has-checked:border-accent">
              <input type="radio" name="paddler_id" value={c.id} defaultChecked={i === 0} className="accent-accent" />
              <span className="font-semibold">{c.name}</span>
            </label>
          ))}
          <label className="flex min-h-touch items-center gap-3 rounded-ctl border border-border bg-surface px-3 has-checked:border-accent">
            <input type="radio" name="paddler_id" value="" defaultChecked={state.candidates.length === 0} className="accent-accent" />
            <span className="text-ink2">I&apos;m not listed</span>
          </label>
        </div>
        <PrimaryButton type="submit">Join club</PrimaryButton>
      </form>
    );
  }
  return (
    <form action={action} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1">
        <MicroLabel>Invite code</MicroLabel>
        <input name="code" required autoCapitalize="characters" autoComplete="off" placeholder="DEMO2026"
          className="min-h-touch rounded-ctl border border-border bg-surface px-3 text-lg tracking-widest uppercase placeholder:text-ink3 focus:border-accent focus:outline-none" />
      </label>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Looking up…" : "Continue"}</PrimaryButton>
    </form>
  );
}
