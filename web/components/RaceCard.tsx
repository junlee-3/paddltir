"use client";
import { useState } from "react";
import type { RaceView } from "@/lib/event";
import { describePlacement, whereAmI } from "@/lib/lineup";
import { BoatDiagram } from "./BoatDiagram";
import { Card, MicroLabel, Pill } from "./ui";

export function RaceCard({ race, me }: { race: RaceView; me: string }) {
  const [selected, setSelected] = useState<string | null>(race.heats[0]?.id ?? null);
  // If the previously-selected heat no longer exists (e.g. a coach deletes it and this
  // re-renders via realtime refresh), fall back to the first heat instead of showing none.
  const heatId = race.heats.some((h) => h.id === selected) ? selected : race.heats[0]?.id;
  const heat = race.heats.find((h) => h.id === heatId) ?? race.heats[0] ?? null;
  const placement = heat ? whereAmI(heat, me) : null;
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <MicroLabel>{race.crewName}</MicroLabel>
          <h2 className="mt-1 text-lg font-bold tracking-tight">{race.name}</h2>
        </div>
        {placement && <Pill tone={placement.kind === "none" ? "neutral" : "accent"}>{describePlacement(placement)}</Pill>}
      </div>
      {race.heats.length > 1 && (
        <div role="tablist" aria-label="Heats" className="mt-3 flex gap-1 rounded-ctl border border-border bg-surface2 p-1">
          {race.heats.map((h) => (
            <button key={h.id} role="tab" aria-selected={h.id === heatId} onClick={() => setSelected(h.id)}
              className={`min-h-touch flex-1 rounded-sm text-sm font-semibold ${h.id === heatId ? "bg-surface text-ink shadow-sm" : "text-ink2"}`}>
              {h.name}
            </button>
          ))}
        </div>
      )}
      <div className="mt-4">
        {heat ? <BoatDiagram heat={heat} benches={race.benches} me={me} /> : <p className="text-ink2">No heats yet — your coach hasn&apos;t set a lineup.</p>}
      </div>
    </Card>
  );
}
