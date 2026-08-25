import { describe, expect, it } from "vitest";
import { polylinePoints } from "./sparkline";

describe("polylinePoints", () => {
  it("maps values left→right, min at the bottom, max at the top", () => {
    expect(polylinePoints([0, 10], 100, 20, 0)).toBe("0,20 100,0");
    expect(polylinePoints([5, 0, 10], 100, 20, 0)).toBe("0,10 50,20 100,0");
  });
  it("a flat series draws a mid-height line; fewer than two points draws nothing", () => {
    expect(polylinePoints([7, 7, 7], 100, 20, 0)).toBe("0,10 50,10 100,10");
    expect(polylinePoints([7], 100, 20)).toBe("");
    expect(polylinePoints([], 100, 20)).toBe("");
  });
});
