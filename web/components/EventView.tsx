import type { EventView as Event } from "@/lib/event";
import { formatSessionDate, formatSessionTime, relativeDay } from "@/lib/time";
import { Card, MicroLabel } from "./ui";
import { RaceCard } from "./RaceCard";
import { AvailabilityToggle } from "./AvailabilityToggle";

export function EventView({ event, me, nowISO }: { event: Event; me: string; nowISO: string }) {
  return (
    <div className="flex flex-col gap-4">
      <header>
        <MicroLabel>{relativeDay(event.startsAt, nowISO)} · {formatSessionDate(event.startsAt)} · {formatSessionTime(event.startsAt)}</MicroLabel>
        <h1 className="mt-1 text-2xl font-extrabold tracking-[-0.02em]">{event.title}</h1>
        {event.venue && <p className="text-ink2">{event.venue}</p>}
      </header>
      {event.kind === "training" ? (
        <Card className="p-4">
          <MicroLabel>Are you in?</MicroLabel>
          <div className="mt-3"><AvailabilityToggle key={`${event.id}:${event.myAvailability ?? "none"}`} sessionId={event.id} value={event.myAvailability} label={`Availability for ${event.title}`} /></div>
          {event.myNote && <p className="mt-2 text-sm text-ink2">Note: {event.myNote}</p>}
        </Card>
      ) : event.races.length === 0 ? (
        <Card className="p-4"><p className="text-ink2">No races entered yet.</p></Card>
      ) : (
        event.races.map((r) => <RaceCard key={r.id} race={r} me={me} />)
      )}
    </div>
  );
}
