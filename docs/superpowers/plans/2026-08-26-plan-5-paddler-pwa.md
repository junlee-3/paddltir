# Plan 5 — Paddler PWA (Next.js on Vercel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the paddler-facing progressive web app — sign in by magic link, join a club by invite code, see your next event (your seat on the boat diagram for a race, one-tap availability for a training), manage availability, submit and chart erg tests, and edit your profile — installable, realtime, mobile-first, on the Paddltir design language.

**Architecture:** A Next.js App Router app in `web/`. Server Components read Supabase (through `@supabase/ssr` with the user's cookie session — RLS does the authorization) and render; Server Actions write; a tiny set of Client Components own interaction (heat switcher, availability toggle, forms, realtime refresh, install nudge). Pure, unit-tested TypeScript in `web/lib/` holds every rule (boat sections, seat lookup, gating, validation, sparkline maths). No domain scoring is ported — the paddler app *displays* lineups, it never evaluates them.

**Tech Stack:** Next.js (latest, App Router, TypeScript strict, Turbopack) · React 19 · Tailwind CSS v4 (`@theme` tokens) · `@supabase/supabase-js` + `@supabase/ssr` · Vitest · Playwright · pnpm · Vercel Services (`web/` + existing `solver/`).

**Spec:** `docs/superpowers/specs/2026-08-22-paddltir-design.md` — §4 (Paddler PWA), §5 (data model), §7 (hosting), §8 (testing), §9 (repo layout). Visual authority: `docs/design/direction.md`.

## Global Constraints

- **Routes (spec §4, verbatim):** `/login` (magic link) · `/join` (invite code → claim name) · `/` (your next event: race → your seat highlighted on a boat diagram + full lineup by name, heat switcher; training → inline availability) · `/availability` · `/erg` (submit metres + date, history, sparkline) · `/profile`. Installable (manifest + service worker, one-time add-to-home-screen nudge). Realtime subscriptions to heats/seats/sessions. This plan adds `/session/[id]` (the same event view for any upcoming session, linked from `/`), `/auth/callback`, `/auth/signout`, `/offline`.
- **Design (direction.md, verbatim values):** `bg #FAFAFA` · `surface #FFFFFF` · `surface2 #F8FAFC` · `ink #0F172A` · `ink2 #475569` · `ink3 #64748B` · `border #E2E8F0` · `primary #0F172A` · `accent #0D7377` · `good #059669` · `danger #DC2626` · male `#DCFCE7`/`#86EFAC` · female `#FEF3C7`/`#FCD34D`. **Inter Tight only** (via `next/font/google`, `Inter_Tight`), tabular numerals on every number, micro-labels 11px UPPERCASE `letter-spacing .09em` `ink3`, 12px cards / 8px controls / 6px control-sm, 1px hairline borders for depth, **light mode only**, **no fake glass** (no `backdrop-blur` chrome — solid surfaces with hairlines), 44px touch targets, contrast ≥ 4.5:1, `aria-*` on every control. Styles come from the `@theme` tokens (Task 1) — never a raw hex in a component.
- **Naming:** the product is **Paddltir** — never "CrewCoach" in any user-facing string, title, manifest, or icon.
- **Privacy is a data fact, not a UI choice:** a paddler reads club-mates only through `paddlers_public` (`id, club_id, name, preferred_side, boat_role, profile_id, archived_at`) — **no gender, weight, email, erg of others**. Seat tiles are therefore neutral (surface + hairline); the viewer's own seat is the only accented tile. Their own full `paddlers` row is readable (`paddlers_select_self`) but **not writable** (coach-only) — `/profile` shows it read-only.
- **Writes a paddler may make (RLS, verbatim policies):** `availability` insert/update own rows (`paddler_id = my_paddler_id()`); `erg_tests` insert with `source = 'self' and recorded_by = auth.uid()`; `profiles.display_name` (own row; `club_id`/`role` are trigger-protected). Every Server Action derives `paddler_id` on the server from the session — never from the request body.
- **Secrets:** only `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY` (the anon/publishable key) reach the app. **The service-role key never appears anywhere in `web/`.** `web/.env.local` is git-ignored (root `.gitignore` already ignores `.env.*` except `.env.example`); `web/.env.example` is committed with local-stack placeholders. Never commit a real hosted key.
- **Auth:** `@supabase/ssr` cookie sessions; server code always uses `supabase.auth.getUser()` (never trusts `getSession()`); the session-refreshing request hook is `proxy.ts` (Next 16 rename of middleware — if `pnpm exec next --version` prints 15.x, the file is `middleware.ts` exporting `middleware`, same body). Magic link redirect goes to `/auth/callback`; local `supabase/config.toml` already allows `http://localhost:3000/**` and `https://paddltir.vercel.app/**`.
- **Realtime:** browser `postgres_changes` subscriptions on `sessions, heats, seats, heat_reserves, availability` trigger a `router.refresh()` — the payload is never rendered (RLS-filtered realtime cannot authorize DELETE payloads). Requires the publication migration in Task 3 (`alter publication supabase_realtime add table …`) with its pgTAP test.
- **Testing (spec §8):** Vitest unit tests for every `lib/` module (TDD — test first); one Playwright smoke (`e2e/smoke.spec.ts`) against the **local** Supabase stack (`supabase start` + `supabase db reset` + `psql … -f supabase/seed_dev.sql`), gated on `PADDLTIR_LIVE_SUPABASE=1`, signing in with the seeded paddler `lily@paddltir.dev` / `password123` through a **dev-only password form** shown only when `NEXT_PUBLIC_PADDLTIR_DEV_LOGIN=1` (the same pattern as the coach app's DEBUG sign-in; the flag is never set on Vercel).
- **Quality gate for every task:** from `web/`: `pnpm typecheck && pnpm lint && pnpm test && pnpm build` all green, zero warnings introduced. Commit per task with conventional-commit subjects.
- **Toolchain (verified locally):** Node 22.19, pnpm 10.33, Playwright 1.62. Tailwind v4 is CSS-first: tokens live in `app/globals.css` under `@theme`, there is no `tailwind.config.js`.
- **Hosting (spec §7):** `vercel.json` gains the `web` service (Task 6). **Deploying is go-live and needs Jun's Vercel/Supabase credentials — this plan ends at a merged, locally verified app; it does not deploy.**
- **Seat semantics (from `PaddltirCore.Boat`, mirrored exactly):** benches `1…n` bow→stern (`standard` n=10, `small` n=5); Drummer at the bow (above bench 1), Sweep at the stern (below bench n); sides `left|right`; sections: stroke = bench 1; pace = the next `max(1, round(0.2n))` benches; sprint = the last `max(1, round(0.3n))`; engine = the rest (n<4: stroke first, sprint last, pace/engine share the middle).
- The old project at `/Users/junlee/Documents/CGS/IB/IA/LEEJun-CSIA/Product/crewCoach` is READ-ONLY reference; nothing is copied from it.

---

## File structure

```
web/
  app/
    layout.tsx                 root: Inter Tight, metadata/viewport, light colour-scheme, SW registration, install nudge
    globals.css                Tailwind v4 import + @theme tokens + base styles
    manifest.ts                PWA manifest (Task 5)
    icon.svg                   favicon (Task 5)
    offline/page.tsx           static offline fallback (Task 5)
    login/page.tsx             magic-link form (+ dev password form when flagged)
    login/actions.ts           sendMagicLink, devPasswordSignIn
    join/page.tsx              invite code → claimable names → join
    join/actions.ts            lookupInvite, joinClub
    auth/callback/route.ts     code / token_hash exchange
    auth/signout/route.ts      POST sign-out
    (app)/layout.tsx           gate (login/join) + bottom tab bar
    (app)/page.tsx             next event + upcoming list
    (app)/session/[id]/page.tsx   event view for one session
    (app)/availability/page.tsx
    (app)/erg/page.tsx
    (app)/profile/page.tsx
    (app)/actions.ts           setAvailability, submitErg, updateDisplayName
  components/
    ui.tsx                     MicroLabel, Card, PrimaryButton, Pill, SegmentedControl
    TabBar.tsx                 client: bottom nav with active state
    EventView.tsx              server: race-day vs training rendering
    RaceCard.tsx               client: heat switcher + BoatDiagram
    BoatDiagram.tsx            the hull grid (pure render)
    AvailabilityToggle.tsx     client: in/maybe/out → server action
    ErgForm.tsx                client: metres + date → server action
    Sparkline.tsx              inline SVG
    RealtimeRefresh.tsx        client: postgres_changes → router.refresh()
    RegisterServiceWorker.tsx  client
    InstallNudge.tsx           client
  lib/
    env.ts                     validated public env
    boat.ts (+test)            sections, bench ranges
    lineup.ts (+test)          seatOf, benchRows
    event.ts (+test)           row → NextEvent mapping
    time.ts (+test)            formatting in the club time zone
    erg.ts (+test)             parseErgSubmission
    sparkline.ts (+test)       polyline points
    install.ts (+test)         shouldShowNudge
    auth/gate.ts (+test)       gateFor(viewer)
    auth/paths.ts (+test)      isPublicPath, safeNext
    supabase/server.ts         createClient() for RSC/actions/route handlers
    supabase/client.ts         createBrowserClient()
    supabase/proxy.ts          updateSession(request)
    db/database.types.ts       generated (`supabase gen types`)
    db/rows.ts                 Row<'sessions'> aliases
    data/viewer.ts             getViewer() (React cache)
    data/sessions.ts           queries
  public/sw.js                 service worker (Task 5)
  public/icons/*.png           generated icons (Task 5)
  scripts/make-icons.mjs       sharp: svg → png (Task 5)
  e2e/smoke.spec.ts            Playwright (Task 6)
  proxy.ts                     session refresh hook
  vitest.config.ts · playwright.config.ts · next.config.ts · .env.example · README.md
supabase/migrations/20260826000600_realtime.sql   publication (Task 3)
supabase/tests/007_realtime.sql                    pgTAP (Task 3)
vercel.json                                        + web service (Task 6)
```

---

### Task 1: Scaffold `web/`, design tokens, fonts, UI primitives, `lib/boat.ts`

**Files:**
- Create: `web/` via `create-next-app`, then `web/app/globals.css`, `web/app/layout.tsx`, `web/app/page.tsx` (placeholder replaced in Task 3), `web/components/ui.tsx`, `web/lib/boat.ts`, `web/lib/boat.test.ts`, `web/vitest.config.ts`, `web/.env.example`
- Modify: `web/package.json` (scripts), `web/tsconfig.json` (strict already on — verify)

**Interfaces:**
- Produces: `@theme` tokens (`bg-bg text-ink border-border rounded-card …`), `MicroLabel`, `Card`, `PrimaryButton`, `Pill`, `SegmentedControl`; `lib/boat.ts` exports `type BoatSize = 'small' | 'standard'`, `type Section = 'stroke' | 'pace' | 'engine' | 'sprint'`, `BENCHES: Record<BoatSize, number>`, `benchesIn(benches: number, section: Section): [number, number]`, `sectionOf(benches: number, bench: number): Section`.

- [ ] **Step 1: Scaffold**

```bash
cd /Users/junlee/Documents/programming/paddltir
pnpm dlx create-next-app@latest web --typescript --tailwind --eslint --app --import-alias "@/*" --use-pnpm --yes
cd web && pnpm exec next --version && rm -f public/*.svg && ls app && test ! -d src && echo "no src/ dir (expected)"
```
(`--yes` takes the defaults for everything not given: no `src/` directory, Turbopack on. Registry check on 2026-08-26: `next` 16.3.2, `tailwindcss` 4.3, `@supabase/ssr` 0.12, `vitest` 4.1 — so the session hook file is `proxy.ts`.) Record the printed Next.js version in your report. If the scaffold produced a `src/` directory anyway, move `app/` up to `web/app/` and delete `src/` before continuing — every path in this plan is `web/app/...`, `web/lib/...`, `web/components/...`.

- [ ] **Step 2: Scripts + Vitest**

```bash
cd /Users/junlee/Documents/programming/paddltir/web && pnpm add -D vitest
```
Edit `package.json` scripts to exactly:
```json
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "eslint .",
  "typecheck": "tsc --noEmit",
  "test": "vitest run",
  "test:watch": "vitest"
}
```
(`next lint` was removed in Next 16; if the scaffold produced `"lint": "next lint"`, replace it as above — `eslint.config.mjs` from the scaffold already configures `eslint-config-next`.)

Create `web/vitest.config.ts`:
```ts
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": path.resolve(__dirname) } },
  test: {
    include: ["lib/**/*.test.ts"],
    exclude: ["node_modules", ".next", "e2e"],
  },
});
```

- [ ] **Step 3: Write the failing boat test**

`web/lib/boat.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { BENCHES, benchesIn, sectionOf } from "./boat";

describe("boat sections (mirrors PaddltirCore.Boat)", () => {
  it("standard boat: stroke 1 · pace 2–3 · engine 4–7 · sprint 8–10", () => {
    expect(BENCHES.standard).toBe(10);
    expect(benchesIn(10, "stroke")).toEqual([1, 1]);
    expect(benchesIn(10, "pace")).toEqual([2, 3]);
    expect(benchesIn(10, "engine")).toEqual([4, 7]);
    expect(benchesIn(10, "sprint")).toEqual([8, 10]);
  });
  it("small boat: stroke 1 · pace 2 · engine 3 · sprint 4–5", () => {
    expect(BENCHES.small).toBe(5);
    expect(benchesIn(5, "pace")).toEqual([2, 2]);
    expect(benchesIn(5, "engine")).toEqual([3, 3]);
    expect(benchesIn(5, "sprint")).toEqual([4, 5]);
  });
  it("degenerate boats: stroke first, sprint last, pace/engine share the middle", () => {
    expect(benchesIn(2, "pace")).toEqual([2, 2]);
    expect(benchesIn(2, "engine")).toEqual([2, 2]);
    expect(benchesIn(3, "engine")).toEqual([3, 3]);
    expect(benchesIn(1, "sprint")).toEqual([1, 1]);
  });
  it("sectionOf covers every bench exactly once", () => {
    const seen = Array.from({ length: 10 }, (_, i) => sectionOf(10, i + 1));
    expect(seen).toEqual(["stroke", "pace", "pace", "engine", "engine", "engine", "engine", "sprint", "sprint", "sprint"]);
  });
});
```

- [ ] **Step 4: Run it — expect FAIL** (`pnpm test` → "Failed to resolve import ./boat").

- [ ] **Step 5: Implement `web/lib/boat.ts`**

```ts
// Mirrors PaddltirCore/Domain/Boat.swift — keep the two in lock-step.
export type BoatSize = "small" | "standard";
export type Section = "stroke" | "pace" | "engine" | "sprint";
export const SECTIONS: readonly Section[] = ["stroke", "pace", "engine", "sprint"];
export const BENCHES: Record<BoatSize, number> = { small: 5, standard: 10 };

/** Inclusive bench range for a section. n < 4 is the degenerate rule from Boat.swift. */
export function benchesIn(benches: number, section: Section): [number, number] {
  const n = benches;
  if (n < 4) {
    switch (section) {
      case "stroke": return [1, 1];
      case "pace": return n >= 2 ? [2, 2] : [1, 1];
      case "engine": return n >= 3 ? [3, 3] : n >= 2 ? [2, 2] : [1, 1];
      case "sprint": return [n, n];
    }
  }
  const sprintCount = Math.max(1, Math.round(n * 0.3));
  const paceCount = Math.max(1, Math.round(n * 0.2));
  const paceEnd = 1 + paceCount;
  const sprintStart = n - sprintCount + 1;
  switch (section) {
    case "stroke": return [1, 1];
    case "pace": return [2, paceEnd];
    case "engine": return [paceEnd + 1, sprintStart - 1];
    case "sprint": return [sprintStart, n];
  }
}

export function sectionOf(benches: number, bench: number): Section {
  for (const s of SECTIONS) {
    const [lo, hi] = benchesIn(benches, s);
    if (bench >= lo && bench <= hi) return s;
  }
  return "engine";
}
```

- [ ] **Step 6: Run — expect PASS** (`pnpm test` → 4 passed).

- [ ] **Step 7: Tokens + base styles** — replace `web/app/globals.css` entirely:

```css
@import "tailwindcss";

@theme {
  --color-bg: #fafafa;
  --color-surface: #ffffff;
  --color-surface2: #f8fafc;
  --color-ink: #0f172a;
  --color-ink2: #475569;
  --color-ink3: #64748b;
  --color-border: #e2e8f0;
  --color-primary: #0f172a;
  --color-on-primary: #ffffff;
  --color-accent: #0d7377;
  --color-good: #059669;
  --color-danger: #dc2626;
  --color-male-fill: #dcfce7;
  --color-male-border: #86efac;
  --color-female-fill: #fef3c7;
  --color-female-border: #fcd34d;
  --font-sans: var(--font-inter-tight), ui-sans-serif, system-ui, sans-serif;
  --radius-card: 12px;
  --radius-ctl: 8px;
  --radius-sm: 6px;
  --spacing-touch: 44px;
}

html { color-scheme: light; }
body {
  background: var(--color-bg);
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-variant-numeric: tabular-nums;
  -webkit-font-smoothing: antialiased;
}

/* CrewCoach signature: tiny tracked uppercase micro-label */
.micro {
  font-size: 11px;
  line-height: 1;
  font-weight: 600;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: var(--color-ink3);
}
```

- [ ] **Step 8: Root layout** — replace `web/app/layout.tsx`:

```tsx
import type { Metadata, Viewport } from "next";
import { Inter_Tight } from "next/font/google";
import "./globals.css";

const interTight = Inter_Tight({ subsets: ["latin"], variable: "--font-inter-tight", display: "swap" });

export const metadata: Metadata = {
  title: { default: "Paddltir", template: "%s · Paddltir" },
  applicationName: "Paddltir",
  description: "Your crew, your seat, your next race.",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "Paddltir" },
};

export const viewport: Viewport = {
  themeColor: "#FAFAFA",
  colorScheme: "light",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={interTight.variable}>
      <body className="min-h-dvh bg-bg text-ink">{children}</body>
    </html>
  );
}
```
Replace `web/app/page.tsx` with a placeholder that Task 3 overwrites:
```tsx
export default function Page() {
  return <main className="p-6"><h1 className="text-2xl font-bold tracking-tight">Paddltir</h1></main>;
}
```

- [ ] **Step 9: UI primitives** — `web/components/ui.tsx`:

```tsx
import type { ComponentProps, ReactNode } from "react";

export function MicroLabel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`micro ${className}`}>{children}</span>;
}

export function Card({ children, className = "", ...rest }: ComponentProps<"section">) {
  return (
    <section className={`rounded-card border border-border bg-surface ${className}`} {...rest}>
      {children}
    </section>
  );
}

export function PrimaryButton({ children, className = "", ...rest }: ComponentProps<"button">) {
  return (
    <button
      className={`min-h-touch rounded-ctl bg-primary px-5 font-semibold text-on-primary disabled:opacity-50 ${className}`}
      {...rest}
    >
      {children}
    </button>
  );
}

export type PillTone = "neutral" | "accent" | "good" | "danger";
const pillTone: Record<PillTone, string> = {
  neutral: "border-border bg-surface2 text-ink2",
  accent: "border-accent/30 bg-accent/10 text-accent",
  good: "border-good/30 bg-good/10 text-good",
  danger: "border-danger/30 bg-danger/10 text-danger",
};
export function Pill({ children, tone = "neutral" }: { children: ReactNode; tone?: PillTone }) {
  return (
    <span className={`inline-flex items-center rounded-sm border px-2 py-0.5 text-xs font-semibold ${pillTone[tone]}`}>
      {children}
    </span>
  );
}

/** Radio-group semantics: one option is `aria-checked`; each target is ≥ 44px tall. */
export function SegmentedControl<T extends string>({
  options, value, onChange, label, disabled = false,
}: { options: { value: T; label: string; tone?: PillTone }[]; value: T | null; onChange: (v: T) => void; label: string; disabled?: boolean }) {
  return (
    <div role="radiogroup" aria-label={label} className="flex rounded-ctl border border-border bg-surface p-1">
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={selected}
            disabled={disabled}
            onClick={() => onChange(o.value)}
            className={`min-h-touch flex-1 rounded-sm text-sm font-semibold transition-colors ${
              selected ? "bg-primary text-on-primary" : "text-ink2 hover:bg-surface2"
            } disabled:opacity-50`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 10: `.env.example`** — `web/.env.example`:
```
# Local Supabase stack — run `supabase start` then `supabase status` and paste the anon key.
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=PASTE_LOCAL_ANON_KEY
# Used for the magic-link redirect when no Origin header is present.
NEXT_PUBLIC_SITE_URL=http://localhost:3000
# Dev-only password sign-in form on /login. NEVER set on Vercel.
NEXT_PUBLIC_PADDLTIR_DEV_LOGIN=1
```
Copy it to `web/.env.local` and paste the real local key from `supabase status` — either the legacy `ANON_KEY` JWT or the newer `PUBLISHABLE_KEY` (`sb_publishable_…`) works with supabase-js ≥ 2.100; never the `SECRET_KEY`/`SERVICE_ROLE_KEY`. `.env.local` is git-ignored; confirm with `git status --ignored web/.env.local`.

- [ ] **Step 11: Gate** — `cd web && pnpm typecheck && pnpm lint && pnpm test && pnpm build` — all green.

- [ ] **Step 12: Commit**
```bash
cd /Users/junlee/Documents/programming/paddltir && git add web && git status --short   # confirm .env.local is NOT listed
git commit -m "feat(web): scaffold Paddltir PWA — Next.js, Tailwind v4 tokens, Inter Tight, UI primitives, boat sections"
```

---

### Task 2: Supabase clients, session hook, magic-link login, join-by-invite, gate

**Files:**
- Create: `web/lib/env.ts`, `web/lib/supabase/server.ts`, `web/lib/supabase/client.ts`, `web/lib/supabase/proxy.ts`, `web/proxy.ts`, `web/lib/db/database.types.ts` (generated), `web/lib/db/rows.ts`, `web/lib/data/viewer.ts`, `web/lib/auth/gate.ts` (+`.test.ts`), `web/lib/auth/paths.ts` (+`.test.ts`), `web/app/login/page.tsx`, `web/app/login/actions.ts`, `web/app/auth/callback/route.ts`, `web/app/auth/signout/route.ts`, `web/app/join/page.tsx`, `web/app/join/actions.ts`, `web/app/(app)/layout.tsx`, `web/components/TabBar.tsx`
- Move: `web/app/page.tsx` → `web/app/(app)/page.tsx` (still the placeholder; Task 3 fills it)

**Interfaces:**
- Consumes: Task 1 primitives and tokens.
- Produces: `createClient(): Promise<SupabaseClient<Database>>` (server), `createBrowserClient()` (client), `getViewer(): Promise<Viewer>` where `Viewer = { user: { id: string; email: string | null } | null; profile: { id: string; club_id: string | null; role: string | null; display_name: string | null } | null; paddler: OwnPaddler | null }` and `OwnPaddler = Pick<Row<'paddlers'>, 'id'|'club_id'|'name'|'weight_kg'|'gender'|'preferred_side'|'seat_preference'|'boat_role'>`; `gateFor(viewer): '/login' | '/join' | null`; `isPublicPath(pathname)`, `safeNext(raw)`.

- [ ] **Step 1: Install + generate types** (local stack must be running: `supabase status` from the repo root)
```bash
cd /Users/junlee/Documents/programming/paddltir/web && pnpm add @supabase/supabase-js @supabase/ssr
cd .. && supabase gen types typescript --local --schema public > web/lib/db/database.types.ts && head -5 web/lib/db/database.types.ts
```
`web/lib/db/rows.ts`:
```ts
import type { Database } from "./database.types";
export type Tables = Database["public"]["Tables"];
export type Row<T extends keyof Tables> = Tables[T]["Row"];
export type Enums = Database["public"]["Enums"];
export type PaddlerPublic = Database["public"]["Views"]["paddlers_public"]["Row"];
```

- [ ] **Step 2: Failing tests for the pure auth rules**

`web/lib/auth/paths.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { isPublicPath, safeNext } from "./paths";

describe("isPublicPath", () => {
  it.each(["/login", "/auth/callback", "/auth/signout", "/offline", "/manifest.webmanifest", "/sw.js", "/icons/icon-192.png"])("%s is public", (p) => {
    expect(isPublicPath(p)).toBe(true);
  });
  it.each(["/", "/availability", "/erg", "/profile", "/session/abc", "/join"])("%s is gated", (p) => {
    expect(isPublicPath(p)).toBe(false);
  });
});

describe("safeNext", () => {
  it("keeps same-origin relative paths", () => {
    expect(safeNext("/erg")).toBe("/erg");
    expect(safeNext("/session/abc?x=1")).toBe("/session/abc?x=1");
  });
  it("rejects absolute, protocol-relative, empty and null", () => {
    expect(safeNext("https://evil.example")).toBe("/");
    expect(safeNext("//evil.example")).toBe("/");
    expect(safeNext("")).toBe("/");
    expect(safeNext(null)).toBe("/");
  });
});
```
`web/lib/auth/gate.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { gateFor } from "./gate";

const paddler = { id: "p1", club_id: "c1", name: "Lily", weight_kg: 58, gender: "female", preferred_side: "left", seat_preference: "stroke", boat_role: "paddler" } as const;

describe("gateFor", () => {
  it("no user → /login", () => {
    expect(gateFor({ user: null, profile: null, paddler: null })).toBe("/login");
  });
  it("user without a club → /join", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: null, role: null, display_name: null }, paddler: null })).toBe("/join");
  });
  it("club but no linked paddler row → /join", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: "c1", role: "paddler", display_name: null }, paddler: null })).toBe("/join");
  });
  it("linked → no gate", () => {
    expect(gateFor({ user: { id: "u", email: null }, profile: { id: "u", club_id: "c1", role: "paddler", display_name: "Lily" }, paddler })).toBeNull();
  });
});
```
Run `pnpm test` — expect FAIL (modules missing).

- [ ] **Step 3: Implement the pure modules**

`web/lib/auth/paths.ts`:
```ts
const PUBLIC_PREFIXES = ["/login", "/auth/", "/offline", "/icons/"];
const PUBLIC_EXACT = new Set(["/manifest.webmanifest", "/sw.js", "/icon.svg", "/favicon.ico"]);

