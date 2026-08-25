// Mirrors PaddltirCore/Domain/Boat.swift — keep the two in lock-step.
export type BoatSize = "small" | "standard";
export type Section = "stroke" | "pace" | "engine" | "sprint";
export const SECTIONS: readonly Section[] = ["stroke", "pace", "engine", "sprint"];
export const BENCHES: Record<BoatSize, number> = { small: 5, standard: 10 };

/** Inclusive bench range for a section. n < 4 is the degenerate rule from Boat.swift. */
export function benchesIn(benches: number, section: Section): [number, number] {
  const n = benches;
  if (n < 4) {
    switch (section) {
      case "stroke": return [1, 1];
      case "pace": return n >= 2 ? [2, 2] : [1, 1];
      case "engine": return n >= 3 ? [3, 3] : n >= 2 ? [2, 2] : [1, 1];
      case "sprint": return [n, n];
    }
  }
  const sprintCount = Math.max(1, Math.round(n * 0.3));
  const paceCount = Math.max(1, Math.round(n * 0.2));
  const paceEnd = 1 + paceCount;
  const sprintStart = n - sprintCount + 1;
  switch (section) {
    case "stroke": return [1, 1];
    case "pace": return [2, paceEnd];
    case "engine": return [paceEnd + 1, sprintStart - 1];
    case "sprint": return [sprintStart, n];
  }
}

export function sectionOf(benches: number, bench: number): Section {
  for (const s of SECTIONS) {
    const [lo, hi] = benchesIn(benches, s);
    if (bench >= lo && bench <= hi) return s;
  }
  return "engine";
}
