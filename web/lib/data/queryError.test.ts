import { describe, expect, it } from "vitest";
import { assertNoQueryError } from "./queryError";

describe("assertNoQueryError", () => {
  it("does not throw when there is no error", () => {
    expect(() => assertNoQueryError("profile", null)).not.toThrow();
  });
  it("throws a descriptive error when the query failed", () => {
    expect(() => assertNoQueryError("profile", { message: "permission denied for table profiles" })).toThrow(
      "viewer: profile query failed: permission denied for table profiles",
    );
  });
});
