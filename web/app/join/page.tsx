import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getViewer } from "@/lib/data/viewer";
import { gateFor } from "@/lib/auth/gate";
import { Card, MicroLabel } from "@/components/ui";
import { JoinForm } from "./JoinForm";

export const metadata: Metadata = { title: "Join your club" };

export default async function JoinPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  const viewer = await getViewer();
  const gate = gateFor(viewer);
  if (gate === "/login") redirect("/login?next=%2Fjoin");
  if (gate === null) redirect("/");
  const hasClubNoPaddler = Boolean(viewer.profile?.club_id) && !viewer.paddler;
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <header>
        <p className="text-3xl font-extrabold tracking-[-0.02em]">Join your club</p>
        <p className="mt-1 text-ink2">Signed in as {viewer.user?.email}.</p>
      </header>
      {hasClubNoPaddler && (
        <Card className="p-5">
          <MicroLabel>Not on the squad yet</MicroLabel>
          <p className="mt-2 text-ink2">You&apos;re in the club but not linked to a paddler. Enter the invite code again to claim your name, or ask your coach to add you to the squad.</p>
        </Card>
      )}
      <Card className="p-5">
        <JoinForm />
        {error && <p role="alert" className="mt-3 text-sm text-danger">{decodeURIComponent(error)}</p>}
      </Card>
      <form action="/auth/signout" method="post"><button type="submit" className="min-h-touch text-ink2 underline">Sign out</button></form>
    </main>
  );
}
