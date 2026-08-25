import { describe, expect, it } from "vitest";
import { formatSessionDate, formatSessionTime, relativeDay, startOfTodayISO } from "./time";

const iso = "2026-09-04T08:00:00+10:00"; // Fri 4 Sep 2026, 08:00 Sydney

describe("time (club time zone = Australia/Sydney)", () => {
  it("formats date and time", () => {
    expect(formatSessionDate(iso)).toBe("Fri 4 Sep");
    expect(formatSessionTime(iso)).toBe("8:00 am");
  });
  it("relative day labels", () => {
    expect(relativeDay(iso, "2026-09-04T01:00:00+10:00")).toBe("Today");
    expect(relativeDay(iso, "2026-09-03T23:00:00+10:00")).toBe("Tomorrow");
    expect(relativeDay(iso, "2026-08-26T09:00:00+10:00")).toBe("In 9 days");
  });
  it("relative day around Sydney midnight", () => {
    expect(relativeDay("2026-09-05T00:10:00+10:00", "2026-09-04T23:59:00+10:00")).toBe("Tomorrow");
  });
  it("relative day across the DST switch", () => {
    expect(relativeDay("2026-10-04T06:00:00+11:00", "2026-10-03T23:30:00+10:00")).toBe("Tomorrow");
  });
});

describe("startOfTodayISO", () => {
  it("returns midnight of now's calendar day in Sydney", () => {
    expect(Date.parse(startOfTodayISO("2026-09-04T23:30:00+10:00"))).toBe(Date.parse("2026-09-04T00:00:00+10:00"));
  });
  it("resolves the exact local midnight on the DST-start day (offset is still +10 at 00:00)", () => {
    expect(Date.parse(startOfTodayISO("2026-10-04T06:00:00+11:00"))).toBe(Date.parse("2026-10-04T00:00:00+10:00"));
    expect(Date.parse(startOfTodayISO("2026-10-04T06:00:00+11:00"))).toBe(Date.parse("2026-10-03T14:00:00Z"));
  });
  it("resolves the exact local midnight on the DST-end day (offset is still +11 at 00:00)", () => {
    expect(Date.parse(startOfTodayISO("2027-04-04T12:00:00+10:00"))).toBe(Date.parse("2027-04-04T00:00:00+11:00"));
    expect(Date.parse(startOfTodayISO("2027-04-04T12:00:00+10:00"))).toBe(Date.parse("2027-04-03T13:00:00Z"));
  });
  it("handles a UTC instant that's already tomorrow in Sydney", () => {
    expect(Date.parse(startOfTodayISO("2026-09-04T13:59:00Z"))).toBe(Date.parse("2026-09-04T00:00:00+10:00"));
  });
});
