"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import type { AvailabilityStatus } from "@/lib/event";

const STATUSES: AvailabilityStatus[] = ["in", "out", "maybe"];

export async function setAvailability(sessionId: string, status: AvailabilityStatus): Promise<{ ok: true } | { ok: false; message: string }> {
  if (!STATUSES.includes(status)) return { ok: false, message: "Invalid status" };
  const viewer = await getViewer();
  if (!viewer.paddler) return { ok: false, message: "You're not linked to a paddler yet." };
  const supabase = await createClient();
  const { error } = await supabase
    .from("availability")
    .upsert({ session_id: sessionId, paddler_id: viewer.paddler.id, status }, { onConflict: "session_id,paddler_id" });
  if (error) return { ok: false, message: "Couldn't save — try again." };
  revalidatePath("/"); revalidatePath(`/session/${sessionId}`); revalidatePath("/availability");
  return { ok: true };
}
