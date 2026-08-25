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
  it("rejects dot-segment normalisation that collapses to a protocol-relative output", () => {
    // WHATWG URL collapses these path-absolute inputs to a "//host"-shaped pathname during
    // parsing (dot-segment removal), which `redirect()` would then send as a scheme-relative
    // Location header — the browser treats "//evil.com" as "https://evil.com". Guard the
    // OUTPUT, not just the input, since the origin check on `raw` never catches this.
    expect(safeNext("/.//evil.com")).toBe("/");
    expect(safeNext("/erg/..//evil.com")).toBe("/");
    expect(safeNext("/%2e%2e//evil.com")).toBe("/");
    expect(safeNext("/.%2e//evil.com")).toBe("/");
  });
  it("still normalises legitimate dot-segments that don't collapse to protocol-relative", () => {
    expect(safeNext("/erg/../availability")).toBe("/availability");
    expect(safeNext("/session/abc?x=1")).toBe("/session/abc?x=1");
  });
});
