import { describe, expect, it } from "vitest";
import { benchRows, whereAmI, type HeatView } from "./lineup";

const heat: HeatView = {
  id: "h1", name: "Heat 1",
  drummer: { id: "dee", name: "Dee Drummer" }, sweep: { id: "sam", name: "Sam Sweep" },
  seats: [
    { bench: 1, side: "left", paddler: { id: "lily", name: "Lily" } },
    { bench: 1, side: "right", paddler: { id: "nick", name: "Nick" } },
    { bench: 4, side: "right", paddler: { id: "owen", name: "Owen" } },
  ],
  reserves: [{ id: "hannah", name: "Hannah" }],
};

describe("whereAmI", () => {
  it("finds a seat", () => expect(whereAmI(heat, "lily")).toEqual({ kind: "seat", bench: 1, side: "left" }));
  it("drummer / sweep / reserve / none", () => {
    expect(whereAmI(heat, "dee")).toEqual({ kind: "drummer" });
    expect(whereAmI(heat, "sam")).toEqual({ kind: "sweep" });
    expect(whereAmI(heat, "hannah")).toEqual({ kind: "reserve" });
    expect(whereAmI(heat, "nobody")).toEqual({ kind: "none" });
  });
});

describe("benchRows", () => {
  it("emits one row per bench, bow to stern, with section labels and empty seats as null", () => {
    const rows = benchRows(10, heat.seats);
    expect(rows).toHaveLength(10);
    expect(rows[0]).toEqual({ bench: 1, section: "stroke", left: { id: "lily", name: "Lily" }, right: { id: "nick", name: "Nick" } });
    expect(rows[3]).toEqual({ bench: 4, section: "engine", left: null, right: { id: "owen", name: "Owen" } });
    expect(rows[9]).toEqual({ bench: 10, section: "sprint", left: null, right: null });
  });
  it("small boat has five rows", () => expect(benchRows(5, [])).toHaveLength(5));
});
