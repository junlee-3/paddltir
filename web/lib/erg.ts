export type ErgSubmission = { ok: true; metres: number; testedAt: string } | { ok: false; message: string };
const YMD = /^\d{4}-\d{2}-\d{2}$/;
// Decimal digits only — Number() would otherwise happily coerce "1e3" or "0x10" into an integer.
const METRES_RE = /^\d+$/;

/** A real (non-overflowing) calendar date — "2026-02-30" round-trips through Date.UTC as March 2. */
function isRealCalendarDate(y: number, m: number, d: number): boolean {
  const check = new Date(Date.UTC(y, m - 1, d));
  return check.getUTCFullYear() === y && check.getUTCMonth() === m - 1 && check.getUTCDate() === d;
}

/** Mirrors the DB checks: metres integer 1–2000; tested_at a real date, today or earlier (club time zone). */
export function parseErgSubmission(input: { metres: string; testedAt: string }, todayYMD: string): ErgSubmission {
  if (!METRES_RE.test(input.metres)) return { ok: false, message: "Metres must be a whole number from 1 to 2000." };
  const metres = Number(input.metres);
  if (metres < 1 || metres > 2000) return { ok: false, message: "Metres must be a whole number from 1 to 2000." };
  if (!YMD.test(input.testedAt)) return { ok: false, message: "Pick the date of the test." };
  const [y, m, d] = input.testedAt.split("-").map(Number);
  if (!isRealCalendarDate(y, m, d)) return { ok: false, message: "Pick the date of the test." };
  if (input.testedAt > todayYMD) return { ok: false, message: "That date is in the future." };
  return { ok: true, metres, testedAt: input.testedAt };
}
