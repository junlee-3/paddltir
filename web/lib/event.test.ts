import { describe, expect, it } from "vitest";
import { paddlerIds, toRaceViews, type RaceRow } from "./event";

const rows: RaceRow[] = [{
  id: "r1", name: "Premier Mixed 200m", boat_size: "standard", sort_order: 1, crews: { name: "Premier Mixed" },
  heats: [
    { id: "h2", name: "Heat 2", sort_order: 2, drummer_id: null, sweep_id: null, seats: [], heat_reserves: [] },
    { id: "h1", name: "Heat 1", sort_order: 1, drummer_id: "dee", sweep_id: "sam",
      seats: [{ bench: 1, side: "left", paddler_id: "lily" }], heat_reserves: [{ paddler_id: "hannah" }] },
  ],
}];
const names = new Map([["lily", "Lily"], ["dee", "Dee Drummer"], ["sam", "Sam Sweep"], ["hannah", "Hannah"]]);

describe("toRaceViews", () => {
  it("orders heats, resolves names, sizes the boat", () => {
    const [race] = toRaceViews(rows, names);
    expect(race.crewName).toBe("Premier Mixed");
    expect(race.benches).toBe(10);
    expect(race.heats.map((h) => h.name)).toEqual(["Heat 1", "Heat 2"]);
    expect(race.heats[0].drummer).toEqual({ id: "dee", name: "Dee Drummer" });
    expect(race.heats[0].seats[0]).toEqual({ bench: 1, side: "left", paddler: { id: "lily", name: "Lily" } });
    expect(race.heats[0].reserves).toEqual([{ id: "hannah", name: "Hannah" }]);
  });
  it("collects every paddler id referenced by a race", () => {
    expect([...paddlerIds(rows)].sort()).toEqual(["dee", "hannah", "lily", "sam"]);
  });
  it("an unknown id renders as 'Unknown' rather than crashing", () => {
    const [race] = toRaceViews(rows, new Map());
    expect(race.heats[0].seats[0].paddler).toEqual({ id: "lily", name: "Unknown" });
  });
});
