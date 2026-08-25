"use client";
import { createBrowserClient as create } from "@supabase/ssr";
import { env } from "@/lib/env";
import type { Database } from "@/lib/db/database.types";

export function createBrowserClient() {
  return create<Database>(env.supabaseUrl, env.supabaseAnonKey);
}
