-- supabase/migrations/20260822000300_rls.sql

alter table clubs enable row level security;
alter table profiles enable row level security;
alter table paddlers enable row level security;
alter table erg_tests enable row level security;
alter table crews enable row level security;
alter table crew_members enable row level security;
alter table sessions enable row level security;
alter table availability enable row level security;
alter table races enable row level security;
alter table heats enable row level security;
alter table seats enable row level security;
alter table heat_reserves enable row level security;
alter table category_rules enable row level security;
alter table optimize_cache enable row level security;

-- clubs
create policy clubs_select on clubs for select to authenticated using (id = auth_club_id());
create policy clubs_update on clubs for update to authenticated using (id = auth_club_id() and is_coach()) with check (id = auth_club_id() and is_coach());

-- profiles
create policy profiles_select on profiles for select to authenticated using (id = auth.uid() or (club_id is not null and club_id = auth_club_id()));
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid() or (is_coach() and club_id = auth_club_id()))
  with check (id = auth.uid() or (is_coach() and club_id = auth_club_id()));

-- paddlers: coaches full (no delete); paddlers read own row only
create policy paddlers_select_coach on paddlers for select to authenticated using (club_id = auth_club_id() and is_coach());
create policy paddlers_select_self on paddlers for select to authenticated using (profile_id = auth.uid());
create policy paddlers_insert on paddlers for insert to authenticated with check (club_id = auth_club_id() and is_coach());
create policy paddlers_update on paddlers for update to authenticated using (club_id = auth_club_id() and is_coach()) with check (club_id = auth_club_id() and is_coach());

-- erg_tests
-- helper keeps policies off RLS-protected subqueries (recursion-proof, like the other *_club helpers)
create or replace function paddler_club(p_paddler uuid) returns uuid
language sql stable security definer set search_path = public as $$ select club_id from paddlers where id = p_paddler $$;
grant execute on function paddler_club(uuid) to authenticated;

create policy erg_select_coach on erg_tests for select to authenticated using (is_coach() and paddler_club(paddler_id) = auth_club_id());
create policy erg_select_self on erg_tests for select to authenticated using (paddler_id = my_paddler_id());
create policy erg_insert_coach on erg_tests for insert to authenticated with check (is_coach() and source = 'coach' and paddler_club(paddler_id) = auth_club_id());
create policy erg_insert_self on erg_tests for insert to authenticated with check (paddler_id = my_paddler_id() and source = 'self' and recorded_by = auth.uid());
create policy erg_update_coach on erg_tests for update to authenticated using (is_coach() and paddler_club(paddler_id) = auth_club_id());
create policy erg_delete_coach on erg_tests for delete to authenticated using (is_coach() and paddler_club(paddler_id) = auth_club_id());

-- club-scoped tables readable by everyone in the club, writable by coaches
create policy crews_select on crews for select to authenticated using (club_id = auth_club_id());
create policy crews_write on crews for all to authenticated using (club_id = auth_club_id() and is_coach()) with check (club_id = auth_club_id() and is_coach());

create policy crew_members_select on crew_members for select to authenticated using (crew_club(crew_id) = auth_club_id());
create policy crew_members_write on crew_members for all to authenticated using (crew_club(crew_id) = auth_club_id() and is_coach()) with check (crew_club(crew_id) = auth_club_id() and is_coach());

create policy sessions_select on sessions for select to authenticated using (club_id = auth_club_id());
create policy sessions_write on sessions for all to authenticated using (club_id = auth_club_id() and is_coach()) with check (club_id = auth_club_id() and is_coach());

create policy races_select on races for select to authenticated using (session_club(session_id) = auth_club_id());
create policy races_write on races for all to authenticated using (session_club(session_id) = auth_club_id() and is_coach()) with check (session_club(session_id) = auth_club_id() and is_coach());

create policy heats_select on heats for select to authenticated using (race_club(race_id) = auth_club_id());
create policy heats_write on heats for all to authenticated using (race_club(race_id) = auth_club_id() and is_coach()) with check (race_club(race_id) = auth_club_id() and is_coach());

create policy seats_select on seats for select to authenticated using (heat_club(heat_id) = auth_club_id());
create policy seats_write on seats for all to authenticated using (heat_club(heat_id) = auth_club_id() and is_coach()) with check (heat_club(heat_id) = auth_club_id() and is_coach());

create policy reserves_select on heat_reserves for select to authenticated using (heat_club(heat_id) = auth_club_id());
create policy reserves_write on heat_reserves for all to authenticated using (heat_club(heat_id) = auth_club_id() and is_coach()) with check (heat_club(heat_id) = auth_club_id() and is_coach());

create policy rules_select on category_rules for select to authenticated using (club_id = auth_club_id());
create policy rules_write on category_rules for all to authenticated using (club_id = auth_club_id() and is_coach()) with check (club_id = auth_club_id() and is_coach());

-- availability: coaches see/write all in club; paddlers only their own rows
create policy avail_select_coach on availability for select to authenticated using (is_coach() and session_club(session_id) = auth_club_id());
create policy avail_select_self on availability for select to authenticated using (paddler_id = my_paddler_id());
create policy avail_write_coach on availability for all to authenticated using (is_coach() and session_club(session_id) = auth_club_id()) with check (is_coach() and session_club(session_id) = auth_club_id());
create policy avail_insert_self on availability for insert to authenticated with check (paddler_id = my_paddler_id() and session_club(session_id) = auth_club_id());
create policy avail_update_self on availability for update to authenticated
  using (paddler_id = my_paddler_id() and session_club(session_id) = auth_club_id())
  with check (paddler_id = my_paddler_id() and session_club(session_id) = auth_club_id());

-- optimize_cache: service role only (no policies) — also revoke table privileges
revoke all on optimize_cache from anon, authenticated;
-- anon gets nothing anywhere
revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
