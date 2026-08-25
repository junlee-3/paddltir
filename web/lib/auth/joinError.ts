const KNOWN: Record<string, string> = {
  "invalid invite code": "That code isn't valid.",
  "paddler not claimable": "That name has already been claimed — pick another or ask your coach.",
  "already in another club": "You're already in another club.",
};

/** Maps a raw `join_club` RPC error message to paddler-facing copy; `undefined` (no error) → null. */
export function joinErrorMessage(raw: string | undefined): string | null {
  if (raw === undefined) return null;
  return KNOWN[raw] ?? "Couldn't join — try again.";
}
