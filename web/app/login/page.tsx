import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { LoginForm } from "./LoginForm";
import { getViewer } from "@/lib/data/viewer";
import { env } from "@/lib/env";
import { safeNext } from "@/lib/auth/paths";
import { devPasswordSignIn } from "./actions";
import { Card, MicroLabel, PrimaryButton } from "@/components/ui";

export const metadata: Metadata = { title: "Sign in" };

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string; error?: string }> }) {
  const { next, error } = await searchParams;
  const viewer = await getViewer();
  if (viewer.user) redirect(safeNext(next ?? null));
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <header>
        <p className="text-3xl font-extrabold tracking-[-0.02em]">Paddltir</p>
        <p className="mt-1 text-ink2">Your crew, your seat, your next race.</p>
      </header>
      <Card className="p-5">
        <LoginForm next={safeNext(next ?? null)} />
        {error === "link" && <p role="alert" className="mt-3 text-sm text-danger">That link has expired — request a new one.</p>}
      </Card>
      {env.devLogin && (
        <Card className="border-dashed p-5">
          <MicroLabel>Dev sign-in (local stack)</MicroLabel>
          <form action={devPasswordSignIn} className="mt-3 flex flex-col gap-3">
            <input type="hidden" name="next" value={safeNext(next ?? null)} />
            <input name="email" type="email" defaultValue="lily@paddltir.dev" aria-label="Email" className="min-h-touch rounded-ctl border border-border px-3" />
            <input name="password" type="password" defaultValue="password123" aria-label="Password" className="min-h-touch rounded-ctl border border-border px-3" />
            <PrimaryButton type="submit">Sign in with password</PrimaryButton>
          </form>
        </Card>
      )}
    </main>
  );
}
