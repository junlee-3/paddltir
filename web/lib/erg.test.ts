import { describe, expect, it } from "vitest";
import { parseErgSubmission } from "./erg";

describe("parseErgSubmission", () => {
  it("accepts whole metres 1–2000 and a date not in the future", () => {
    expect(parseErgSubmission({ metres: "545", testedAt: "2026-08-25" }, "2026-08-26")).toEqual({ ok: true, metres: 545, testedAt: "2026-08-25" });
    expect(parseErgSubmission({ metres: "2000", testedAt: "2026-08-26" }, "2026-08-26")).toEqual({ ok: true, metres: 2000, testedAt: "2026-08-26" });
  });
  it("rejects out-of-range, non-integer, empty, future", () => {
    expect(parseErgSubmission({ metres: "0", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "2001", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "12.5", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "500", testedAt: "2026-08-27" }, "2026-08-26")).toMatchObject({ ok: false, message: expect.stringContaining("future") });
    expect(parseErgSubmission({ metres: "500", testedAt: "not-a-date" }, "2026-08-26")).toMatchObject({ ok: false });
  });
  it("rejects non-decimal-digit metres notation (1e3, 0x…) even when Number() would coerce it", () => {
    expect(parseErgSubmission({ metres: "1e3", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "0x10", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
  });
  it("rejects a date that isn't a real calendar date", () => {
    expect(parseErgSubmission({ metres: "500", testedAt: "2026-02-30" }, "2026-08-26")).toMatchObject({ ok: false });
  });
});
