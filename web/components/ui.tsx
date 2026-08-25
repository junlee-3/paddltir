import type { ComponentProps, ReactNode } from "react";

export function MicroLabel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`micro ${className}`}>{children}</span>;
}

export function Card({ children, className = "", ...rest }: ComponentProps<"section">) {
  return (
    <section className={`rounded-card border border-border bg-surface ${className}`} {...rest}>
      {children}
    </section>
  );
}

export function PrimaryButton({ children, className = "", ...rest }: ComponentProps<"button">) {
  return (
    <button
      className={`min-h-touch rounded-ctl bg-primary px-5 font-semibold text-on-primary disabled:opacity-50 ${className}`}
      {...rest}
    >
      {children}
    </button>
  );
}

export type PillTone = "neutral" | "accent" | "good" | "danger";
const pillTone: Record<PillTone, string> = {
  neutral: "border-border bg-surface2 text-ink2",
  accent: "border-accent/30 bg-accent/10 text-accent",
  good: "border-good/30 bg-good/10 text-good",
  danger: "border-danger/30 bg-danger/10 text-danger",
};
export function Pill({ children, tone = "neutral" }: { children: ReactNode; tone?: PillTone }) {
  return (
    <span className={`inline-flex items-center rounded-sm border px-2 py-0.5 text-xs font-semibold ${pillTone[tone]}`}>
      {children}
    </span>
  );
}

/** Radio-group semantics: one option is `aria-checked`; each target is ≥ 44px tall. */
export function SegmentedControl<T extends string>({
  options, value, onChange, label, disabled = false,
}: { options: { value: T; label: string; tone?: PillTone }[]; value: T | null; onChange: (v: T) => void; label: string; disabled?: boolean }) {
  return (
    <div role="radiogroup" aria-label={label} className="flex rounded-ctl border border-border bg-surface p-1">
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={selected}
            disabled={disabled}
            onClick={() => onChange(o.value)}
            className={`min-h-touch flex-1 rounded-sm text-sm font-semibold transition-colors ${
              selected ? "bg-primary text-on-primary" : "text-ink2 hover:bg-surface2"
            } disabled:opacity-50`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
