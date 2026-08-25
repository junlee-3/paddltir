const PUBLIC_PREFIXES = ["/login", "/auth/", "/offline", "/icons/"];
const PUBLIC_EXACT = new Set(["/manifest.webmanifest", "/sw.js", "/icon.svg", "/favicon.ico"]);

export function isPublicPath(pathname: string): boolean {
  return PUBLIC_EXACT.has(pathname) || PUBLIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(p));
}

/**
 * Only a same-origin relative path may be used as a post-login destination.
 * WHATWG URL treats `\` as `/`, so `/\evil.com` resolves to `https://evil.com/` —
 * reject any raw `\` (or its percent-encoded form) outright, then confirm the
 * parsed origin still matches before trusting `pathname`/`search` (hash is dropped).
 * Dot-segment removal during parsing can ALSO collapse an innocent-looking path-absolute
 * input (e.g. "/.//evil.com") into a protocol-relative pathname ("//evil.com") — the input
 * guards above never see that, since it only exists in the parsed output — so guard the
 * output too: `redirect()` would otherwise send a scheme-relative `Location: //evil.com`,
 * which browsers resolve as `https://evil.com`.
 */
export function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith("/")) return "/";
  const second = raw[1];
  if (second === "/" || second === "\\") return "/";
  if (raw.includes("\\") || /%5c/i.test(raw)) return "/";
  try {
    const u = new URL(raw, "http://x");
    if (u.origin !== "http://x") return "/";
    if (u.pathname.startsWith("//") || u.pathname.startsWith("/\\")) return "/";
    return u.pathname + u.search;
  } catch {
    return "/";
  }
}
