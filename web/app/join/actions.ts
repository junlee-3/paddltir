"use server";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type JoinState =
  | { status: "idle" }
  | { status: "choose"; code: string; candidates: { id: string; name: string }[] }
  | { status: "error"; message: string };

export async function lookupInvite(_prev: JoinState, formData: FormData): Promise<JoinState> {
  const code = String(formData.get("code") ?? "").trim().toUpperCase();
  if (code.length < 4) return { status: "error", message: "Enter the invite code your coach shared." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("claimable_paddlers", { p_code: code });
  if (error) return { status: "error", message: "Couldn't look up that code." };
  return { status: "choose", code, candidates: data ?? [] };
}

export async function joinClub(formData: FormData): Promise<void> {
  const code = String(formData.get("code") ?? "").trim().toUpperCase();
  const chosen = String(formData.get("paddler_id") ?? "");
  const supabase = await createClient();
  const { error } = await supabase.rpc("join_club", { p_code: code, p_paddler_id: chosen === "" ? undefined : chosen });
  if (error) redirect(`/join?error=${encodeURIComponent(error.message)}`);
  redirect("/");
}