export function isPublicPath(pathname: string): boolean {
  return PUBLIC_EXACT.has(pathname) || PUBLIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(p));
}

/** Only a same-origin relative path may be used as a post-login destination. */
export function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//")) return "/";
  return raw;
}
```
`web/lib/auth/gate.ts`:
```ts
import type { Viewer } from "@/lib/data/viewer";

/** Where the (app) layout must send this viewer, or null when they may proceed. */
export function gateFor(viewer: Viewer): "/login" | "/join" | null {
  if (!viewer.user) return "/login";
  if (!viewer.profile?.club_id || !viewer.paddler) return "/join";
  return null;
}
```
`web/lib/env.ts`:
```ts
function required(name: string, value: string | undefined): string {
  if (!value) throw new Error(`${name} is not set — copy web/.env.example to web/.env.local and fill it in`);
  return value;
}
export const env = {
  supabaseUrl: required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: required("NEXT_PUBLIC_SUPABASE_ANON_KEY", process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY),
  siteUrl: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  devLogin: process.env.NEXT_PUBLIC_PADDLTIR_DEV_LOGIN === "1",
};
```
`web/lib/data/viewer.ts`:
```ts
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { Row } from "@/lib/db/rows";

export type OwnPaddler = Pick<Row<"paddlers">, "id" | "club_id" | "name" | "weight_kg" | "gender" | "preferred_side" | "seat_preference" | "boat_role">;
export type Viewer = {
  user: { id: string; email: string | null } | null;
  profile: Pick<Row<"profiles">, "id" | "club_id" | "role" | "display_name"> | null;
  paddler: OwnPaddler | null;
};

