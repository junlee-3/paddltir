"use server";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { env } from "@/lib/env";
import { safeNext } from "@/lib/auth/paths";

export type LoginState = { status: "idle" } | { status: "sent"; email: string } | { status: "error"; message: string };

export async function sendMagicLink(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const next = safeNext(String(formData.get("next") ?? ""));
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { status: "error", message: "Enter the email your coach has for you." };
  const origin = (await headers()).get("origin") ?? env.siteUrl;
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: `${origin}/auth/callback?next=${encodeURIComponent(next)}`, shouldCreateUser: true },
  });
  if (error) return { status: "error", message: "Couldn't send the link. Try again in a minute." };
  return { status: "sent", email };
}

/** DEV ONLY — password sign-in against the local stack (mirrors the coach app's DEBUG sign-in). */
export async function devPasswordSignIn(formData: FormData): Promise<void> {
  if (!env.devLogin) throw new Error("dev login is disabled");
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(formData.get("email") ?? ""),
    password: String(formData.get("password") ?? ""),
  });
  if (error) redirect("/login?error=dev");
  redirect(safeNext(String(formData.get("next") ?? "")));
}
