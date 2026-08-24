# PROGRESS.md — Paddltir

> Source of truth across sessions. After any compaction: re-read this file and the
> implementation plan (docs/superpowers/plans/) BEFORE anything else.

## Current phase
**Phase 1 — ready to execute Plans 1–3** (core, supabase, solver). Spec approved 2026-08-22.
Plans live in `docs/superpowers/plans/` — start from `2026-08-22-roadmap.md`.
Execution: subagent-driven, parallel (Jun chose 2026-08-23). One git worktree + branch per plan:
`.worktrees/plan-1-core` (branch plan-1-core), `.worktrees/plan-2-supabase`, `.worktrees/plan-3-solver`.
Each worktree has an SDD ledger at `<worktree>/.superpowers/sdd/<plan>/progress.md` (git-ignored) —
after compaction: read those ledgers + `git log` on each branch to find the next task. Branches are pushed
as tasks complete; each plan merges to main after its final review. Plan 3 Task 2+ waits for Plan 1's
fixtures to land on main (then `git merge main` into plan-3-solver).

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
- 2026-08-22: **Navigation = Schedule · Crews · Squad** (approach A). Concepts renamed: Roster→Squad, Crewlist→Crew, Config→Race, heats are rows, Session new. (user chose)
- 2026-08-22: **powerRatio dropped** — algorithms use absolute erg metres (objective is scale-invariant); UI derives relative bar. (user approved)
- 2026-08-22: Hosting: Vercel **Services** (web/ Next.js + solver/ FastAPI) preferred; fallback file-based web/api/optimize.py. Python 3.12.
- 2026-08-22: **Selection-quality stage added** (maximise total erg of seated crew) between "max seated" and "weight balance" in BOTH algorithms — otherwise the optimiser may bench the strongest paddler to shave grams of imbalance. Flagged to Jun at plan handoff; proceed unless vetoed.
- 2026-08-22: `category_rules` carries min/max for both women and men (women-only = max_men 0).
- 2026-08-22: Plans 4 (coach app) and 5 (PWA) are written AFTER the visual-direction phase (frontend-design + ui-ux-pro-max + imagegen) per the brief's skill order.
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
- [x] Brainstorm UX / screen architecture — all 6 sections approved
- [x] Spec written and approved (docs/superpowers/specs/2026-08-22-paddltir-design.md)
- [x] Roadmap + Plans 1–3 written and self-reviewed (docs/superpowers/plans/)
- [x] **Plan 1 (PaddltirCore): MERGED to main** (commit 40a7882). 12 tasks, 56/56 tests, 0 warnings, greedy auto-fill ≈3ms release, golden fixtures. Final whole-branch review clean. Branch+worktree deleted. Rulings recorded in git history + scratchpad ledger copy.
- [~] Plan 2 (Supabase): tasks 1–6 + local wrap COMPLETE (3 opus security reviews; RLS write-policy hardening in final re-review now); 93 pgTAP tests green. Task 7 (hosted project) = go-live. Ready to merge after RLS re-review.
- [x] **Plan 3 (Solver): MERGED to main** (commit e6aa5e0). Python model + scoring (EXACT cross-lang parity), lexicographic HiGHS MIP (y-reformulation proves all provable stages ~161ms), MIP goldens, auth/db/cache adapters, FastAPI /api/optimize (authz-ordered, cache), vercel.json. 25 tests. Final review clean. LIVE deploy deferred to go-live. Branch+worktree deleted.

## Next
- [x] Write design spec → docs/superpowers/specs/2026-08-22-paddltir-design.md
- [ ] Phase 2: visual direction (frontend-design + ui-ux-pro-max) → docs/design/direction.md; concepts via imagegen-frontend-mobile
- [ ] Write Plans 4 (coach app) + 5 (PWA), then execute
- [ ] Plan 6 integration + verification

## Blocked / open questions for Jun
- (none right now)

## Learned the hard way
(nothing yet)