/** One session lookup per request (React cache); RLS scopes both reads to the viewer. */
export const getViewer = cache(async (): Promise<Viewer> => {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { user: null, profile: null, paddler: null };
  const [{ data: profile }, { data: paddler }] = await Promise.all([
    supabase.from("profiles").select("id, club_id, role, display_name").eq("id", user.id).maybeSingle(),
    supabase.from("paddlers").select("id, club_id, name, weight_kg, gender, preferred_side, seat_preference, boat_role").eq("profile_id", user.id).is("archived_at", null).maybeSingle(),
  ]);
  return { user: { id: user.id, email: user.email ?? null }, profile, paddler };
});
```
Run `pnpm test` — the two pure suites PASS (viewer.ts is only type-imported by gate.ts).

- [ ] **Step 4: Supabase clients + session hook**

`web/lib/supabase/server.ts`:
```ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { env } from "@/lib/env";
import type { Database } from "@/lib/db/database.types";

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient<Database>(env.supabaseUrl, env.supabaseAnonKey, {
    cookies: {
      getAll() { return cookieStore.getAll(); },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Called from a Server Component: cookies are read-only there; proxy.ts refreshes the session instead.
        }
      },
    },
  });
}
```
`web/lib/supabase/client.ts`:
```ts
"use client";
import { createBrowserClient as create } from "@supabase/ssr";
import { env } from "@/lib/env";
import type { Database } from "@/lib/db/database.types";

export function createBrowserClient() {
  return create<Database>(env.supabaseUrl, env.supabaseAnonKey);
}
```
`web/lib/supabase/proxy.ts`:
```ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { env } from "@/lib/env";
import { isPublicPath } from "@/lib/auth/paths";

/** Refreshes the auth cookies on every request and bounces signed-out visitors to /login. */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const supabase = createServerClient(env.supabaseUrl, env.supabaseAnonKey, {
    cookies: {
      getAll() { return request.cookies.getAll(); },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });
  const { data: { user } } = await supabase.auth.getUser();  // getUser() validates with Supabase Auth; never trust getSession() here
  const { pathname } = request.nextUrl;
  if (!user && !isPublicPath(pathname)) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = pathname === "/" ? "" : `?next=${encodeURIComponent(pathname)}`;
    return NextResponse.redirect(url);
  }
  return response;
}
```
`web/proxy.ts` (Next 16; on 15.x name it `middleware.ts` and export `middleware`):
```ts
import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icon.svg|icons/|sw.js|manifest.webmanifest|.*\\.(?:png|svg|ico)$).*)"],
};
```
If `pnpm build` warns that the config export must be named `proxyConfig`, rename it — keep whichever name builds warning-free and note it in the report.

- [ ] **Step 5: Login page + actions**

`web/app/login/actions.ts`:
```ts
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
```
`web/app/login/page.tsx`:
```tsx
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { LoginForm } from "./LoginForm";
import { getViewer } from "@/lib/data/viewer";
import { env } from "@/lib/env";
import { safeNext } from "@/lib/auth/paths";
import { devPasswordSignIn } from "./actions";
import { Card, MicroLabel, PrimaryButton } from "@/components/ui";

export const metadata: Metadata = { title: "Sign in" };

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string; error?: string }> }) {
  const { next, error } = await searchParams;
  const viewer = await getViewer();
  if (viewer.user) redirect(safeNext(next ?? null));
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <header>
        <p className="text-3xl font-extrabold tracking-[-0.02em]">Paddltir</p>
        <p className="mt-1 text-ink2">Your crew, your seat, your next race.</p>
      </header>
      <Card className="p-5">
        <LoginForm next={safeNext(next ?? null)} />
        {error === "link" && <p role="alert" className="mt-3 text-sm text-danger">That link has expired — request a new one.</p>}
      </Card>
      {env.devLogin && (
        <Card className="border-dashed p-5">
          <MicroLabel>Dev sign-in (local stack)</MicroLabel>
          <form action={devPasswordSignIn} className="mt-3 flex flex-col gap-3">
            <input type="hidden" name="next" value={safeNext(next ?? null)} />
            <input name="email" type="email" defaultValue="lily@paddltir.dev" aria-label="Email" className="min-h-touch rounded-ctl border border-border px-3" />
            <input name="password" type="password" defaultValue="password123" aria-label="Password" className="min-h-touch rounded-ctl border border-border px-3" />
            <PrimaryButton type="submit">Sign in with password</PrimaryButton>
          </form>
        </Card>
      )}
    </main>
  );
}
```
`web/app/login/LoginForm.tsx`:
```tsx
"use client";
import { useActionState } from "react";
import { sendMagicLink, type LoginState } from "./actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function LoginForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<LoginState, FormData>(sendMagicLink, { status: "idle" });
  if (state.status === "sent") {
    return (
      <div role="status">
        <MicroLabel>Check your email</MicroLabel>
        <p className="mt-2">We sent a sign-in link to <span className="font-semibold">{state.email}</span>. Open it on this device.</p>
      </div>
    );
  }
  return (
    <form action={action} className="flex flex-col gap-3">
      <input type="hidden" name="next" value={next} />
      <label className="flex flex-col gap-1">
        <MicroLabel>Email</MicroLabel>
        <input name="email" type="email" inputMode="email" autoComplete="email" required placeholder="you@club.com"
          className="min-h-touch rounded-ctl border border-border bg-surface px-3 text-ink placeholder:text-ink3 focus:border-accent focus:outline-none" />
      </label>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Sending…" : "Email me a sign-in link"}</PrimaryButton>
    </form>
  );
}
```

- [ ] **Step 6: Auth route handlers**

`web/app/auth/callback/route.ts`:
```ts
import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import { safeNext } from "@/lib/auth/paths";

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const next = safeNext(searchParams.get("next"));
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const supabase = await createClient();
  const { error } = code
    ? await supabase.auth.exchangeCodeForSession(code)
    : tokenHash && type
      ? await supabase.auth.verifyOtp({ token_hash: tokenHash, type })
      : { error: new Error("missing code") };
  if (error) return NextResponse.redirect(`${origin}/login?error=link`);
  return NextResponse.redirect(`${origin}${next}`);
}
```
`web/app/auth/signout/route.ts`:
```ts
import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(new URL("/login", request.url), { status: 303 });
}
```

- [ ] **Step 7: Join page + actions**

`web/app/join/actions.ts`:
```ts
"use server";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type JoinState =
  | { status: "idle" }
  | { status: "choose"; code: string; candidates: { id: string; name: string }[] }
  | { status: "error"; message: string };

export async function lookupInvite(_prev: JoinState, formData: FormData): Promise<JoinState> {
  const code = String(formData.get("code") ?? "").trim().toUpperCase();
  if (code.length < 4) return { status: "error", message: "Enter the invite code your coach shared." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("claimable_paddlers", { p_code: code });
  if (error) return { status: "error", message: "Couldn't look up that code." };
  return { status: "choose", code, candidates: data ?? [] };
}

export async function joinClub(formData: FormData): Promise<void> {
  const code = String(formData.get("code") ?? "").trim().toUpperCase();
  const chosen = String(formData.get("paddler_id") ?? "");
  const supabase = await createClient();
  const { error } = await supabase.rpc("join_club", { p_code: code, p_paddler_id: chosen === "" ? undefined : chosen });
  if (error) redirect(`/join?error=${encodeURIComponent(error.message)}`);
  redirect("/");
}
```
`web/app/join/JoinForm.tsx`:
```tsx
"use client";
import { useActionState } from "react";
import { joinClub, lookupInvite, type JoinState } from "./actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function JoinForm() {
  const [state, action, pending] = useActionState<JoinState, FormData>(lookupInvite, { status: "idle" });
  if (state.status === "choose") {
    return (
      <form action={joinClub} className="flex flex-col gap-3">
        <input type="hidden" name="code" value={state.code} />
        <MicroLabel>Which one is you?</MicroLabel>
        {state.candidates.length === 0 && <p className="text-ink2">No unclaimed names match this code. Join anyway — if your coach entered your email, you'll be linked automatically.</p>}
        <div role="radiogroup" aria-label="Your name" className="flex flex-col gap-2">
          {state.candidates.map((c, i) => (
            <label key={c.id} className="flex min-h-touch items-center gap-3 rounded-ctl border border-border bg-surface px-3 has-checked:border-accent">
              <input type="radio" name="paddler_id" value={c.id} defaultChecked={i === 0} className="accent-accent" />
              <span className="font-semibold">{c.name}</span>
            </label>
          ))}
          <label className="flex min-h-touch items-center gap-3 rounded-ctl border border-border bg-surface px-3 has-checked:border-accent">
            <input type="radio" name="paddler_id" value="" defaultChecked={state.candidates.length === 0} className="accent-accent" />
            <span className="text-ink2">I'm not listed</span>
          </label>
        </div>
        <PrimaryButton type="submit">Join club</PrimaryButton>
      </form>
    );
  }
  return (
    <form action={action} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1">
        <MicroLabel>Invite code</MicroLabel>
        <input name="code" required autoCapitalize="characters" autoComplete="off" placeholder="DEMO2026"
          className="min-h-touch rounded-ctl border border-border bg-surface px-3 font-mono text-lg tracking-widest uppercase placeholder:text-ink3 focus:border-accent focus:outline-none" />
      </label>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Looking up…" : "Continue"}</PrimaryButton>
    </form>
  );
}
```
`web/app/join/page.tsx`:
```tsx
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getViewer } from "@/lib/data/viewer";
import { gateFor } from "@/lib/auth/gate";
import { Card, MicroLabel } from "@/components/ui";
import { JoinForm } from "./JoinForm";

