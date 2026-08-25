/** v1 assumption: one club, one time zone. Rendered identically on server and client, so no hydration drift. */
export const CLUB_TZ = "Australia/Sydney";
// en-US parts are reassembled by hand so the output is ICU-version-independent ("Sep", never "Sept").
const date = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, weekday: "short", day: "numeric", month: "short" });
const time = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, hour: "numeric", minute: "2-digit", hour12: true });
const ymd = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" });

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

export function relativeDay(iso: string, nowISO: string): string {
  const days = Math.round((Date.parse(ymd.format(new Date(iso))) - Date.parse(ymd.format(new Date(nowISO)))) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days < 0) return `${-days} day${days === -1 ? "" : "s"} ago`;
  return `In ${days} days`;
}
