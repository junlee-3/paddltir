import type { Viewer } from "@/lib/data/viewer";

/** Where the (app) layout must send this viewer, or null when they may proceed. */
export function gateFor(viewer: Viewer): "/login" | "/join" | null {
  if (!viewer.user) return "/login";
  if (!viewer.profile?.club_id || !viewer.paddler) return "/join";
  return null;
}