export const metadata: Metadata = { title: "Join your club" };

export default async function JoinPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  const viewer = await getViewer();
  const gate = gateFor(viewer);
  if (gate === "/login") redirect("/login?next=%2Fjoin");
  if (gate === null) redirect("/");
  const hasClubNoPaddler = Boolean(viewer.profile?.club_id) && !viewer.paddler;
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <header>
        <p className="text-3xl font-extrabold tracking-[-0.02em]">Join your club</p>
        <p className="mt-1 text-ink2">Signed in as {viewer.user?.email}.</p>
      </header>
      {hasClubNoPaddler && (
        <Card className="p-5">
          <MicroLabel>Not on the squad yet</MicroLabel>
          <p className="mt-2 text-ink2">You're in the club but not linked to a paddler. Enter the invite code again to claim your name, or ask your coach to add you to the squad.</p>
        </Card>
      )}
      <Card className="p-5">
        <JoinForm />
        {error && <p role="alert" className="mt-3 text-sm text-danger">{decodeURIComponent(error)}</p>}
      </Card>
      <form action="/auth/signout" method="post"><button type="submit" className="min-h-touch text-ink2 underline">Sign out</button></form>
    </main>
  );
}
```

- [ ] **Step 8: App layout with gate + tab bar**

`web/components/TabBar.tsx`:
```tsx
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
```
`web/app/(app)/layout.tsx`:
```tsx
import { redirect } from "next/navigation";
import { getViewer } from "@/lib/data/viewer";
import { gateFor } from "@/lib/auth/gate";
import { TabBar } from "@/components/TabBar";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const gate = gateFor(await getViewer());
  if (gate) redirect(gate);
  return (
    <>
      <div className="mx-auto max-w-md px-4 pb-24 pt-[max(1rem,env(safe-area-inset-top))]">{children}</div>
      <TabBar />
    </>
  );
}
```
Move the placeholder: `git mv web/app/page.tsx "web/app/(app)/page.tsx"`.

- [ ] **Step 9: Gate + manual check**
`pnpm typecheck && pnpm lint && pnpm test && pnpm build`. Then, with the local stack up and `seed_dev.sql` loaded: `pnpm dev` → open `http://localhost:3000/` → redirected to `/login` → dev sign-in as `lily@paddltir.dev` → lands on `/` showing the placeholder inside the tab bar. Sign out via `/profile` isn't built yet — `curl -X POST -i http://localhost:3000/auth/signout` returns 303 to `/login`. Record both in the report.

- [ ] **Step 10: Commit**
```bash
git add web && git commit -m "feat(web): Supabase SSR auth — magic-link login, dev sign-in, join by invite code, gated app layout"
```

---

### Task 3: Next event — race lineup with your seat, heat switcher, training availability, realtime

**Files:**
- Create: `web/lib/lineup.ts` (+`.test.ts`), `web/lib/event.ts` (+`.test.ts`), `web/lib/time.ts` (+`.test.ts`), `web/lib/data/sessions.ts`, `web/components/EventView.tsx`, `web/components/RaceCard.tsx`, `web/components/BoatDiagram.tsx`, `web/components/AvailabilityToggle.tsx`, `web/components/RealtimeRefresh.tsx`, `web/app/(app)/actions.ts`, `web/app/(app)/session/[id]/page.tsx`, `supabase/migrations/20260826000600_realtime.sql`, `supabase/tests/007_realtime.sql`
- Modify: `web/app/(app)/page.tsx` (replace placeholder)

**Interfaces:**
- Consumes: `getViewer()`, `createClient()`, `benchesIn/sectionOf/BENCHES` (Task 1), `SegmentedControl/Card/MicroLabel/Pill`.
- Produces: `type SeatRef = { bench: number; side: 'left' | 'right' }`; `type HeatView = { id: string; name: string; drummer: Named | null; sweep: Named | null; seats: SeatView[]; reserves: Named[] }` with `Named = { id: string; name: string }`, `SeatView = SeatRef & { paddler: Named | null }`; `type RaceView = { id: string; name: string; crewName: string; boatSize: BoatSize; benches: number; heats: HeatView[] }`; `type EventView = { id: string; kind: 'race_day'; title: string; startsAt: string; venue: string | null; races: RaceView[] } | { id: string; kind: 'training'; title: string; startsAt: string; venue: string | null; myAvailability: AvailabilityStatus | null; myNote: string | null }`; `AvailabilityStatus = 'in' | 'out' | 'maybe'`; `whereAmI(heat, paddlerId): { kind: 'seat'; bench; side } | { kind: 'drummer' } | { kind: 'sweep' } | { kind: 'reserve' } | { kind: 'none' }`; `benchRows(benches, seats): { bench; section; left; right }[]`; server action `setAvailability(sessionId: string, status: AvailabilityStatus): Promise<{ ok: true } | { ok: false; message: string }>`; `fetchUpcomingSessions(supabase, nowISO, limit)`, `fetchEvent(supabase, sessionId, paddlerId)`.

- [ ] **Step 1: Realtime publication migration + pgTAP** (spec §4 "Realtime subscriptions to heats/seats/sessions")

`supabase/migrations/20260826000600_realtime.sql`:
```sql
-- Paddler PWA subscribes to postgres_changes on these tables; RLS still filters every event per subscriber.
alter publication supabase_realtime add table sessions, heats, seats, heat_reserves, availability;
```
`supabase/tests/007_realtime.sql`:
```sql
begin;
select plan(2);
select is(
  (select count(*) from pg_publication_tables where pubname = 'supabase_realtime'
     and schemaname = 'public' and tablename in ('sessions','heats','seats','heat_reserves','availability')),
  5::bigint, 'the five paddler-facing tables are published to realtime');
select is(
  (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('erg_tests','paddlers','profiles','clubs')),
  0::bigint, 'private tables are not published');
select * from finish();
rollback;
```
Run from the repo root: `supabase db reset && supabase test db` → expect all suites pass including `007_realtime` (2 tests). Then reload demo data: `/opt/homebrew/opt/libpq/bin/psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql`. (`psql` is not on PATH in this environment — that libpq path works, as does `docker exec -i supabase_db_paddltir psql -U postgres -d postgres < supabase/seed_dev.sql`.) Regenerate types (no schema change, but keep the habit): `supabase gen types typescript --local --schema public > web/lib/db/database.types.ts`.

- [ ] **Step 2: Failing tests for the pure modules**

`web/lib/lineup.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { benchRows, whereAmI, type HeatView } from "./lineup";

const heat: HeatView = {
  id: "h1", name: "Heat 1",
  drummer: { id: "dee", name: "Dee Drummer" }, sweep: { id: "sam", name: "Sam Sweep" },
  seats: [
    { bench: 1, side: "left", paddler: { id: "lily", name: "Lily" } },
    { bench: 1, side: "right", paddler: { id: "nick", name: "Nick" } },
    { bench: 4, side: "right", paddler: { id: "owen", name: "Owen" } },
  ],
  reserves: [{ id: "hannah", name: "Hannah" }],
};

describe("whereAmI", () => {
  it("finds a seat", () => expect(whereAmI(heat, "lily")).toEqual({ kind: "seat", bench: 1, side: "left" }));
  it("drummer / sweep / reserve / none", () => {
    expect(whereAmI(heat, "dee")).toEqual({ kind: "drummer" });
    expect(whereAmI(heat, "sam")).toEqual({ kind: "sweep" });
    expect(whereAmI(heat, "hannah")).toEqual({ kind: "reserve" });
    expect(whereAmI(heat, "nobody")).toEqual({ kind: "none" });
  });
});

describe("benchRows", () => {
  it("emits one row per bench, bow to stern, with section labels and empty seats as null", () => {
    const rows = benchRows(10, heat.seats);
    expect(rows).toHaveLength(10);
    expect(rows[0]).toEqual({ bench: 1, section: "stroke", left: { id: "lily", name: "Lily" }, right: { id: "nick", name: "Nick" } });
    expect(rows[3]).toEqual({ bench: 4, section: "engine", left: null, right: { id: "owen", name: "Owen" } });
    expect(rows[9]).toEqual({ bench: 10, section: "sprint", left: null, right: null });
  });
  it("small boat has five rows", () => expect(benchRows(5, [])).toHaveLength(5));
});
```
`web/lib/event.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { paddlerIds, toRaceViews, type RaceRow } from "./event";

const rows: RaceRow[] = [{
  id: "r1", name: "Premier Mixed 200m", boat_size: "standard", sort_order: 1, crews: { name: "Premier Mixed" },
  heats: [
    { id: "h2", name: "Heat 2", sort_order: 2, drummer_id: null, sweep_id: null, seats: [], heat_reserves: [] },
    { id: "h1", name: "Heat 1", sort_order: 1, drummer_id: "dee", sweep_id: "sam",
      seats: [{ bench: 1, side: "left", paddler_id: "lily" }], heat_reserves: [{ paddler_id: "hannah" }] },
  ],
}];
const names = new Map([["lily", "Lily"], ["dee", "Dee Drummer"], ["sam", "Sam Sweep"], ["hannah", "Hannah"]]);

describe("toRaceViews", () => {
  it("orders heats, resolves names, sizes the boat", () => {
    const [race] = toRaceViews(rows, names);
    expect(race.crewName).toBe("Premier Mixed");
    expect(race.benches).toBe(10);
    expect(race.heats.map((h) => h.name)).toEqual(["Heat 1", "Heat 2"]);
    expect(race.heats[0].drummer).toEqual({ id: "dee", name: "Dee Drummer" });
    expect(race.heats[0].seats[0]).toEqual({ bench: 1, side: "left", paddler: { id: "lily", name: "Lily" } });
    expect(race.heats[0].reserves).toEqual([{ id: "hannah", name: "Hannah" }]);
  });
  it("collects every paddler id referenced by a race", () => {
    expect([...paddlerIds(rows)].sort()).toEqual(["dee", "hannah", "lily", "sam"]);
  });
  it("an unknown id renders as 'Unknown' rather than crashing", () => {
    const [race] = toRaceViews(rows, new Map());
    expect(race.heats[0].seats[0].paddler).toEqual({ id: "lily", name: "Unknown" });
  });
});
```
`web/lib/time.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { formatSessionDate, formatSessionTime, relativeDay } from "./time";

const iso = "2026-09-04T08:00:00+10:00"; // Fri 4 Sep 2026, 08:00 Sydney

describe("time (club time zone = Australia/Sydney)", () => {
  it("formats date and time", () => {
    expect(formatSessionDate(iso)).toBe("Fri 4 Sep");
    expect(formatSessionTime(iso)).toBe("8:00 am");
  });
  it("relative day labels", () => {
    expect(relativeDay(iso, "2026-09-04T01:00:00+10:00")).toBe("Today");
    expect(relativeDay(iso, "2026-09-03T23:00:00+10:00")).toBe("Tomorrow");
    expect(relativeDay(iso, "2026-08-26T09:00:00+10:00")).toBe("In 9 days");
  });
});
```
Run `pnpm test` — expect FAIL (modules missing).

