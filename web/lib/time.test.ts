import { describe, expect, it } from "vitest";
import { formatSessionDate, formatSessionTime, relativeDay } from "./time";

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
});
