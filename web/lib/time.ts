/** v1 assumption: one club, one time zone. Rendered identically on server and client, so no hydration drift. */
export const CLUB_TZ = "Australia/Sydney";
// en-US parts are reassembled by hand so the output is ICU-version-independent ("Sep", never "Sept").
const date = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, weekday: "short", day: "numeric", month: "short" });
const time = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, hour: "numeric", minute: "2-digit", hour12: true });
const ymd = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" });
// hourCycle "h23" pins the format to 0-23 (some ICU builds render midnight as "24" under hour12:false).
const zonedClock = new Intl.DateTimeFormat("en-US", {
  timeZone: CLUB_TZ, hourCycle: "h23",
  year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit",
});

/** CLUB_TZ's UTC offset (minutes, east-positive) in effect at `instant`. */
function clubOffsetMinutes(instant: Date): number {
  const p = zonedClock.formatToParts(instant);
  const n = (t: Intl.DateTimeFormatPartTypes) => Number(part(p, t));
  const asUTC = Date.UTC(n("year"), n("month") - 1, n("day"), n("hour"), n("minute"), n("second"));
  return Math.round((asUTC - instant.getTime()) / 60_000);
}

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
 * Offset is read from CLUB_TZ at that date's UTC midnight (not from a search for the exact
 * local-00:00 instant): on the one Sunday a year DST actually begins, those two differ by an
 * hour — the exact-local-midnight offset is still AEST, but this picks the new AEDT offset
 * that governs the rest of that calendar day. That trades an hour of theoretical precision
 * (which would only matter for a session starting between 11pm and midnight the night before
 * the switch) for a boundary that matches the offset every other session on the page uses.
 */
export function startOfTodayISO(nowISO: string): string {
  const day = ymd.format(new Date(nowISO)); // "YYYY-MM-DD" in CLUB_TZ
  const offset = clubOffsetMinutes(new Date(`${day}T00:00:00Z`));
  const sign = offset >= 0 ? "+" : "-";
  const abs = Math.abs(offset);
  const hh = String(Math.floor(abs / 60)).padStart(2, "0");
  const mm = String(abs % 60).padStart(2, "0");
  return `${day}T00:00:00${sign}${hh}:${mm}`;
}

export function relativeDay(iso: string, nowISO: string): string {
  const days = Math.round((Date.parse(ymd.format(new Date(iso))) - Date.parse(ymd.format(new Date(nowISO)))) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days < 0) return `${-days} day${days === -1 ? "" : "s"} ago`;
  return `In ${days} days`;
}
