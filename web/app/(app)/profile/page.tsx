import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { Card, MicroLabel } from "@/components/ui";
import { DisplayNameForm } from "./DisplayNameForm";
import { assertNoQueryError } from "@/lib/data/queryError";

export const metadata: Metadata = { title: "Profile" };

const SIDE: Record<string, string> = { left: "Left", right: "Right", either: "Either" };
const PREF: Record<string, string> = { stroke: "Stroke", pace: "Pace", engine: "Engine", sprint: "Sprint", none: "No preference" };
const ROLE: Record<string, string> = { paddler: "Paddler", drummer: "Drummer", sweep: "Sweep" };

export default async function ProfilePage() {
  const viewer = await getViewer();
  const p = viewer.paddler!;
  const supabase = await createClient();
  const { data: club, error: clubError } = await supabase.from("clubs").select("name").eq("id", p.club_id).maybeSingle();
  assertNoQueryError("club", clubError);
  const rows: [string, string][] = [
    ["Name", p.name], ["Weight", `${Number(p.weight_kg).toFixed(1)} kg`], ["Gender", p.gender === "female" ? "Female" : "Male"],
    ["Preferred side", SIDE[p.preferred_side]], ["Seat preference", PREF[p.seat_preference]], ["Role", ROLE[p.boat_role]],
  ];
  return (
    <main className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Profile</h1>
      <Card className="p-4"><MicroLabel>{club?.name ?? "Your club"}</MicroLabel><div className="mt-3"><DisplayNameForm initial={viewer.profile?.display_name ?? p.name} /></div>
        <p className="mt-2 text-sm text-ink3">Signed in as {viewer.user?.email}</p></Card>
      <Card>
        <dl className="divide-y divide-border">
          {rows.map(([k, v]) => (<div key={k} className="flex min-h-touch items-center justify-between px-4 py-2"><dt className="text-sm text-ink2">{k}</dt><dd className="font-semibold">{v}</dd></div>))}
        </dl>
        <p className="border-t border-border px-4 py-3 text-sm text-ink3">Ask your coach to change these — they&apos;re managed from the coach app.</p>
      </Card>
      <form action="/auth/signout" method="post"><button type="submit" className="min-h-touch w-full rounded-ctl border border-border bg-surface font-semibold text-danger">Sign out</button></form>
    </main>
  );
}
