"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@/lib/supabase/client";

const TABLES = ["sessions", "heats", "seats", "heat_reserves", "availability"] as const;

/** Any change to a lineup/session table re-renders the current route from the server (RLS re-applies). */
export function RealtimeRefresh() {
  const router = useRouter();
  useEffect(() => {
    const supabase = createBrowserClient();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const refresh = () => { clearTimeout(timer); timer = setTimeout(() => router.refresh(), 300); };
    let channel = supabase.channel("paddltir-live");
    for (const table of TABLES) channel = channel.on("postgres_changes", { event: "*", schema: "public", table }, refresh);
    channel.subscribe();
    return () => { clearTimeout(timer); supabase.removeChannel(channel); };
  }, [router]);
  return null;
}
