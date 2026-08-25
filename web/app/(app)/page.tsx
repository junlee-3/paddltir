import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { fetchEvent, fetchUpcomingSessions } from "@/lib/data/sessions";
import { formatSessionDate, formatSessionTime } from "@/lib/time";
import { EventView } from "@/components/EventView";
import { RealtimeRefresh } from "@/components/RealtimeRefresh";
import { Card, MicroLabel, Pill } from "@/components/ui";

export default async function NextEventPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const nowISO = new Date().toISOString();
  const upcoming = await fetchUpcomingSessions(supabase, nowISO);
  const next = upcoming[0] ? await fetchEvent(supabase, upcoming[0].id, viewer.paddler!.id) : null;
  return (
    <main className="flex flex-col gap-6">
      <RealtimeRefresh />
      {next ? <EventView event={next} me={viewer.paddler!.id} nowISO={nowISO} /> : (
        <Card className="p-5"><MicroLabel>Nothing scheduled</MicroLabel><p className="mt-2 text-ink2">No upcoming sessions — check back when your coach adds one.</p></Card>
      )}
      {upcoming.length > 1 && (
        <section>
          <MicroLabel>Coming up</MicroLabel>
          <ul className="mt-2 flex flex-col gap-2">
            {upcoming.slice(1).map((s) => (
              <li key={s.id}>
                <Link href={`/session/${s.id}`} className="flex min-h-touch items-center justify-between rounded-card border border-border bg-surface px-4 py-3">
                  <span><span className="font-semibold">{s.title}</span><span className="block text-sm text-ink2">{formatSessionDate(s.startsAt)} · {formatSessionTime(s.startsAt)}</span></span>
                  <Pill tone={s.kind === "race_day" ? "accent" : "neutral"}>{s.kind === "race_day" ? "Race day" : "Training"}</Pill>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
