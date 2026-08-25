"use client";
import { useActionState } from "react";
import { sendMagicLink, type LoginState } from "./actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function LoginForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<LoginState, FormData>(sendMagicLink, { status: "idle" });
  if (state.status === "sent") {
    return (
      <div role="status">
        <MicroLabel>Check your email</MicroLabel>
        <p className="mt-2">We sent a sign-in link to <span className="font-semibold">{state.email}</span>. Open it on this device.</p>
      </div>
    );
  }
  return (
    <form action={action} className="flex flex-col gap-3">
      <input type="hidden" name="next" value={next} />
      <label className="flex flex-col gap-1">
        <MicroLabel>Email</MicroLabel>
        <input name="email" type="email" inputMode="email" autoComplete="email" required placeholder="you@club.com"
          className="min-h-touch rounded-ctl border border-border bg-surface px-3 text-ink placeholder:text-ink3 focus:border-accent focus:outline-none" />
      </label>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Sending…" : "Email me a sign-in link"}</PrimaryButton>
    </form>
  );
}
