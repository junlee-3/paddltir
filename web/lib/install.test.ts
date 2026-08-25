import { describe, expect, it } from "vitest";
import { shouldShowNudge } from "./install";

describe("shouldShowNudge", () => {
  it("never when already installed or already dismissed", () => {
    expect(shouldShowNudge({ standalone: true, dismissed: false, isIOS: true, canPrompt: true })).toBe("none");
    expect(shouldShowNudge({ standalone: false, dismissed: true, isIOS: false, canPrompt: true })).toBe("none");
  });
  it("iOS gets the Share → Add to Home Screen instructions", () => {
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: true, canPrompt: false })).toBe("ios");
  });
  it("browsers that fired beforeinstallprompt get the install button; others nothing", () => {
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: false, canPrompt: true })).toBe("prompt");
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: false, canPrompt: false })).toBe("none");
  });
});