- [ ] **Step 3: Implement the pure modules**

`web/lib/lineup.ts`:
```ts
import { sectionOf, type Section } from "./boat";

export type Named = { id: string; name: string };
export type Side = "left" | "right";
export type SeatRef = { bench: number; side: Side };
export type SeatView = SeatRef & { paddler: Named | null };
export type HeatView = { id: string; name: string; drummer: Named | null; sweep: Named | null; seats: SeatView[]; reserves: Named[] };

export type Placement =
  | { kind: "seat"; bench: number; side: Side }
  | { kind: "drummer" } | { kind: "sweep" } | { kind: "reserve" } | { kind: "none" };

export function whereAmI(heat: HeatView, paddlerId: string): Placement {
  const seat = heat.seats.find((s) => s.paddler?.id === paddlerId);
  if (seat) return { kind: "seat", bench: seat.bench, side: seat.side };
  if (heat.drummer?.id === paddlerId) return { kind: "drummer" };
  if (heat.sweep?.id === paddlerId) return { kind: "sweep" };
  if (heat.reserves.some((r) => r.id === paddlerId)) return { kind: "reserve" };
  return { kind: "none" };
}

export type BenchRow = { bench: number; section: Section; left: Named | null; right: Named | null };

/** Bow (bench 1) to stern; every bench present even when empty. */
export function benchRows(benches: number, seats: SeatView[]): BenchRow[] {
  const at = (bench: number, side: Side) => seats.find((s) => s.bench === bench && s.side === side)?.paddler ?? null;
  return Array.from({ length: benches }, (_, i) => {
    const bench = i + 1;
    return { bench, section: sectionOf(benches, bench), left: at(bench, "left"), right: at(bench, "right") };
  });
}

export function describePlacement(p: Placement): string {
  switch (p.kind) {
    case "seat": return `Bench ${p.bench} ${p.side}`;
    case "drummer": return "Drummer";
    case "sweep": return "Sweep";
    case "reserve": return "Reserve";
    case "none": return "Not in this heat";
  }
}
```
`web/lib/event.ts`:
```ts
import { BENCHES, type BoatSize } from "./boat";
import type { HeatView, Named, Side } from "./lineup";

/** Shape returned by the PostgREST embed in data/sessions.ts (kept explicit so the mapper is unit-testable). */
export type RaceRow = {
  id: string; name: string; boat_size: BoatSize; sort_order: number;
  crews: { name: string } | null;
  heats: {
    id: string; name: string; sort_order: number; drummer_id: string | null; sweep_id: string | null;
    seats: { bench: number; side: Side; paddler_id: string }[];
    heat_reserves: { paddler_id: string }[];
  }[];
};

export type RaceView = { id: string; name: string; crewName: string; boatSize: BoatSize; benches: number; heats: HeatView[] };
export type AvailabilityStatus = "in" | "out" | "maybe";
export type EventView =
  | { id: string; kind: "race_day"; title: string; startsAt: string; venue: string | null; races: RaceView[] }
  | { id: string; kind: "training"; title: string; startsAt: string; venue: string | null; myAvailability: AvailabilityStatus | null; myNote: string | null };

export function paddlerIds(rows: RaceRow[]): Set<string> {
  const ids = new Set<string>();
  for (const r of rows) for (const h of r.heats) {
    if (h.drummer_id) ids.add(h.drummer_id);
    if (h.sweep_id) ids.add(h.sweep_id);
    h.seats.forEach((s) => ids.add(s.paddler_id));
    h.heat_reserves.forEach((x) => ids.add(x.paddler_id));
  }
  return ids;
}

export function toRaceViews(rows: RaceRow[], names: Map<string, string>): RaceView[] {
  const named = (id: string | null): Named | null => (id ? { id, name: names.get(id) ?? "Unknown" } : null);
  return [...rows].sort((a, b) => a.sort_order - b.sort_order).map((r) => ({
    id: r.id, name: r.name, crewName: r.crews?.name ?? "Crew", boatSize: r.boat_size, benches: BENCHES[r.boat_size],
    heats: [...r.heats].sort((a, b) => a.sort_order - b.sort_order).map((h) => ({
      id: h.id, name: h.name, drummer: named(h.drummer_id), sweep: named(h.sweep_id),
      seats: h.seats.map((s) => ({ bench: s.bench, side: s.side, paddler: named(s.paddler_id) })),
      reserves: h.heat_reserves.map((x) => named(x.paddler_id)!),
    })),
  }));
}
```
`web/lib/time.ts`:
```ts
/** v1 assumption: one club, one time zone. Rendered identically on server and client, so no hydration drift. */
export const CLUB_TZ = "Australia/Sydney";
// en-US parts are reassembled by hand so the output is ICU-version-independent ("Sep", never "Sept").
const date = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, weekday: "short", day: "numeric", month: "short" });
const time = new Intl.DateTimeFormat("en-US", { timeZone: CLUB_TZ, hour: "numeric", minute: "2-digit", hour12: true });
const ymd = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" });

const part = (parts: Intl.DateTimeFormatPart[], type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? "";

/** "Fri 4 Sep" — Australian day-month order. */
export function formatSessionDate(iso: string): string {
  const p = date.formatToParts(new Date(iso));
  return `${part(p, "weekday")} ${part(p, "day")} ${part(p, "month")}`;
}
/** "8:00 am" */
export function formatSessionTime(iso: string): string {
  const p = time.formatToParts(new Date(iso));
  return `${part(p, "hour")}:${part(p, "minute")} ${part(p, "dayPeriod").toLowerCase()}`;
}

export function relativeDay(iso: string, nowISO: string): string {
  const days = Math.round((Date.parse(ymd.format(new Date(iso))) - Date.parse(ymd.format(new Date(nowISO)))) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days < 0) return `${-days} day${days === -1 ? "" : "s"} ago`;
  return `In ${days} days`;
}
```
Run `pnpm test` — expect PASS.

- [ ] **Step 4: Queries** — `web/lib/data/sessions.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/db/database.types";
import { paddlerIds, toRaceViews, type EventView, type RaceRow } from "@/lib/event";

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
    const { data: a } = await supabase.from("availability").select("status, note").eq("session_id", s.id).eq("paddler_id", paddlerId).maybeSingle();
    return { ...base, kind: "training", myAvailability: a?.status ?? null, myNote: a?.note ?? null };
  }
  const { data: races, error: rErr } = await supabase.from("races").select(RACE_SELECT).eq("session_id", s.id).order("sort_order");
  if (rErr) throw rErr;
  const rows = (races ?? []) as unknown as RaceRow[];
  const ids = [...paddlerIds(rows)];
  const names = new Map<string, string>();
  if (ids.length) {
    const { data: people } = await supabase.from("paddlers_public").select("id, name").in("id", ids);
    people?.forEach((p) => { if (p.id && p.name) names.set(p.id, p.name); });
  }
  return { ...base, kind: "race_day", races: toRaceViews(rows, names) };
}
```

- [ ] **Step 5: Server action** — `web/app/(app)/actions.ts`:
```ts
"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import type { AvailabilityStatus } from "@/lib/event";

const STATUSES: AvailabilityStatus[] = ["in", "out", "maybe"];

export async function setAvailability(sessionId: string, status: AvailabilityStatus): Promise<{ ok: true } | { ok: false; message: string }> {
  if (!STATUSES.includes(status)) return { ok: false, message: "Invalid status" };
  const viewer = await getViewer();
  if (!viewer.paddler) return { ok: false, message: "You're not linked to a paddler yet." };
  const supabase = await createClient();
  const { error } = await supabase
    .from("availability")
    .upsert({ session_id: sessionId, paddler_id: viewer.paddler.id, status }, { onConflict: "session_id,paddler_id" });
  if (error) return { ok: false, message: "Couldn't save — try again." };
  revalidatePath("/"); revalidatePath(`/session/${sessionId}`); revalidatePath("/availability");
  return { ok: true };
}
```

- [ ] **Step 6: Components**

`web/components/BoatDiagram.tsx` (server-renderable, no state):
```tsx
import { benchRows, type HeatView, type Named } from "@/lib/lineup";
import { MicroLabel } from "@/components/ui";

function Tile({ p, me, label }: { p: Named | null; me: string; label: string }) {
  const mine = p?.id === me;
  return (
    <div
      aria-label={`${label}: ${p ? p.name : "empty"}${mine ? " (you)" : ""}`}
      className={`flex min-h-touch items-center justify-center rounded-sm border px-2 text-center text-sm leading-tight ${
        p ? (mine ? "border-accent bg-accent/10 font-semibold text-accent" : "border-border bg-surface text-ink") : "border-dashed border-border bg-surface2 text-ink3"
      }`}
    >
      {p ? p.name : "—"}
    </div>
  );
}

export function BoatDiagram({ heat, benches, me }: { heat: HeatView; benches: number; me: string }) {
  const rows = benchRows(benches, heat.seats);
  return (
    <div role="table" aria-label={`${heat.name} lineup, bow to stern`} className="flex flex-col gap-1.5">
      <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2"><div /><Tile p={heat.drummer} me={me} label="Drummer" /><div /></div>
      {rows.map((r) => (
        <div key={r.bench} role="row" className="grid grid-cols-[1fr_3.25rem_1fr] items-center gap-2">
          <Tile p={r.left} me={me} label={`Bench ${r.bench} left`} />
          <div className="flex flex-col items-center gap-0.5">
            <span className="text-xs font-bold text-ink3">{r.bench}</span>
            <MicroLabel className="text-[9px]">{r.section}</MicroLabel>
          </div>
          <Tile p={r.right} me={me} label={`Bench ${r.bench} right`} />
        </div>
      ))}
      <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2"><div /><Tile p={heat.sweep} me={me} label="Sweep" /><div /></div>
      {heat.reserves.length > 0 && (
        <p className="mt-2 text-sm text-ink2"><span className="micro mr-2">Reserves</span>{heat.reserves.map((r) => r.name).join(" · ")}</p>
      )}
    </div>
  );
}
```
`web/components/RaceCard.tsx`:
```tsx
"use client";
import { useState } from "react";
import type { RaceView } from "@/lib/event";
import { describePlacement, whereAmI } from "@/lib/lineup";
import { BoatDiagram } from "./BoatDiagram";
import { Card, MicroLabel, Pill } from "./ui";

export function RaceCard({ race, me }: { race: RaceView; me: string }) {
  const [heatId, setHeatId] = useState(race.heats[0]?.id ?? null);
  const heat = race.heats.find((h) => h.id === heatId) ?? null;
  const placement = heat ? whereAmI(heat, me) : null;
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <MicroLabel>{race.crewName}</MicroLabel>
          <h2 className="mt-1 text-lg font-bold tracking-tight">{race.name}</h2>
        </div>
        {placement && <Pill tone={placement.kind === "none" ? "neutral" : "accent"}>{describePlacement(placement)}</Pill>}
      </div>
      {race.heats.length > 1 && (
        <div role="tablist" aria-label="Heats" className="mt-3 flex gap-1 rounded-ctl border border-border bg-surface2 p-1">
          {race.heats.map((h) => (
            <button key={h.id} role="tab" aria-selected={h.id === heatId} onClick={() => setHeatId(h.id)}
              className={`min-h-touch flex-1 rounded-sm text-sm font-semibold ${h.id === heatId ? "bg-surface text-ink shadow-sm" : "text-ink2"}`}>
              {h.name}
            </button>
          ))}
        </div>
      )}
      <div className="mt-4">
        {heat ? <BoatDiagram heat={heat} benches={race.benches} me={me} /> : <p className="text-ink2">No heats yet — your coach hasn't set a lineup.</p>}
      </div>
    </Card>
  );
}
```
`web/components/AvailabilityToggle.tsx`:
```tsx
"use client";
import { useState, useTransition } from "react";
import { setAvailability } from "@/app/(app)/actions";
import type { AvailabilityStatus } from "@/lib/event";
import { SegmentedControl } from "./ui";

const OPTIONS = [{ value: "in", label: "In" }, { value: "maybe", label: "Maybe" }, { value: "out", label: "Out" }] as const;

export function AvailabilityToggle({ sessionId, value, label }: { sessionId: string; value: AvailabilityStatus | null; label: string }) {
  const [current, setCurrent] = useState(value);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <div>
      <SegmentedControl label={label} options={[...OPTIONS]} value={current} disabled={pending}
        onChange={(next) => { const prev = current; setCurrent(next); setError(null);
          start(async () => { const r = await setAvailability(sessionId, next); if (!r.ok) { setCurrent(prev); setError(r.message); } }); }} />
      {error && <p role="alert" className="mt-2 text-sm text-danger">{error}</p>}
    </div>
  );
}
```
`web/components/RealtimeRefresh.tsx`:
```tsx
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
```
`web/components/EventView.tsx`:
```tsx
import type { EventView as Event } from "@/lib/event";
import { formatSessionDate, formatSessionTime, relativeDay } from "@/lib/time";
import { Card, MicroLabel } from "./ui";
import { RaceCard } from "./RaceCard";
import { AvailabilityToggle } from "./AvailabilityToggle";

export function EventView({ event, me, nowISO }: { event: Event; me: string; nowISO: string }) {
  return (
    <div className="flex flex-col gap-4">
      <header>
        <MicroLabel>{relativeDay(event.startsAt, nowISO)} · {formatSessionDate(event.startsAt)} · {formatSessionTime(event.startsAt)}</MicroLabel>
        <h1 className="mt-1 text-2xl font-extrabold tracking-[-0.02em]">{event.title}</h1>
        {event.venue && <p className="text-ink2">{event.venue}</p>}
      </header>
      {event.kind === "training" ? (
        <Card className="p-4">
          <MicroLabel>Are you in?</MicroLabel>
          <div className="mt-3"><AvailabilityToggle sessionId={event.id} value={event.myAvailability} label={`Availability for ${event.title}`} /></div>
          {event.myNote && <p className="mt-2 text-sm text-ink2">Note: {event.myNote}</p>}
        </Card>
      ) : event.races.length === 0 ? (
        <Card className="p-4"><p className="text-ink2">No races entered yet.</p></Card>
      ) : (
        event.races.map((r) => <RaceCard key={r.id} race={r} me={me} />)
      )}
    </div>
  );
}
```

