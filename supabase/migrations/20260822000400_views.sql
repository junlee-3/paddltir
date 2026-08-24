-- supabase/migrations/20260822000400_views.sql

-- Coach-facing: paddler + latest erg (respects caller's RLS on paddlers/erg_tests)
create view paddlers_with_power with (security_invoker = true) as
select p.*, e.metres as erg_m, e.tested_at as erg_tested_at
from paddlers p
left join lateral (
  select metres, tested_at from erg_tests t where t.paddler_id = p.id
  order by tested_at desc, created_at desc limit 1
) e on true;

-- Paddler-facing: names and roles for the whole club, nothing sensitive. Definer view, filtered by club.
create view paddlers_public as
select id, club_id, name, preferred_side, boat_role, profile_id, archived_at
from paddlers where club_id = auth_club_id();

-- Both views are read-only surfaces. Without an explicit revoke, `authenticated`
-- would inherit INSERT/UPDATE/DELETE on them via 0002's blanket default-privilege
-- grant (which also covers views created afterward). For paddlers_public that would
-- be a serious hole: it is a definer view owned by a role that bypasses RLS on the
-- underlying paddlers table, so any club member (not just coaches) could
-- `update paddlers_public set profile_id = auth.uid() ...` and claim or edit a
-- teammate's row, bypassing the coach-only paddlers_update policy entirely.
revoke all on paddlers_with_power, paddlers_public from anon, authenticated;
grant select on paddlers_with_power, paddlers_public to authenticated;
