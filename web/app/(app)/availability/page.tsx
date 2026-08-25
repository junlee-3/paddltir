import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { fetchUpcomingSessions } from "@/lib/data/sessions";
import { formatSessionDate, formatSessionTime } from "@/lib/time";
import { AvailabilityToggle } from "@/components/AvailabilityToggle";
import { RealtimeRefresh } from "@/components/RealtimeRefresh";
import { Card, MicroLabel, Pill } from "@/components/ui";
import type { AvailabilityStatus } from "@/lib/event";
import { assertNoQueryError } from "@/lib/data/queryError";

export const metadata: Metadata = { title: "Availability" };

export default async function AvailabilityPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const sessions = await fetchUpcomingSessions(supabase, new Date().toISOString(), 20);
  const { data: mine, error: mineError } = await supabase.from("availability").select("session_id, status").eq("paddler_id", viewer.paddler!.id);
  assertNoQueryError("availability", mineError);
  const status = new Map<string, AvailabilityStatus>((mine ?? []).map((a) => [a.session_id, a.status]));
  return (
    <main className="flex flex-col gap-4">
      <RealtimeRefresh />
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Availability</h1>
      {sessions.length === 0 && <Card className="p-5"><p className="text-ink2">No upcoming sessions.</p></Card>}
      {sessions.map((s) => (
        <Card key={s.id} className="p-4">
          <div className="flex items-start justify-between gap-3">
            <div><MicroLabel>{formatSessionDate(s.startsAt)} · {formatSessionTime(s.startsAt)}</MicroLabel><h2 className="mt-1 font-bold">{s.title}</h2></div>
            <Pill tone={s.kind === "race_day" ? "accent" : "neutral"}>{s.kind === "race_day" ? "Race day" : "Training"}</Pill>
          </div>
          <div className="mt-3"><AvailabilityToggle sessionId={s.id} value={status.get(s.id) ?? null} label={`Availability for ${s.title}`} /></div>
        </Card>
      ))}
    </main>
  );
}