- [ ] **Step 7: Pages**

`web/app/(app)/page.tsx`:
```tsx
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { fetchEvent, fetchUpcomingSessions } from "@/lib/data/sessions";
import { formatSessionDate, formatSessionTime } from "@/lib/time";
import { EventView } from "@/components/EventView";
import { RealtimeRefresh } from "@/components/RealtimeRefresh";
import { Card, MicroLabel, Pill } from "@/components/ui";

export default async function NextEventPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const nowISO = new Date().toISOString();
  const upcoming = await fetchUpcomingSessions(supabase, nowISO);
  const next = upcoming[0] ? await fetchEvent(supabase, upcoming[0].id, viewer.paddler!.id) : null;
  return (
    <main className="flex flex-col gap-6">
      <RealtimeRefresh />
      {next ? <EventView event={next} me={viewer.paddler!.id} nowISO={nowISO} /> : (
        <Card className="p-5"><MicroLabel>Nothing scheduled</MicroLabel><p className="mt-2 text-ink2">No upcoming sessions — check back when your coach adds one.</p></Card>
      )}
      {upcoming.length > 1 && (
        <section>
          <MicroLabel>Coming up</MicroLabel>
          <ul className="mt-2 flex flex-col gap-2">
            {upcoming.slice(1).map((s) => (
              <li key={s.id}>
                <Link href={`/session/${s.id}`} className="flex min-h-touch items-center justify-between rounded-card border border-border bg-surface px-4 py-3">
                  <span><span className="font-semibold">{s.title}</span><span className="block text-sm text-ink2">{formatSessionDate(s.startsAt)} · {formatSessionTime(s.startsAt)}</span></span>
                  <Pill tone={s.kind === "race_day" ? "accent" : "neutral"}>{s.kind === "race_day" ? "Race day" : "Training"}</Pill>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
```
`web/app/(app)/session/[id]/page.tsx`:
```tsx
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
```
(`viewer.paddler!` is safe: the `(app)` layout redirected anyone without one.)

- [ ] **Step 8: Gate + manual check**
`pnpm typecheck && pnpm lint && pnpm test && pnpm build`. Then `pnpm dev`, sign in as Lily: `/` shows "Tuesday training" with the toggle on **In**; tap **Maybe** → persists across reload; "Coming up" lists "Sydney Regatta" → open it: Heat 1 shows Lily highlighted at Bench 1 left with the pill "Bench 1 left", Dee Drummer at the bow, Sam Sweep at the stern, reserves Hannah · Oscar; "Final" tab shows an empty hull. Realtime: in another terminal run `/opt/homebrew/opt/libpq/bin/psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "update seats set bench = 5 where paddler_id = (select id from paddlers where name = 'Lily')"` → the open page updates without a reload (pill becomes "Bench 5 left"); revert with `bench = 1`. Record what you observed.

- [ ] **Step 9: Commit**
```bash
git add web supabase/migrations/20260826000600_realtime.sql supabase/tests/007_realtime.sql
git commit -m "feat(web): next event — race boat diagram with your seat, heat switcher, training availability, realtime refresh"
```

---

### Task 4: `/availability`, `/erg`, `/profile`

**Files:**
- Create: `web/lib/erg.ts` (+`.test.ts`), `web/lib/sparkline.ts` (+`.test.ts`), `web/components/Sparkline.tsx`, `web/components/ErgForm.tsx`, `web/app/(app)/availability/page.tsx`, `web/app/(app)/erg/page.tsx`, `web/app/(app)/profile/page.tsx`, `web/app/(app)/profile/DisplayNameForm.tsx`
- Modify: `web/app/(app)/actions.ts` (add `submitErg`, `updateDisplayName`)

**Interfaces:**
- Consumes: `setAvailability`, `AvailabilityToggle`, `getViewer`, `createClient`, `fetchUpcomingSessions`, `formatSessionDate/Time`.
- Produces: `parseErgSubmission(input: { metres: string; testedAt: string }, todayYMD: string): { ok: true; metres: number; testedAt: string } | { ok: false; message: string }`; `polylinePoints(values: number[], width: number, height: number, pad?: number): string`; actions `submitErg(prev, formData): Promise<ErgState>`, `updateDisplayName(formData): Promise<void>`.

- [ ] **Step 1: Failing tests**

`web/lib/erg.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { parseErgSubmission } from "./erg";

describe("parseErgSubmission", () => {
  it("accepts whole metres 1–2000 and a date not in the future", () => {
    expect(parseErgSubmission({ metres: "545", testedAt: "2026-08-25" }, "2026-08-26")).toEqual({ ok: true, metres: 545, testedAt: "2026-08-25" });
    expect(parseErgSubmission({ metres: "2000", testedAt: "2026-08-26" }, "2026-08-26")).toEqual({ ok: true, metres: 2000, testedAt: "2026-08-26" });
  });
  it("rejects out-of-range, non-integer, empty, future", () => {
    expect(parseErgSubmission({ metres: "0", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "2001", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "12.5", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "", testedAt: "2026-08-26" }, "2026-08-26")).toMatchObject({ ok: false });
    expect(parseErgSubmission({ metres: "500", testedAt: "2026-08-27" }, "2026-08-26")).toMatchObject({ ok: false, message: expect.stringContaining("future") });
    expect(parseErgSubmission({ metres: "500", testedAt: "not-a-date" }, "2026-08-26")).toMatchObject({ ok: false });
  });
});
```
`web/lib/sparkline.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { polylinePoints } from "./sparkline";

describe("polylinePoints", () => {
  it("maps values left→right, min at the bottom, max at the top", () => {
    expect(polylinePoints([0, 10], 100, 20, 0)).toBe("0,20 100,0");
    expect(polylinePoints([5, 0, 10], 100, 20, 0)).toBe("0,10 50,20 100,0");
  });
  it("a flat series draws a mid-height line; fewer than two points draws nothing", () => {
    expect(polylinePoints([7, 7, 7], 100, 20, 0)).toBe("0,10 50,10 100,10");
    expect(polylinePoints([7], 100, 20)).toBe("");
    expect(polylinePoints([], 100, 20)).toBe("");
  });
});
```
Run `pnpm test` — expect FAIL.

- [ ] **Step 2: Implement**

`web/lib/erg.ts`:
```ts
export type ErgSubmission = { ok: true; metres: number; testedAt: string } | { ok: false; message: string };
const YMD = /^\d{4}-\d{2}-\d{2}$/;

/** Mirrors the DB checks: metres integer 1–2000; tested_at a real date, today or earlier (club time zone). */
export function parseErgSubmission(input: { metres: string; testedAt: string }, todayYMD: string): ErgSubmission {
  const metres = Number(input.metres);
  if (input.metres.trim() === "" || !Number.isInteger(metres) || metres < 1 || metres > 2000) return { ok: false, message: "Metres must be a whole number from 1 to 2000." };
  if (!YMD.test(input.testedAt) || Number.isNaN(Date.parse(input.testedAt))) return { ok: false, message: "Pick the date of the test." };
  if (input.testedAt > todayYMD) return { ok: false, message: "That date is in the future." };
  return { ok: true, metres, testedAt: input.testedAt };
}
```
`web/lib/sparkline.ts`:
```ts
/** SVG polyline `points` for a series, oldest first. Empty string when there is nothing to draw. */
export function polylinePoints(values: number[], width: number, height: number, pad = 2): string {
  if (values.length < 2) return "";
  const min = Math.min(...values), max = Math.max(...values);
  const span = max - min;
  const innerH = height - pad * 2;
  const x = (i: number) => (i / (values.length - 1)) * width;
  const y = (v: number) => (span === 0 ? height / 2 : pad + innerH - ((v - min) / span) * innerH);
  return values.map((v, i) => `${round(x(i))},${round(y(v))}`).join(" ");
}
const round = (n: number) => String(Math.round(n * 100) / 100);
```
`web/components/Sparkline.tsx`:
```tsx
import { polylinePoints } from "@/lib/sparkline";

export function Sparkline({ values, label }: { values: number[]; label: string }) {
  const points = polylinePoints(values, 160, 40);
  if (!points) return <p className="text-sm text-ink3">Log two tests to see a trend.</p>;
  return (
    <svg viewBox="0 0 160 40" width="100%" height="40" role="img" aria-label={label} className="overflow-visible">
      <polyline points={points} fill="none" stroke="var(--color-accent)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}
```
Add to `web/app/(app)/actions.ts`:
```ts
import { parseErgSubmission } from "@/lib/erg";
import { CLUB_TZ } from "@/lib/time";

export type ErgState = { status: "idle" } | { status: "saved"; metres: number } | { status: "error"; message: string };

export async function submitErg(_prev: ErgState, formData: FormData): Promise<ErgState> {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: CLUB_TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  const parsed = parseErgSubmission({ metres: String(formData.get("metres") ?? ""), testedAt: String(formData.get("tested_at") ?? "") }, today);
  if (!parsed.ok) return { status: "error", message: parsed.message };
  const viewer = await getViewer();
  if (!viewer.user || !viewer.paddler) return { status: "error", message: "You're not linked to a paddler yet." };
  const supabase = await createClient();
  const { error } = await supabase.from("erg_tests").insert({
    paddler_id: viewer.paddler.id, metres: parsed.metres, tested_at: parsed.testedAt, source: "self", recorded_by: viewer.user.id,
  });
  if (error) return { status: "error", message: "Couldn't save — try again." };
  revalidatePath("/erg");
  return { status: "saved", metres: parsed.metres };
}

export async function updateDisplayName(formData: FormData): Promise<void> {
  const name = String(formData.get("display_name") ?? "").trim().slice(0, 80);
  const viewer = await getViewer();
  if (!viewer.user || name.length === 0) return;
  const supabase = await createClient();
  await supabase.from("profiles").update({ display_name: name }).eq("id", viewer.user.id);
  revalidatePath("/profile");
}
```

- [ ] **Step 3: Pages**

