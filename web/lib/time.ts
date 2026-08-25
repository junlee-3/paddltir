/** v1 assumption: one club, one time zone. Rendered identically on server and client, so no hydration drift. */
export const CLUB_TZ = "Australia/Sydney";
// en-US parts are reassembled by hand so the output is ICU-version-independent ("Sep", never "Sept").
const date = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, weekday: "short", day: "numeric", month: "short" });
const time = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, hour: "numeric", minute: "2-digit", hour12: true });
const ymd = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" });
// hourCycle "h23" pins the format to 0-23 (some ICU builds render midnight as "24" under hour12:false).
const zonedClock = new Intl.DateTimeFormat("en-CA", {
  timeZone: CLUB_TZ, hourCycle: "h23",
  year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
});

const part = (parts: Intl.DateTimeFormatPart[], type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? "";

/** "Fri 4 Sep" — Australian day-month order. */
export function formatSessionDate(iso: string): string {
  const p = date.formatToParts(new Date(iso));
  return `${part(p, "weekday")} ${part(p, "day")} ${part(p, "month")}`;
}
/** "8:00 am" */
export function formatSessionTime(iso: string): string {
  const p = time.formatToParts(new Date(iso));
  return `${part(p, "hour")}:${part(p, "minute")} ${part(p, "dayPeriod").toLowerCase()}`;
}

/**
 * Midnight of `now`'s calendar day in CLUB_TZ, as an ISO instant — used to keep "today's"
 * event in an upcoming-sessions query for its whole calendar day, not just until it starts.
 * There's no direct way to build a zoned instant from Intl parts, so this searches every UTC
 * hour offset in range and keeps the one whose CLUB_TZ wall clock reads back `${day} 00:00` —
 * correct on both DST transition days, since it resolves whichever offset is actually in
 * effect at that exact local instant rather than assuming one for the whole calendar day.
 */
export function startOfTodayISO(nowISO: string): string {
  const day = ymd.format(new Date(nowISO)); // "YYYY-MM-DD" in CLUB_TZ
  const [y, m, d] = day.split("-").map(Number);
  for (let h = -14; h <= 14; h++) {
    const candidate = new Date(Date.UTC(y, m - 1, d, h, 0, 0));
    const p = zonedClock.formatToParts(candidate);
    const zonedDay = `${part(p, "year")}-${part(p, "month")}-${part(p, "day")}`;
    if (zonedDay === day && part(p, "hour") === "00" && part(p, "minute") === "00") {
      return candidate.toISOString();
    }
  }
  throw new Error(`startOfTodayISO: could not resolve midnight for ${nowISO}`);
}

export function relativeDay(iso: string, nowISO: string): string {
  const days = Math.round((Date.parse(ymd.format(new Date(iso))) - Date.parse(ymd.format(new Date(nowISO)))) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days < 0) return `${-days} day${days === -1 ? "" : "s"} ago`;
  return `In ${days} days`;
}
