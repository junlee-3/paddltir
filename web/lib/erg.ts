export type ErgSubmission = { ok: true; metres: number; testedAt: string } | { ok: false; message: string };
const YMD = /^\d{4}-\d{2}-\d{2}$/;

/** Mirrors the DB checks: metres integer 1–2000; tested_at a real date, today or earlier (club time zone). */
export function parseErgSubmission(input: { metres: string; testedAt: string }, todayYMD: string): ErgSubmission {
  const metres = Number(input.metres);
  if (input.metres.trim() === "" || !Number.isInteger(metres) || metres < 1 || metres > 2000) return { ok: false, message: "Metres must be a whole number from 1 to 2000." };
  if (!YMD.test(input.testedAt) || Number.isNaN(Date.parse(input.testedAt))) return { ok: false, message: "Pick the date of the test." };
  if (input.testedAt > todayYMD) return { ok: false, message: "That date is in the future." };
  return { ok: true, metres, testedAt: input.testedAt };
}