`web/app/(app)/availability/page.tsx`:
```tsx
import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { fetchUpcomingSessions } from "@/lib/data/sessions";
import { formatSessionDate, formatSessionTime } from "@/lib/time";
import { AvailabilityToggle } from "@/components/AvailabilityToggle";
import { RealtimeRefresh } from "@/components/RealtimeRefresh";
import { Card, MicroLabel, Pill } from "@/components/ui";
import type { AvailabilityStatus } from "@/lib/event";

export const metadata: Metadata = { title: "Availability" };

export default async function AvailabilityPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const sessions = await fetchUpcomingSessions(supabase, new Date().toISOString(), 20);
  const { data: mine } = await supabase.from("availability").select("session_id, status").eq("paddler_id", viewer.paddler!.id);
  const status = new Map<string, AvailabilityStatus>((mine ?? []).map((a) => [a.session_id, a.status]));
  return (
    <main className="flex flex-col gap-4">
      <RealtimeRefresh />
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Availability</h1>
      {sessions.length === 0 && <Card className="p-5"><p className="text-ink2">No upcoming sessions.</p></Card>}
      {sessions.map((s) => (
        <Card key={s.id} className="p-4">
          <div className="flex items-start justify-between gap-3">
            <div><MicroLabel>{formatSessionDate(s.startsAt)} · {formatSessionTime(s.startsAt)}</MicroLabel><h2 className="mt-1 font-bold">{s.title}</h2></div>
            <Pill tone={s.kind === "race_day" ? "accent" : "neutral"}>{s.kind === "race_day" ? "Race day" : "Training"}</Pill>
          </div>
          <div className="mt-3"><AvailabilityToggle sessionId={s.id} value={status.get(s.id) ?? null} label={`Availability for ${s.title}`} /></div>
        </Card>
      ))}
    </main>
  );
}
```
`web/components/ErgForm.tsx`:
```tsx
"use client";
import { useActionState } from "react";
import { submitErg, type ErgState } from "@/app/(app)/actions";
import { MicroLabel, PrimaryButton } from "./ui";

export function ErgForm({ today }: { today: string }) {
  const [state, action, pending] = useActionState<ErgState, FormData>(submitErg, { status: "idle" });
  return (
    <form action={action} className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3">
        <label className="flex flex-col gap-1"><MicroLabel>Metres (1 min)</MicroLabel>
          <input name="metres" type="number" inputMode="numeric" min={1} max={2000} step={1} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 text-lg font-semibold focus:border-accent focus:outline-none" /></label>
        <label className="flex flex-col gap-1"><MicroLabel>Date</MicroLabel>
          <input name="tested_at" type="date" max={today} defaultValue={today} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 focus:border-accent focus:outline-none" /></label>
      </div>
      {state.status === "error" && <p role="alert" className="text-sm text-danger">{state.message}</p>}
      {state.status === "saved" && <p role="status" className="text-sm text-good">Saved {state.metres} m.</p>}
      <PrimaryButton type="submit" disabled={pending}>{pending ? "Saving…" : "Log erg test"}</PrimaryButton>
    </form>
  );
}
```
`web/app/(app)/erg/page.tsx`:
```tsx
import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { CLUB_TZ } from "@/lib/time";
import { ErgForm } from "@/components/ErgForm";
import { Sparkline } from "@/components/Sparkline";
import { Card, MicroLabel, Pill } from "@/components/ui";

export const metadata: Metadata = { title: "Erg" };

export default async function ErgPage() {
  const viewer = await getViewer();
  const supabase = await createClient();
  const { data: tests } = await supabase.from("erg_tests").select("id, tested_at, metres, source").eq("paddler_id", viewer.paddler!.id).order("tested_at", { ascending: false }).order("created_at", { ascending: false }).limit(50);
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
```
`web/app/(app)/profile/DisplayNameForm.tsx`:
```tsx
"use client";
import { updateDisplayName } from "@/app/(app)/actions";
import { MicroLabel, PrimaryButton } from "@/components/ui";

export function DisplayNameForm({ initial }: { initial: string }) {
  return (
    <form action={updateDisplayName} className="flex items-end gap-2">
      <label className="flex flex-1 flex-col gap-1"><MicroLabel>Display name</MicroLabel>
        <input name="display_name" defaultValue={initial} maxLength={80} required className="min-h-touch rounded-ctl border border-border bg-surface px-3 focus:border-accent focus:outline-none" /></label>
      <PrimaryButton type="submit">Save</PrimaryButton>
    </form>
  );
}
```
`web/app/(app)/profile/page.tsx`:
```tsx
import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { getViewer } from "@/lib/data/viewer";
import { Card, MicroLabel } from "@/components/ui";
import { DisplayNameForm } from "./DisplayNameForm";

export const metadata: Metadata = { title: "Profile" };

const SIDE: Record<string, string> = { left: "Left", right: "Right", either: "Either" };
const PREF: Record<string, string> = { stroke: "Stroke", pace: "Pace", engine: "Engine", sprint: "Sprint", none: "No preference" };
const ROLE: Record<string, string> = { paddler: "Paddler", drummer: "Drummer", sweep: "Sweep" };

export default async function ProfilePage() {
  const viewer = await getViewer();
  const p = viewer.paddler!;
  const supabase = await createClient();
  const { data: club } = await supabase.from("clubs").select("name").eq("id", p.club_id).maybeSingle();
  const rows: [string, string][] = [
    ["Name", p.name], ["Weight", `${Number(p.weight_kg).toFixed(1)} kg`], ["Gender", p.gender === "female" ? "Female" : "Male"],
    ["Preferred side", SIDE[p.preferred_side]], ["Seat preference", PREF[p.seat_preference]], ["Role", ROLE[p.boat_role]],
  ];
  return (
    <main className="flex flex-col gap-4">
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Profile</h1>
      <Card className="p-4"><MicroLabel>{club?.name ?? "Your club"}</MicroLabel><div className="mt-3"><DisplayNameForm initial={viewer.profile?.display_name ?? p.name} /></div>
        <p className="mt-2 text-sm text-ink3">Signed in as {viewer.user?.email}</p></Card>
      <Card>
        <dl className="divide-y divide-border">
          {rows.map(([k, v]) => (<div key={k} className="flex min-h-touch items-center justify-between px-4 py-2"><dt className="text-sm text-ink2">{k}</dt><dd className="font-semibold">{v}</dd></div>))}
        </dl>
        <p className="border-t border-border px-4 py-3 text-sm text-ink3">Ask your coach to change these — they're managed from the coach app.</p>
      </Card>
      <form action="/auth/signout" method="post"><button type="submit" className="min-h-touch w-full rounded-ctl border border-border bg-surface font-semibold text-danger">Sign out</button></form>
    </main>
  );
}
```

- [ ] **Step 4: Gate + manual check** — `pnpm typecheck && pnpm lint && pnpm test && pnpm build`; `pnpm dev` as Lily: `/availability` lists both seeded sessions with her statuses; `/erg` shows two coach tests and a sparkline, logging `555` today adds a "Self" row and the trend updates; `/profile` shows Lily · 58.0 kg · Female · Left · Stroke · Paddler, renaming the display name persists, **Sign out** returns to `/login`.

- [ ] **Step 5: Commit** — `git add web && git commit -m "feat(web): availability list, erg log with sparkline, profile"`

---

### Task 5: PWA — manifest, icons, service worker, install nudge, offline page

**Files:**
- Create: `web/app/manifest.ts`, `web/app/icon.svg`, `web/app/offline/page.tsx`, `web/public/sw.js`, `web/public/icons/{icon-192,icon-512,maskable-512,apple-touch-icon}.png` (generated), `web/scripts/make-icons.mjs`, `web/scripts/icon.svg`, `web/scripts/maskable.svg`, `web/components/RegisterServiceWorker.tsx`, `web/components/InstallNudge.tsx`, `web/lib/install.ts` (+`.test.ts`)
- Modify: `web/app/layout.tsx` (mount the two client components; apple-touch-icon link via metadata), `web/next.config.ts` (headers for `/sw.js`)

**Interfaces:**
- Produces: `shouldShowNudge(input: { standalone: boolean; dismissed: boolean; isIOS: boolean; canPrompt: boolean }): 'ios' | 'prompt' | 'none'`.

- [ ] **Step 1: Failing test** — `web/lib/install.test.ts`:
```ts
import { describe, expect, it } from "vitest";
import { shouldShowNudge } from "./install";

describe("shouldShowNudge", () => {
  it("never when already installed or already dismissed", () => {
    expect(shouldShowNudge({ standalone: true, dismissed: false, isIOS: true, canPrompt: true })).toBe("none");
    expect(shouldShowNudge({ standalone: false, dismissed: true, isIOS: false, canPrompt: true })).toBe("none");
  });
  it("iOS gets the Share → Add to Home Screen instructions", () => {
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: true, canPrompt: false })).toBe("ios");
  });
  it("browsers that fired beforeinstallprompt get the install button; others nothing", () => {
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: false, canPrompt: true })).toBe("prompt");
    expect(shouldShowNudge({ standalone: false, dismissed: false, isIOS: false, canPrompt: false })).toBe("none");
  });
});
```
Run → FAIL. Implement `web/lib/install.ts`:
```ts
export type NudgeKind = "ios" | "prompt" | "none";
export function shouldShowNudge(i: { standalone: boolean; dismissed: boolean; isIOS: boolean; canPrompt: boolean }): NudgeKind {
  if (i.standalone || i.dismissed) return "none";
  if (i.isIOS) return "ios";
  return i.canPrompt ? "prompt" : "none";
}
```
Run → PASS.

- [ ] **Step 2: Icons** — `web/scripts/icon.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="112" fill="#0F172A"/>
  <path fill="#FAFAFA" fill-rule="evenodd" d="M156 392V120h116c64 0 106 40 106 98s-42 98-106 98h-56v76zm60-136h50c30 0 50-18 50-46s-20-46-50-46h-50z"/>
  <rect x="156" y="408" width="222" height="18" rx="9" fill="#0D7377"/>
</svg>
```
`web/scripts/maskable.svg` (same marks scaled into the 80% safe zone):
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#0F172A"/>
  <g transform="translate(51.2 51.2) scale(0.8)">
    <path fill="#FAFAFA" fill-rule="evenodd" d="M156 392V120h116c64 0 106 40 106 98s-42 98-106 98h-56v76zm60-136h50c30 0 50-18 50-46s-20-46-50-46h-50z"/>
    <rect x="156" y="408" width="222" height="18" rx="9" fill="#0D7377"/>
  </g>
</svg>
```
`web/scripts/make-icons.mjs`:
```js
import sharp from "sharp";
import { mkdir } from "node:fs/promises";
const out = new URL("../public/icons/", import.meta.url);
await mkdir(out, { recursive: true });
const jobs = [
  ["icon.svg", "icon-192.png", 192], ["icon.svg", "icon-512.png", 512],
  ["icon.svg", "apple-touch-icon.png", 180], ["maskable.svg", "maskable-512.png", 512],
];
for (const [src, name, size] of jobs) {
  await sharp(new URL(src, import.meta.url).pathname).resize(size, size).png().toFile(new URL(name, out).pathname);
  console.log("wrote", name);
}
```
```bash
cd web && pnpm add -D sharp && node scripts/make-icons.mjs && cp scripts/icon.svg app/icon.svg && ls -la public/icons
```
Add `"icons": "node scripts/make-icons.mjs"` to `package.json` scripts. Commit the PNGs (they are the manifest's contract).

- [ ] **Step 3: Manifest + offline page**

`web/app/manifest.ts`:
```ts
import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Paddltir", short_name: "Paddltir", description: "Your crew, your seat, your next race.",
    start_url: "/", scope: "/", display: "standalone", orientation: "portrait",
    background_color: "#FAFAFA", theme_color: "#FAFAFA",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
