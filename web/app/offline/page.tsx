export const metadata = { title: "Offline" };
export default function OfflinePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-3 p-6">
      <p className="micro">You&apos;re offline</p>
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Paddltir needs a connection</h1>
      <p className="text-ink2">Lineups and availability come straight from your club&apos;s live data. Reconnect and pull to refresh.</p>
    </main>
  );
}
