"use client";
import { useEffect, useState } from "react";
import { shouldShowNudge, type NudgeKind } from "@/lib/install";
import { PrimaryButton } from "./ui";

type BeforeInstallPromptEvent = Event & { prompt: () => Promise<void> };
const KEY = "paddltir.installNudgeDismissed";

export function InstallNudge() {
  const [kind, setKind] = useState<NudgeKind>("none");
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);

  useEffect(() => {
    const standalone = window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;
    const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
    let dismissed = false;
    try { dismissed = localStorage.getItem(KEY) === "1"; } catch { /* private mode */ }
    // window/localStorage don't exist during SSR, so this syncs post-mount browser state into React once (hydration-safe client-only UI).
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setKind(shouldShowNudge({ standalone, dismissed, isIOS, canPrompt: false }));
    const onPrompt = (e: Event) => { e.preventDefault(); setDeferred(e as BeforeInstallPromptEvent); setKind(shouldShowNudge({ standalone, dismissed, isIOS, canPrompt: true })); };
    window.addEventListener("beforeinstallprompt", onPrompt);
    return () => window.removeEventListener("beforeinstallprompt", onPrompt);
  }, []);

  const dismiss = () => { try { localStorage.setItem(KEY, "1"); } catch { /* ignore */ } setKind("none"); };
  if (kind === "none") return null;
  return (
    <aside role="dialog" aria-label="Install Paddltir" className="fixed inset-x-4 bottom-20 z-10 mx-auto max-w-md rounded-card border border-border bg-surface p-4">
      <p className="font-bold">Add Paddltir to your Home Screen</p>
      {kind === "ios"
        ? <p className="mt-1 text-sm text-ink2">Tap <span className="font-semibold">Share</span>, then <span className="font-semibold">Add to Home Screen</span>.</p>
        : <p className="mt-1 text-sm text-ink2">Get to your seat in one tap.</p>}
      <div className="mt-3 flex gap-2">
        {kind === "prompt" && <PrimaryButton onClick={async () => { await deferred?.prompt(); dismiss(); }}>Install</PrimaryButton>}
        <button type="button" onClick={dismiss} className="min-h-touch px-3 text-sm font-semibold text-ink2">Not now</button>
      </div>
    </aside>
  );
}