```
`web/app/offline/page.tsx`:
```tsx
export const metadata = { title: "Offline" };
export default function OfflinePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-3 p-6">
      <p className="micro">You're offline</p>
      <h1 className="text-2xl font-extrabold tracking-[-0.02em]">Paddltir needs a connection</h1>
      <p className="text-ink2">Lineups and availability come straight from your club's live data. Reconnect and pull to refresh.</p>
    </main>
  );
}
```

- [ ] **Step 4: Service worker** — `web/public/sw.js`:
```js
/* Paddltir service worker: app-shell caching only. Data (Supabase) is never cached — it is per-user and authorised. */
const VERSION = "paddltir-v1";
const OFFLINE_URL = "/offline";

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((cache) => cache.addAll([OFFLINE_URL])).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return; // Supabase & friends: network only
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(OFFLINE_URL)));
    return;
  }
  if (url.pathname.startsWith("/_next/static/") || url.pathname.startsWith("/icons/")) {
    event.respondWith(
      caches.match(request).then((hit) => hit || fetch(request).then((res) => {
        const copy = res.clone();
        caches.open(VERSION).then((cache) => cache.put(request, copy));
        return res;
      })),
    );
  }
});
```
`web/next.config.ts`:
```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: "/sw.js", headers: [{ key: "Cache-Control", value: "no-cache" }, { key: "Service-Worker-Allowed", value: "/" }] }];
  },
};
export default nextConfig;
```

- [ ] **Step 5: Client components + layout**

`web/components/RegisterServiceWorker.tsx`:
```tsx
"use client";
import { useEffect } from "react";

export function RegisterServiceWorker() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "production" || !("serviceWorker" in navigator)) return;
    navigator.serviceWorker.register("/sw.js").catch(() => { /* offline shell is a nicety, never a blocker */ });
  }, []);
  return null;
}
```
`web/components/InstallNudge.tsx`:
```tsx
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
    setKind(shouldShowNudge({ standalone, dismissed, isIOS, canPrompt: false }));
    const onPrompt = (e: Event) => { e.preventDefault(); setDeferred(e as BeforeInstallPromptEvent); setKind(shouldShowNudge({ standalone, dismissed, isIOS, canPrompt: true })); };
    window.addEventListener("beforeinstallprompt", onPrompt);
    return () => window.removeEventListener("beforeinstallprompt", onPrompt);
  }, []);

  const dismiss = () => { try { localStorage.setItem(KEY, "1"); } catch { /* ignore */ } setKind("none"); };
  if (kind === "none") return null;
  return (
    <aside role="dialog" aria-label="Install Paddltir" className="fixed inset-x-4 bottom-20 z-10 mx-auto max-w-md rounded-card border border-border bg-surface p-4 shadow-lg">
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
```
In `web/app/layout.tsx`, add `icons: { apple: "/icons/apple-touch-icon.png" }` to `metadata`, and render `<RegisterServiceWorker />` and `<InstallNudge />` inside `<body>` after `{children}`.

- [ ] **Step 6: Gate + verification**
`pnpm typecheck && pnpm lint && pnpm test && pnpm build && pnpm start &` then:
`curl -s http://localhost:3000/manifest.webmanifest | head -c 300` (JSON with `"name":"Paddltir"`), `curl -sI http://localhost:3000/sw.js | grep -iE "cache-control|service-worker-allowed"`, `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/icons/icon-512.png` (200), `curl -s http://localhost:3000/offline | grep -c "Paddltir needs a connection"` (1). Stop the server. Record outputs.

- [ ] **Step 7: Commit** — `git add web && git commit -m "feat(web): installable PWA — manifest, icons, service worker with offline shell, add-to-home-screen nudge"`

---

### Task 6: Playwright smoke, Vercel services config, docs

**Files:**
- Create: `web/playwright.config.ts`, `web/e2e/smoke.spec.ts`, `web/README.md`
- Modify: `vercel.json`, `web/package.json` (scripts), `web/.gitignore` (append Playwright outputs), `PROGRESS.md`, `docs/superpowers/plans/2026-08-26-plan-5-paddler-pwa.md` (tick boxes)

- [ ] **Step 1: Playwright**
```bash
cd web && pnpm add -D @playwright/test && pnpm exec playwright install chromium
printf '\n# Playwright\n/test-results/\n/playwright-report/\n' >> .gitignore
```
Add scripts: `"e2e": "playwright test"`. Ensure `tsconfig.json` `exclude` does not drop `e2e/` (it should be typechecked) and that `vitest.config.ts` still excludes it.

`web/playwright.config.ts`:
```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  retries: 0,
  use: { baseURL: "http://localhost:3000", ...devices["Pixel 7"] },
  webServer: {
    command: "pnpm dev",
    url: "http://localhost:3000/login",
    reuseExistingServer: true,
    timeout: 120_000,
    env: { NEXT_PUBLIC_PADDLTIR_DEV_LOGIN: "1" },
  },
});
```
`web/e2e/smoke.spec.ts`:
```ts
import { expect, test } from "@playwright/test";

// Needs: `supabase start`, `supabase db reset`, `psql … -f supabase/seed_dev.sql`, and web/.env.local (see README).
test.skip(!process.env.PADDLTIR_LIVE_SUPABASE, "set PADDLTIR_LIVE_SUPABASE=1 with the local stack + demo seed running");

test("a paddler signs in, sees their next event, finds their seat, logs an erg", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveURL(/\/login$/);
  await page.getByLabel("Password").fill("password123");
  await page.getByRole("button", { name: "Sign in with password" }).click();

  // Next event = the seeded training; availability is seeded "in".
  await expect(page.getByRole("heading", { name: "Tuesday training" })).toBeVisible();
  const group = page.getByRole("radiogroup", { name: "Availability for Tuesday training" });
  await expect(group.getByRole("radio", { name: "In" })).toHaveAttribute("aria-checked", "true");
  await group.getByRole("radio", { name: "Maybe" }).click();
  await page.reload();
  await expect(group.getByRole("radio", { name: "Maybe" })).toHaveAttribute("aria-checked", "true");
  await group.getByRole("radio", { name: "In" }).click();

  // The race day: Lily is Bench 1 left in Heat 1; the Final is empty.
  await page.getByRole("link", { name: /Sydney Regatta/ }).click();
  await expect(page.getByRole("heading", { name: "Premier Mixed 200m" })).toBeVisible();
  await expect(page.getByText("Bench 1 left", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Bench 1 left: Lily (you)")).toBeVisible();
  await expect(page.getByLabel("Drummer: Dee Drummer")).toBeVisible();
  await page.getByRole("tab", { name: "Final" }).click();
  await expect(page.getByText("Not in this heat")).toBeVisible();

  // Erg
  await page.getByRole("link", { name: "Erg" }).click();
  await page.getByLabel("Metres (1 min)").fill("555");
  await page.getByRole("button", { name: "Log erg test" }).click();
  await expect(page.getByRole("status")).toHaveText("Saved 555 m.");
  await expect(page.getByText("555 m", { exact: true })).toBeVisible(); // exact: "Saved 555 m." must not also match

  // Profile + manifest
  await page.getByRole("link", { name: "Profile" }).click();
  await expect(page.getByText("Signed in as lily@paddltir.dev")).toBeVisible();
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute("href", /manifest\.webmanifest/);
});
```
Run: `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e` (local stack + demo seed loaded; if a previous run left Lily on "Maybe", the test still passes because it asserts the seeded state only after resetting — if it fails on the first assertion, re-seed with `supabase db reset` + `seed_dev.sql`). Expect 1 passed. Also run `pnpm e2e` without the flag → 1 skipped.

- [ ] **Step 2: Vercel services** — replace `vercel.json`:
```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "services": {
    "web": { "root": "web/" },
    "solver": { "root": "solver/", "entrypoint": "main:app" }
  },
  "rewrites": [
    { "source": "/api/(.*)", "destination": { "service": "solver" } },
    { "source": "/(.*)", "destination": { "service": "web" } }
  ]
}
```

- [ ] **Step 3: README** — `web/README.md`:
```markdown
# Paddltir — paddler PWA

Next.js App Router + Supabase (`@supabase/ssr`) + Tailwind v4. Mobile-first, installable, realtime.

## Local setup
1. From the repo root: `supabase start`, `supabase db reset`, then load demo data:
   `/opt/homebrew/opt/libpq/bin/psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed_dev.sql`
2. `cp .env.example .env.local` and paste the anon key from `supabase status`.
3. `pnpm install && pnpm dev` → http://localhost:3000 — sign in with the dev form as `lily@paddltir.dev` / `password123`
   (the form only renders when `NEXT_PUBLIC_PADDLTIR_DEV_LOGIN=1`; never set it on Vercel).

## Commands
`pnpm typecheck` · `pnpm lint` · `pnpm test` (Vitest, `lib/`) · `pnpm build` · `PADDLTIR_LIVE_SUPABASE=1 pnpm e2e` (Playwright smoke vs the local stack) · `pnpm icons` (regenerate PNG icons from `scripts/*.svg`).

## Shape
- `app/` routes: `/login` (magic link) · `/join` (invite code → claim your name) · `/` next event (+ `/session/[id]`) · `/availability` · `/erg` · `/profile` · `/auth/*` · `/offline`.
- `lib/` pure, unit-tested rules (boat sections mirror `PaddltirCore.Boat`; lineup lookup; gating; validation). No scoring — paddlers *see* lineups.
- Server Components read through the user's cookie session (RLS authorises); Server Actions write; `proxy.ts` refreshes the session.
- Realtime `postgres_changes` on `sessions/heats/seats/heat_reserves/availability` → `router.refresh()`.
- Regenerate DB types after a migration: `supabase gen types typescript --local --schema public > lib/db/database.types.ts`.

## Go-live (needs Jun)
Vercel project `paddltir` with services `web/` + `solver/` (`vercel.json`); env `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SITE_URL=https://paddltir.vercel.app`. Supabase Auth → add the Vercel URL to redirect URLs (already listed in `supabase/config.toml` for local).
```

- [ ] **Step 4: Full gate, docs, commit**
`cd web && pnpm typecheck && pnpm lint && pnpm test && pnpm build && PADDLTIR_LIVE_SUPABASE=1 pnpm e2e`; from the root `supabase test db` (all suites incl. 007). Tick every checkbox in this plan; add a `PROGRESS.md` bullet under MERGED TO MAIN reading: "**Plan 5 — Paddler PWA (web/).** Next.js App Router + @supabase/ssr; routes /login /join / /session/[id] /availability /erg /profile; boat diagram with your seat + heat switcher; realtime refresh (publication migration + pgTAP 007); installable (manifest/SW/nudge); N Vitest tests + 1 Playwright smoke (gated) verified vs local stack. NOT deployed — go-live needs Jun's Vercel/Supabase credentials." (fill in N).
```bash
git add web vercel.json PROGRESS.md docs/superpowers/plans/2026-08-26-plan-5-paddler-pwa.md
git commit -m "test(web): Playwright smoke vs local stack; chore: Vercel web service; docs: Plan 5 complete"
```

---

## Self-review (done while writing)

- **Spec coverage:** §4 routes — `/login` T2 · `/join` T2 · `/` next event with boat diagram + your seat + full lineup by name + heat switcher, training inline availability T3 · `/availability` T4 · `/erg` submit + history + sparkline T4 · `/profile` T4 · installable manifest/SW/one-time nudge T5 · realtime heats/seats/sessions T3 (+ publication migration) · `@supabase/ssr`, Tailwind, mobile-first, same palette/type/boat diagram, no fake glass T1. §7 services config T6 (deploy deferred to go-live). §8 Vitest + one Playwright smoke T6. §9 `web/` T1.
- **Placeholders:** none — every step carries its code; version-dependent names (`proxy.ts`/`middleware.ts`, `config`/`proxyConfig`, `Intl` month spelling) are stated as rules with the check that settles them.
- **Type consistency:** `HeatView/Named/SeatView/Side` defined in `lib/lineup.ts` and consumed by `lib/event.ts`, `BoatDiagram`, `RaceCard`; `EventView`/`RaceView`/`AvailabilityStatus` in `lib/event.ts` consumed by `data/sessions.ts`, `EventView.tsx`, `AvailabilityToggle`, pages; `Viewer/OwnPaddler` in `data/viewer.ts` consumed by `gate.ts`, layouts, pages; `setAvailability(sessionId, status)` signature identical in T3 definition and T3/T4 callers; `ErgState`/`submitErg` (T4) match `ErgForm`; `shouldShowNudge` (T5) matches its caller. `Card` accepts `ComponentProps<"section">` so `className` merges in every use.
- **Known assumption (state it, don't hide it):** one club time zone (`Australia/Sydney`) for display — v1 only has one club; make it a club column when multi-club lands.
