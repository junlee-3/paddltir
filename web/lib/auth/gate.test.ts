import { describe, expect, it } from "vitest";
import { gateFor } from "./gate";

const paddler = { id: "p1", club_id: "c1", name: "Lily", weight_kg: 58, gender: "female", preferred_side: "left", seat_preference: "stroke", boat_role: "paddler" } as const;

describe("gateFor", () => {
  it("no user → /login", () => {
    expect(gateFor({ user: null, profile: null, paddler: null })).toBe("/login");
  });
  it("user without a club → /join", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: null, role: null, display_name: null }, paddler: null })).toBe("/join");
  });
  it("club but no linked paddler row → /join", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: "c1", role: "paddler", display_name: null }, paddler: null })).toBe("/join");
  });
  it("linked → no gate", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: "c1", role: "paddler", display_name: "Lily" }, paddler })).toBeNull();
  });
});
