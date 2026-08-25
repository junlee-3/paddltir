import { sectionOf, type Section } from "./boat";

export type Named = { id: string; name: string };
export type Side = "left" | "right";
export type SeatRef = { bench: number; side: Side };
export type SeatView = SeatRef & { paddler: Named | null };
export type HeatView = { id: string; name: string; drummer: Named | null; sweep: Named | null; seats: SeatView[]; reserves: Named[] };

export type Placement =
  | { kind: "seat"; bench: number; side: Side }
  | { kind: "drummer" } | { kind: "sweep" } | { kind: "reserve" } | { kind: "none" };

export function whereAmI(heat: HeatView, paddlerId: string): Placement {
  const seat = heat.seats.find((s) => s.paddler?.id === paddlerId);
  if (seat) return { kind: "seat", bench: seat.bench, side: seat.side };
  if (heat.drummer?.id === paddlerId) return { kind: "drummer" };
  if (heat.sweep?.id === paddlerId) return { kind: "sweep" };
  if (heat.reserves.some((r) => r.id === paddlerId)) return { kind: "reserve" };
  return { kind: "none" };
}

export type BenchRow = { bench: number; section: Section; left: Named | null; right: Named | null };

/** Bow (bench 1) to stern; every bench present even when empty. */
export function benchRows(benches: number, seats: SeatView[]): BenchRow[] {
  const at = (bench: number, side: Side) => seats.find((s) => s.bench === bench && s.side === side)?.paddler ?? null;
  return Array.from({ length: benches }, (_, i) => {
    const bench = i + 1;
    return { bench, section: sectionOf(benches, bench), left: at(bench, "left"), right: at(bench, "right") };
  });
}

export function describePlacement(p: Placement): string {
  switch (p.kind) {
    case "seat": return `Bench ${p.bench} ${p.side}`;
    case "drummer": return "Drummer";
    case "sweep": return "Sweep";
    case "reserve": return "Reserve";
    case "none": return "Not in this heat";
  }
}
