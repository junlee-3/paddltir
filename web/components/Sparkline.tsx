import { polylinePoints } from "@/lib/sparkline";

export function Sparkline({ values, label }: { values: number[]; label: string }) {
  const points = polylinePoints(values, 160, 40);
  if (!points) return <p className="text-sm text-ink3">Log two tests to see a trend.</p>;
  return (
    <svg viewBox="0 0 160 40" width="100%" height="40" role="img" aria-label={label} className="overflow-visible">
      <polyline points={points} fill="none" stroke="var(--color-accent)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}
