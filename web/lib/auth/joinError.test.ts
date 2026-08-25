import { describe, expect, it } from "vitest";
import { joinErrorMessage } from "./joinError";

describe("joinErrorMessage", () => {
  it("maps 'invalid invite code'", () => {
    expect(joinErrorMessage("invalid invite code")).toBe("That code isn't valid.");
  });
  it("maps 'paddler not claimable'", () => {
    expect(joinErrorMessage("paddler not claimable")).toBe("That name has already been claimed — pick another or ask your coach.");
  });
  it("maps 'already in another club'", () => {
    expect(joinErrorMessage("already in another club")).toBe("You're already in another club.");
  });
  it("falls back to a generic message for anything else", () => {
    expect(joinErrorMessage("some unexpected db error")).toBe("Couldn't join — try again.");
  });
  it("returns null when there's no error", () => {
    expect(joinErrorMessage(undefined)).toBeNull();
  });
});
