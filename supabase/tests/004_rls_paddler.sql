begin;
select plan(17);
select tests.create_user('coach@test.dev','Coach'); select tests.create_user('p1@test.dev','P1'); select tests.create_user('p2@test.dev','P2');
select tests.login_as('coach@test.dev'); select create_club('Club');
insert into paddlers (club_id, name, email, weight_kg, gender) values (auth_club_id(), 'P One', 'p1@test.dev', 61.5, 'female');
insert into paddlers (club_id, name, email, weight_kg, gender) values (auth_club_id(), 'P Two', 'p2@test.dev', 82.0, 'male');
insert into sessions (club_id, kind, title, starts_at) values (auth_club_id(), 'training', 'Tuesday', now() + interval '2 days');
insert into crews (club_id, name, age_division, category) values (auth_club_id(), 'Crew', 'Premier', 'mixed');
insert into races (session_id, crew_id, name) select s.id, c.id, 'R' from sessions s, crews c;
insert into heats (race_id, name) select id, 'Heat 1' from races;
insert into seats (heat_id, bench, side, paddler_id) select h.id, 1, 'left', p.id from heats h, paddlers p where p.name='P Two';
insert into erg_tests (paddler_id, metres, source) select id, 600, 'coach' from paddlers where name='P Two';
select tests.logout();

select tests.login_as('p1@test.dev'); select join_club((select invite_code from clubs));
-- reads
select is((select count(*) from paddlers), 1::bigint, 'paddler reads only own base row');
select is((select name from paddlers), 'P One', 'and it is theirs');
select is((select count(*) from paddlers_public), 2::bigint, 'public view shows whole club');
select is((select count(*) from seats), 1::bigint, 'paddler sees lineup seats');
select is((select count(*) from heats), 1::bigint, 'paddler sees heats');
select is((select count(*) from sessions), 1::bigint, 'paddler sees sessions');
select is((select count(*) from erg_tests), 0::bigint, 'paddler cannot see others erg tests');
-- writes
select lives_ok($$ insert into availability (session_id, paddler_id, status, note) select id, my_paddler_id(), 'in', 'yes' from sessions $$, 'paddler sets own availability');
select lives_ok($$ update availability set status = 'maybe' where paddler_id = my_paddler_id() $$, 'paddler updates own availability');
select throws_ok($$ insert into availability (session_id, paddler_id, status) select s.id, p.id, 'out' from sessions s, paddlers_public p where p.name = 'P Two' $$, '42501', null, 'cannot set others availability');
select lives_ok($$ insert into erg_tests (paddler_id, metres, source, recorded_by) values (my_paddler_id(), 520, 'self', auth.uid()) $$, 'paddler submits own erg');
select throws_ok($$ insert into erg_tests (paddler_id, metres, source) values (my_paddler_id(), 520, 'coach') $$, '42501', null, 'paddler cannot claim coach source');
update paddlers set weight_kg = 50 where id = my_paddler_id();   -- no UPDATE policy for paddlers ⇒ affects 0 rows
select is((select weight_kg from paddlers where id = my_paddler_id()), 61.5::numeric, 'paddler cannot edit own weight');
update paddlers set profile_id = auth.uid() where id in (select id from paddlers_public where name = 'P Two');  -- claim bypass ⇒ 0 rows
select is((select profile_id from paddlers_public where name = 'P Two'), null, 'paddler cannot claim rows directly');
select throws_ok($$ insert into seats (heat_id, bench, side, paddler_id) select h.id, 2, 'left', my_paddler_id() from heats h $$, '42501', null, 'paddler cannot edit lineup');
select throws_ok($$ update profiles set role = 'coach' where id = auth.uid() $$, '42501', null, 'paddler cannot self-promote');
select is((select count(*) from availability), 1::bigint, 'paddler sees only own availability rows');
select tests.logout();
select * from finish();
rollback;
