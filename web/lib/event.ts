import { BENCHES, type BoatSize } from "./boat";
import type { HeatView, Named, Side } from "./lineup";

/** Shape returned by the PostgREST embed in data/sessions.ts (kept explicit so the mapper is unit-testable). */
export type RaceRow = {
  id: string; name: string; boat_size: BoatSize; sort_order: number;
  crews: { name: string } | null;
  heats: {
    id: string; name: string; sort_order: number; drummer_id: string | null; sweep_id: string | null;
    seats: { bench: number; side: Side; paddler_id: string }[];
    heat_reserves: { paddler_id: string }[];
  }[];
};

export type RaceView = { id: string; name: string; crewName: string; boatSize: BoatSize; benches: number; heats: HeatView[] };
export type AvailabilityStatus = "in" | "out" | "maybe";
export type EventView =
  | { id: string; kind: "race_day"; title: string; startsAt: string; venue: string | null; races: RaceView[] }
  | { id: string; kind: "training"; title: string; startsAt: string; venue: string | null; myAvailability: AvailabilityStatus | null; myNote: string | null };

export function paddlerIds(rows: RaceRow[]): Set<string> {
  const ids = new Set<string>();
  for (const r of rows) for (const h of r.heats) {
    if (h.drummer_id) ids.add(h.drummer_id);
    if (h.sweep_id) ids.add(h.sweep_id);
    h.seats.forEach((s) => ids.add(s.paddler_id));
    h.heat_reserves.forEach((x) => ids.add(x.paddler_id));
  }
  return ids;
}

export function toRaceViews(rows: RaceRow[], names: Map<string, string>): RaceView[] {
  const named = (id: string | null): Named | null => (id ? { id, name: names.get(id) ?? "Unknown" } : null);
  return [...rows].sort((a, b) => a.sort_order - b.sort_order).map((r) => ({
    id: r.id, name: r.name, crewName: r.crews?.name ?? "Crew", boatSize: r.boat_size, benches: BENCHES[r.boat_size],
    heats: [...r.heats].sort((a, b) => a.sort_order - b.sort_order).map((h) => ({
      id: h.id, name: h.name, drummer: named(h.drummer_id), sweep: named(h.sweep_id),
      seats: h.seats.map((s) => ({ bench: s.bench, side: s.side, paddler: named(s.paddler_id) })),
      reserves: h.heat_reserves.map((x) => named(x.paddler_id)!),
    })),
  }));
}
