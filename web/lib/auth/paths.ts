const PUBLIC_PREFIXES = ["/login", "/auth/", "/offline", "/icons/"];
const PUBLIC_EXACT = new Set(["/manifest.webmanifest", "/sw.js", "/icon.svg", "/favicon.ico"]);

export function isPublicPath(pathname: string): boolean {
  return PUBLIC_EXACT.has(pathname) || PUBLIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(p));
}

/** Only a same-origin relative path may be used as a post-login destination. */
export function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//")) return "/";
  return raw;
}
