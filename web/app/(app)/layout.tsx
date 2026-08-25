import { redirect } from "next/navigation";
import { getViewer } from "@/lib/data/viewer";
import { gateFor } from "@/lib/auth/gate";
import { TabBar } from "@/components/TabBar";
import { InstallNudge } from "@/components/InstallNudge";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const gate = gateFor(await getViewer());
  if (gate) redirect(gate);
  return (
    <>
      <div className="mx-auto max-w-md px-4 pb-24 pt-[max(1rem,env(safe-area-inset-top))]">{children}</div>
      <TabBar />
      <InstallNudge />
    </>
  );
}
