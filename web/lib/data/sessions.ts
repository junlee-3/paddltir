import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/db/database.types";
import { paddlerIds, toRaceViews, type EventView, type RaceRow } from "@/lib/event";
import { assertNoQueryError } from "@/lib/data/queryError";

type Client = SupabaseClient<Database>;
export type SessionSummary = { id: string; kind: "training" | "race_day"; title: string; startsAt: string; venue: string | null };

export async function fetchUpcomingSessions(supabase: Client, nowISO: string, limit = 10): Promise<SessionSummary[]> {
  const { data, error } = await supabase.from("sessions").select("id, kind, title, starts_at, venue").gte("starts_at", nowISO).order("starts_at").limit(limit);
  if (error) throw error;
  return (data ?? []).map((s) => ({ id: s.id, kind: s.kind, title: s.title, startsAt: s.starts_at, venue: s.venue }));
}

const RACE_SELECT = "id, name, boat_size, sort_order, crews(name), heats(id, name, sort_order, drummer_id, sweep_id, seats(bench, side, paddler_id), heat_reserves(paddler_id))";

export async function fetchEvent(supabase: Client, sessionId: string, paddlerId: string): Promise<EventView | null> {
  const { data: s, error } = await supabase.from("sessions").select("id, kind, title, starts_at, venue").eq("id", sessionId).maybeSingle();
  if (error) throw error;
  if (!s) return null;
  const base = { id: s.id, title: s.title, startsAt: s.starts_at, venue: s.venue };
  if (s.kind === "training") {
    const { data: a, error: aErr } = await supabase.from("availability").select("status, note").eq("session_id", s.id).eq("paddler_id", paddlerId).maybeSingle();
    assertNoQueryError("availability", aErr);
    return { ...base, kind: "training", myAvailability: a?.status ?? null, myNote: a?.note ?? null };
  }
  const { data: races, error: rErr } = await supabase.from("races").select(RACE_SELECT).eq("session_id", s.id).order("sort_order");
  if (rErr) throw rErr;
  const rows = (races ?? []) as unknown as RaceRow[];
  const ids = [...paddlerIds(rows)];
  const names = new Map<string, string>();
  if (ids.length) {
    const { data: people, error: pErr } = await supabase.from("paddlers_public").select("id, name").in("id", ids);
    assertNoQueryError("paddlers_public", pErr);
    people?.forEach((p) => { if (p.id && p.name) names.set(p.id, p.name); });
  }
  return { ...base, kind: "race_day", races: toRaceViews(rows, names) };
}
