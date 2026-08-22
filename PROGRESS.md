# PROGRESS.md — Paddltir

> Source of truth across sessions. After any compaction: re-read this file and the
> implementation plan (docs/superpowers/plans/) BEFORE anything else.

## Current phase
**Phase 0 — Brainstorming / design.** Project directory confirmed as
`/Users/junlee/Documents/programming/paddltir` (git remote: github.com/junlee-3/paddltir).
Working through superpowers:brainstorming → writing a design spec → writing-plans.

## Hard rules (from the brief)
- Old project `/Users/junlee/Documents/CGS/IB/IA/LEEJun-CSIA/Product/crewCoach` is **READ-ONLY**. Never write/modify anything there.
- Any mention of "CrewCoach" in the product → **Paddltir**.
- Architecture is locked (SwiftUI coach app + PaddltirCore pkg, Next.js paddler PWA on Vercel,
  Supabase backend, Python+highspy solver as Vercel Python fn). Raise objections with the user, don't deviate silently.
- Commit + push to GitHub as we go.

## Decisions made (with reasoning)
- 2026-08-22: Project lives in the existing empty repo at cwd (user confirmed).
- 2026-08-22: **Club model = invite-code clubs.** Coach signs up → creates club → shareable invite code/link. Paddlers sign in by email magic link, enter code, claim their roster row (auto-linked if coach entered their email). Multi-club ready. (user chose)
- 2026-08-22: **Supabase = new hosted project (ap-southeast-2) + OrbStack locally** for `supabase start` + pgTAP RLS tests. Hosted = staging/prod. (user chose). Jun to install OrbStack: `brew install --cask orbstack`.
- 2026-08-22: **Availability = coach-defined sessions** (training / race day); paddlers respond In/Out/Maybe + note. (user chose)
- 2026-08-22: Mixed-crew gender rule (IDBF, verified): standard boat 8–12 of each gender /20; small boat 4–6 /10. Some events use 8–10 / 4–5 → configurable per category (min/max women).

## Domain facts from old prototype (extracted 2026-08-22, see agent brief)
- Erg score = metres in a 2-minute erg test (higher better). powerRatio = erg/max(erg over roster), derived, never stored.
- Enums: side Left|Right|Both; gender Male|Female; seat pref Stroke|Pace|Engine|Sprint; role Paddler|Drummer|Sweep;
  size small(5 benches)|standard(10); category open|women|mixed; age divisions 16U 18U 24U Premier "Senior A" "Senior B" "Senior C".
- Sections standard: Stroke[1] Pace[2,3] Engine[4–7] Sprint[8–10]; small: Stroke[1] Pace[2] Engine[3] Sprint[4,5].
- Warn thresholds: weight Δ 10 kg; power Δ 10% of total; side-pref < 80%; trim Δ 50 kg.
- Trim: arm for bench b = b − (n+1)/2 (5.5 standard); drummer arm −(n+1)/2; sweep arm +(n−(n+1)/2+1). trimDelta = 2|Σw·arm|/n.
- Old greedy: lexicographic 4-tuple [|ΔW|, |ΔP|, −sideMatches, −benchMatches], 3 deterministic orderings, ignores trim + drummer/sweep weight. Suggestions: top-2 swaps; replacement plans ≤3 moves.
- Old app: heats hardcoded (heat1/heat2/final), no paddler login, no availability, no gender constraint.

## Done
- [x] Project directory confirmed
- [x] PROGRESS.md created

## In progress
- [ ] Brainstorm UX / screen architecture (superpowers:brainstorming)

## Next
- [ ] Write design spec → docs/superpowers/specs/
- [ ] Write implementation plan → docs/superpowers/plans/
- [ ] Visual direction (frontend-design + ui-ux-pro-max), screen concepts (imagegen-frontend-mobile)
- [ ] Build

## Blocked / open questions for Jun
- powerRatio: roster-relative vs absolute scale (to raise with recommendation)

## Learned the hard way
(nothing yet)
