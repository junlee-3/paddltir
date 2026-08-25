import { describe, expect, it } from "vitest";
import { BENCHES, benchesIn, sectionOf } from "./boat";

describe("boat sections (mirrors PaddltirCore.Boat)", () => {
  it("standard boat: stroke 1 · pace 2–3 · engine 4–7 · sprint 8–10", () => {
    expect(BENCHES.standard).toBe(10);
    expect(benchesIn(10, "stroke")).toEqual([1, 1]);
    expect(benchesIn(10, "pace")).toEqual([2, 3]);
    expect(benchesIn(10, "engine")).toEqual([4, 7]);
    expect(benchesIn(10, "sprint")).toEqual([8, 10]);
  });
  it("small boat: stroke 1 · pace 2 · engine 3 · sprint 4–5", () => {
    expect(BENCHES.small).toBe(5);
    expect(benchesIn(5, "pace")).toEqual([2, 2]);
    expect(benchesIn(5, "engine")).toEqual([3, 3]);
    expect(benchesIn(5, "sprint")).toEqual([4, 5]);
  });
  it("degenerate boats: stroke first, sprint last, pace/engine share the middle", () => {
    expect(benchesIn(2, "pace")).toEqual([2, 2]);
    expect(benchesIn(2, "engine")).toEqual([2, 2]);
    expect(benchesIn(3, "engine")).toEqual([3, 3]);
    expect(benchesIn(1, "sprint")).toEqual([1, 1]);
  });
  it("sectionOf covers every bench exactly once", () => {
    const seen = Array.from({ length: 10 }, (_, i) => sectionOf(10, i + 1));
    expect(seen).toEqual(["stroke", "pace", "pace", "engine", "engine", "engine", "engine", "sprint", "sprint", "sprint"]);
  });
});
