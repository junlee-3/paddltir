begin;
select plan(18);
select tests.create_user('c1@test.dev','C1'); select tests.create_user('c2@test.dev','C2');
select tests.login_as('c1@test.dev'); select create_club('Club One');
insert into paddlers (club_id, name, weight_kg, gender) values (auth_club_id(), 'A', 70, 'male');
insert into crews (club_id, name, age_division, category) values (auth_club_id(), 'Premier Mixed', 'Premier', 'mixed');
insert into sessions (club_id, kind, title, starts_at) values (auth_club_id(), 'race_day', 'Regatta', now() + interval '7 days');
insert into races (session_id, crew_id, name) select s.id, c.id, 'Race 1' from sessions s, crews c;
insert into heats (race_id, name) select id, 'Heat 1' from races;
insert into seats (heat_id, bench, side, paddler_id) select h.id, 1, 'left', p.id from heats h, paddlers p;
select is((select count(*) from seats), 1::bigint, 'coach reads own seats');
select lives_ok($$ update paddlers set weight_kg = 71 $$, 'coach updates paddler');
delete from paddlers;   -- no DELETE policy ⇒ RLS hides every row ⇒ silently affects 0 rows
select is((select count(*) from paddlers), 1::bigint, 'delete is a no-op: nobody deletes paddlers');
select lives_ok($$ insert into erg_tests (paddler_id, metres, source, recorded_by) select id, 500, 'coach', auth.uid() from paddlers $$, 'coach records erg');
select lives_ok($$ update clubs set name = 'Club Uno' $$, 'coach renames club');
select tests.logout();
create temp table club_one as select id from clubs where name = 'Club Uno';   -- as postgres, for the cross-club insert below
grant select on club_one to authenticated;  -- so the insert below fails on RLS with-check, not on temp-table privilege

select tests.login_as('c2@test.dev'); select create_club('Club Two');
select is((select count(*) from paddlers), 0::bigint, 'other club sees no paddlers');
select is((select count(*) from seats), 0::bigint, 'other club sees no seats');
select is((select count(*) from pg_tables where schemaname = 'public' and rowsecurity = false), 0::bigint, 'every public table has RLS enabled');
select is((select count(*) from sessions), 0::bigint, 'other club sees no sessions');
select is((select count(*) from clubs), 1::bigint, 'sees only own club');
select throws_ok($$ insert into paddlers (club_id, name, weight_kg, gender) select id, 'X', 70, 'male' from club_one $$, '42501', null, 'cannot insert into other club');
select throws_ok($$ select count(*) from optimize_cache $$, '42501', null, 'cache not readable by users');
select throws_ok($$ insert into optimize_cache (input_hash, result) values ('x', '{}') $$, '42501', null, 'cache not writable by users');
insert into paddlers (club_id, name, weight_kg, gender) values (auth_club_id(), 'B', 60, 'female');   -- club two's paddler, referenced cross-club below
select tests.logout();
create temp table club_two_paddler as select id from paddlers where name = 'B';   -- as postgres, for the cross-club write attempts below
grant select on club_two_paddler to authenticated;  -- so the writes below fail on RLS with-check, not on temp-table privilege

select tests.login_as('c1@test.dev');
select throws_ok($$ insert into availability (session_id, paddler_id, status) select s.id, p.id, 'in' from sessions s, club_two_paddler p $$, '42501', null, 'coach cannot set availability for foreign-club paddler');
select throws_ok($$ insert into crew_members (crew_id, paddler_id) select c.id, p.id from crews c, club_two_paddler p $$, '42501', null, 'coach cannot add foreign-club paddler to crew');
select throws_ok($$ insert into seats (heat_id, bench, side, paddler_id) select h.id, 2, 'right', p.id from heats h, club_two_paddler p $$, '42501', null, 'coach cannot seat foreign-club paddler');
select throws_ok($$ insert into heat_reserves (heat_id, paddler_id) select h.id, p.id from heats h, club_two_paddler p $$, '42501', null, 'coach cannot reserve foreign-club paddler');
select throws_ok($$ update heats set drummer_id = p.id from club_two_paddler p $$, '42501', null, 'coach cannot set foreign-club paddler as drummer');
select tests.logout();
select * from finish();
rollback;
