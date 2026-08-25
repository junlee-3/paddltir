import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { fetchEvent } from "@/lib/data/sessions";
import { EventView } from "@/components/EventView";
import { RealtimeRefresh } from "@/components/RealtimeRefresh";

export default async function SessionPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const viewer = await getViewer();
  const supabase = await createClient();
  const event = await fetchEvent(supabase, id, viewer.paddler!.id);
  if (!event) notFound();
  return (
    <main className="flex flex-col gap-4">
      <RealtimeRefresh />
      <Link href="/" className="min-h-touch inline-flex items-center text-sm font-semibold text-accent">← Next event</Link>
      <EventView event={event} me={viewer.paddler!.id} nowISO={new Date().toISOString()} />
    </main>
  );
}
