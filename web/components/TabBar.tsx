"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/", label: "Next" },
  { href: "/availability", label: "Availability" },
  { href: "/erg", label: "Erg" },
  { href: "/profile", label: "Profile" },
] as const;

export function TabBar() {
  const pathname = usePathname();
  return (
    <nav aria-label="Primary" className="fixed inset-x-0 bottom-0 border-t border-border bg-surface pb-[env(safe-area-inset-bottom)]">
      <ul className="mx-auto flex max-w-md">
        {TABS.map((t) => {
          const active = t.href === "/" ? pathname === "/" || pathname.startsWith("/session/") : pathname.startsWith(t.href);
          return (
            <li key={t.href} className="flex-1">
              <Link href={t.href} aria-current={active ? "page" : undefined}
                className={`flex min-h-touch items-center justify-center border-t-2 text-sm font-semibold ${active ? "border-accent text-accent" : "border-transparent text-ink3"}`}>
                {t.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
