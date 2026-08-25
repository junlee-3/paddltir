import { describe, expect, it } from "vitest";
import { isPublicPath, safeNext } from "./paths";

describe("isPublicPath", () => {
  it.each(["/login", "/auth/callback", "/auth/signout", "/offline", "/manifest.webmanifest", "/sw.js", "/icons/icon-192.png"])("%s is public", (p) => {
    expect(isPublicPath(p)).toBe(true);
  });
  it.each(["/", "/availability", "/erg", "/profile", "/session/abc", "/join"])("%s is gated", (p) => {
    expect(isPublicPath(p)).toBe(false);
  });
});

describe("safeNext", () => {
  it("keeps same-origin relative paths", () => {
    expect(safeNext("/erg")).toBe("/erg");
    expect(safeNext("/session/abc?x=1")).toBe("/session/abc?x=1");
  });
  it("rejects absolute, protocol-relative, empty and null", () => {
    expect(safeNext("https://evil.example")).toBe("/");
    expect(safeNext("//evil.example")).toBe("/");
    expect(safeNext("")).toBe("/");
    expect(safeNext(null)).toBe("/");
  });
  it("rejects backslash open-redirect tricks (WHATWG URL treats \\ as /)", () => {
    expect(safeNext("/\\evil.com")).toBe("/");
    expect(safeNext("/\\/evil.com")).toBe("/");
    expect(safeNext("/%5Cevil.com")).toBe("/");
    expect(safeNext("/%5cevil.com")).toBe("/");
  });
  it("drops a hash fragment from an otherwise-safe path", () => {
    expect(safeNext("/erg#frag")).toBe("/erg");
  });
});
