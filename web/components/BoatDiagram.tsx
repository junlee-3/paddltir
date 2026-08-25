import { benchRows, type HeatView, type Named } from "@/lib/lineup";
import { MicroLabel } from "@/components/ui";

function Tile({ p, me, label }: { p: Named | null; me: string; label: string }) {
  const mine = p?.id === me;
  return (
    <div
      role="cell"
      aria-label={`${label}: ${p ? p.name : "empty"}${mine ? " (you)" : ""}`}
      className={`flex min-h-touch items-center justify-center rounded-sm border px-2 text-center text-sm leading-tight ${
        p ? (mine ? "border-accent bg-accent/10 font-semibold text-accent" : "border-border bg-surface text-ink") : "border-dashed border-border bg-surface2 text-ink3"
      }`}
    >
      {p ? p.name : "—"}
    </div>
  );
}

export function BoatDiagram({ heat, benches, me }: { heat: HeatView; benches: number; me: string }) {
  const rows = benchRows(benches, heat.seats);
  return (
    <>
      <div role="table" aria-label={`${heat.name} lineup, bow to stern`} className="flex flex-col gap-1.5">
        <div role="row" className="grid grid-cols-[1fr_auto_1fr] items-center gap-2"><div aria-hidden /><Tile p={heat.drummer} me={me} label="Drummer" /><div aria-hidden /></div>
        {rows.map((r) => (
          <div key={r.bench} role="row" className="grid grid-cols-[1fr_4rem_1fr] items-center gap-2">
            <Tile p={r.left} me={me} label={`Bench ${r.bench} left`} />
            <div role="cell" className="flex flex-col items-center gap-0.5">
              <span className="text-xs font-bold text-ink3">{r.bench}</span>
              <MicroLabel>{r.section}</MicroLabel>
            </div>
            <Tile p={r.right} me={me} label={`Bench ${r.bench} right`} />
          </div>
        ))}
        <div role="row" className="grid grid-cols-[1fr_auto_1fr] items-center gap-2"><div aria-hidden /><Tile p={heat.sweep} me={me} label="Sweep" /><div aria-hidden /></div>
      </div>
      {heat.reserves.length > 0 && (
        <p className="mt-2 text-sm text-ink2"><span className="micro mr-2">Reserves</span>{heat.reserves.map((r) => r.name).join(" · ")}</p>
      )}
    </>
  );
}
