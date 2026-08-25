import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { CLUB_TZ } from "@/lib/time";
import { ErgForm } from "@/components/ErgForm";
import { Sparkline } from "@/components/Sparkline";
import { Card, MicroLabel, Pill } from "@/components/ui";
import { assertNoQueryError } from "@/lib/data/queryError";

export const metadata: Metadata = { title: "Erg" };

export default async function ErgPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const { data: tests, error: testsError } = await supabase.from("erg_tests").select("id, tested_at, metres, source").eq("paddler_id", viewer.paddler!.id).order("tested_at", { ascending: false }).order("created_at", { ascending: false }).limit(50);
  assertNoQueryError("erg_tests", testsError);
  const history = tests ?? [];
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  const best = history.reduce((m, t) => Math.max(m, t.metres), 0);
  return (
    <main className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Erg</h1>
      <Card className="p-4"><MicroLabel>Log a 1-minute test</MicroLabel><div className="mt-3"><ErgForm today={today} /></div></Card>
      <Card className="p-4">
        <div className="flex items-baseline justify-between"><MicroLabel>Trend</MicroLabel>{best > 0 && <span className="text-sm text-ink2">Best <span className="font-bold text-ink">{best} m</span></span>}</div>
        <div className="mt-3"><Sparkline values={[...history].reverse().map((t) => t.metres)} label="Erg metres over time" /></div>
      </Card>
      <Card>
        <ul className="divide-y divide-border">
          {history.length === 0 && <li className="p-4 text-ink2">No tests yet.</li>}
          {history.map((t) => (
            <li key={t.id} className="flex min-h-touch items-center justify-between px-4 py-2">
              <span className="text-sm text-ink2">{t.tested_at}</span>
              <span className="flex items-center gap-2"><span className="font-bold">{t.metres} m</span><Pill tone={t.source === "coach" ? "accent" : "neutral"}>{t.source === "coach" ? "Coach" : "Self"}</Pill></span>
            </li>
          ))}
        </ul>
      </Card>
    </main>
  );
}
