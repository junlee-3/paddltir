-- supabase/seed.sql  (LOCAL ONLY — never pushed to hosted)
-- NOTE: tests.create_user is anon-callable by design; this file is never pushed to hosted.
-- ---------- test helpers ----------
create schema if not exists tests;
grant usage on schema tests to anon, authenticated;   -- so tests.logout() is callable after login_as()

create or replace function tests.create_user(p_email text, p_name text default null) returns uuid
language plpgsql security definer as $$
declare uid uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', lower(p_email),
    crypt('password123', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', coalesce(p_name, split_part(p_email,'@',1))), now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text, jsonb_build_object('sub', uid::text, 'email', lower(p_email)), 'email', now(), now(), now());
  return uid;
end $$;

create or replace function tests.login_as(p_email text) returns void language plpgsql as $$
declare uid uuid;
begin
  select id into uid from auth.users where email = lower(p_email);
  if uid is null then raise exception 'no such test user %', p_email; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'email', lower(p_email))::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function tests.login_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;

create or replace function tests.logout() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

-- ---------- demo data (local only) ----------
do $$
declare coach_id uuid; lily_id uuid; club uuid; crew uuid; train uuid; raceday uuid; race uuid; h1 uuid; h2 uuid; hf uuid;
  names text[] := array['Lily','Nick','Maya','Owen','Zoe','Ethan','Ava','Liam','Chloe','Noah','Mia','Lucas','Ella','Mason','Grace','Logan','Ruby','Jack','Isla','Leo','Hannah','Oscar'];
  weights numeric[] := array[58,78,62,82,60,85,64,88,66,80,59,90,63,76,61,84,65,79,57,86,68,83];
  ergs int[] := array[520,640,540,660,500,650,515,670,530,630,490,680,505,620,495,645,510,635,480,655,545,625];
  genders gender[] := array['female','male','female','male','female','male','female','male','female','male','female','male','female','male','female','male','female','male','female','male','female','male'];
  sides side_pref[] := array['left','left','right','right','left','left','either','right','right','either','left','left','right','right','left','left','either','either','right','right','left','right'];
  prefs seat_pref[] := array['stroke','stroke','stroke','pace','pace','engine','pace','engine','engine','engine','engine','engine','engine','sprint','sprint','sprint','sprint','sprint','none','none','none','pace'];
  i int; pid uuid; paddler_ids uuid[] := '{}';
begin
  coach_id := tests.create_user('coach@paddltir.dev', 'Coach Jun');
  lily_id  := tests.create_user('lily@paddltir.dev', 'Lily');

  insert into clubs (name, invite_code, created_by) values ('Paddltir Demo Club', 'DEMO2026', coach_id) returning id into club;
  perform set_config('paddltir.allow_profile_admin', '1', true);
  update profiles set club_id = club, role = 'head_coach' where id = coach_id;
  insert into category_rules (club_id, category, boat_size, min_women, max_women, min_men, max_men) values
    (club, 'mixed', 'standard', 8, 12, 8, 12), (club, 'mixed', 'small', 4, 6, 4, 6),
    (club, 'women', 'standard', null, null, null, 0), (club, 'women', 'small', null, null, null, 0);

  for i in 1..22 loop
    insert into paddlers (club_id, name, email, weight_kg, gender, preferred_side, seat_preference)
    values (club, names[i], case when i = 1 then 'lily@paddltir.dev' else null end, weights[i], genders[i], sides[i], prefs[i])
    returning id into pid;
    paddler_ids := paddler_ids || pid;
    insert into erg_tests (paddler_id, tested_at, metres, source, recorded_by) values (pid, current_date - 14, ergs[i] - 10, 'coach', coach_id);
    insert into erg_tests (paddler_id, tested_at, metres, source, recorded_by) values (pid, current_date - 1, ergs[i], 'coach', coach_id);
  end loop;
  -- drummer and sweep
  insert into paddlers (club_id, name, weight_kg, gender, boat_role) values (club, 'Dee Drummer', 52, 'female', 'drummer') returning id into pid; paddler_ids := paddler_ids || pid;
  insert into paddlers (club_id, name, weight_kg, gender, boat_role) values (club, 'Sam Sweep', 81, 'male', 'sweep') returning id into pid; paddler_ids := paddler_ids || pid;

  -- link Lily's account
  update profiles set club_id = club, role = 'paddler' where id = lily_id;
  update paddlers set profile_id = lily_id where club_id = club and name = 'Lily';

  insert into crews (club_id, name, age_division, category) values (club, 'Premier Mixed', 'Premier', 'mixed') returning id into crew;
  insert into crew_members (crew_id, paddler_id) select crew, unnest(paddler_ids);

  insert into sessions (club_id, kind, title, starts_at, venue) values (club, 'training', 'Tuesday training', date_trunc('day', now()) + interval '2 days' + interval '18 hours', 'Boat shed') returning id into train;
  insert into sessions (club_id, kind, title, starts_at, venue) values (club, 'race_day', 'Sydney Regatta', date_trunc('day', now()) + interval '9 days' + interval '8 hours', 'Sydney International Regatta Centre') returning id into raceday;
  insert into availability (session_id, paddler_id, status) select train, unnest(paddler_ids[1:18]), 'in';
  insert into availability (session_id, paddler_id, status, note) values (train, paddler_ids[19], 'out', 'exam'), (train, paddler_ids[20], 'maybe', null);

  insert into races (session_id, crew_id, name, boat_size, distance_m) values (raceday, crew, 'Premier Mixed 200m', 'standard', 200) returning id into race;
  insert into heats (race_id, name, sort_order, drummer_id, sweep_id) values (race, 'Heat 1', 1, paddler_ids[23], paddler_ids[24]) returning id into h1;
  insert into heats (race_id, name, sort_order, drummer_id, sweep_id) values (race, 'Heat 2', 2, paddler_ids[23], paddler_ids[24]) returning id into h2;
  insert into heats (race_id, name, sort_order, drummer_id, sweep_id) values (race, 'Final', 3, paddler_ids[23], paddler_ids[24]) returning id into hf;
  -- naive lineup for heat 1: first 20 alternating sides
  for i in 1..20 loop
    insert into seats (heat_id, bench, side, paddler_id) values (h1, (i + 1) / 2, (case when i % 2 = 1 then 'left' else 'right' end)::boat_side, paddler_ids[i]);
  end loop;
  insert into heat_reserves (heat_id, paddler_id) values (h1, paddler_ids[21]), (h1, paddler_ids[22]);
end $$;
