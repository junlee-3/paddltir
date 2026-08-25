"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import type { AvailabilityStatus } from "@/lib/event";
import { parseErgSubmission } from "@/lib/erg";
import { CLUB_TZ } from "@/lib/time";

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

export type ErgState = { status: "idle" } | { status: "saved"; metres: number } | { status: "error"; message: string };

export async function submitErg(_prev: ErgState, formData: FormData): Promise<ErgState> {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  const parsed = parseErgSubmission({ metres: String(formData.get("metres") ?? ""), testedAt: String(formData.get("tested_at") ?? "") }, today);
  if (!parsed.ok) return { status: "error", message: parsed.message };
  const viewer = await getViewer();
  if (!viewer.user || !viewer.paddler) return { status: "error", message: "You're not linked to a paddler yet." };
  const supabase = await createClient();
  const { error } = await supabase.from("erg_tests").insert({
    paddler_id: viewer.paddler.id, metres: parsed.metres, tested_at: parsed.testedAt, source: "self", recorded_by: viewer.user.id,
  });
  if (error) return { status: "error", message: "Couldn't save — try again." };
  revalidatePath("/erg");
  return { status: "saved", metres: parsed.metres };
}

export type NameState = { status: "idle" } | { status: "saved" } | { status: "error"; message: string };

export async function updateDisplayName(_prev: NameState, formData: FormData): Promise<NameState> {
  const name = String(formData.get("display_name") ?? "").trim().slice(0, 80);
  if (name.length === 0) return { status: "error", message: "Enter a display name." };
  const viewer = await getViewer();
  if (!viewer.user) return { status: "error", message: "Couldn't save — try again." };
  const supabase = await createClient();
  const { error } = await supabase.from("profiles").update({ display_name: name }).eq("id", viewer.user.id);
  if (error) return { status: "error", message: "Couldn't save — try again." };
  revalidatePath("/profile");
  return { status: "saved" };
}
