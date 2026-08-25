import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { Row } from "@/lib/db/rows";

export type OwnPaddler = Pick<Row<"paddlers">, "id" | "club_id" | "name" | "weight_kg" | "gender" | "preferred_side" | "seat_preference" | "boat_role">;
export type Viewer = {
  user: { id: string; email: string | null } | null;
  profile: Pick<Row<"profiles">, "id" | "club_id" | "role" | "display_name"> | null;
  paddler: OwnPaddler | null;
};

/** One session lookup per request (React cache); RLS scopes both reads to the viewer. */
export const getViewer = cache(async (): Promise<Viewer> => {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { user: null, profile: null, paddler: null };
  const [{ data: profile }, { data: paddler }] = await Promise.all([
    supabase.from("profiles").select("id, club_id, role, display_name").eq("id", user.id).maybeSingle(),
    supabase.from("paddlers").select("id, club_id, name, weight_kg, gender, preferred_side, seat_preference, boat_role").eq("profile_id", user.id).is("archived_at", null).maybeSingle(),
  ]);
  return { user: { id: user.id, email: user.email ?? null }, profile, paddler };
});
