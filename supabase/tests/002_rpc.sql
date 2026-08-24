begin;
select plan(20);

select tests.create_user('coach@test.dev', 'Coach');
select tests.create_user('lily@test.dev', 'Lily');
select tests.create_user('sam@test.dev', 'Sam');

-- signup trigger created profiles
select is((select count(*) from profiles where display_name in ('Coach','Lily','Sam')), 3::bigint, 'profiles created on signup');

-- create_club
select tests.login_as('coach@test.dev');
select lives_ok($$ select create_club('Test Club') $$, 'coach can create a club');
select is((select role from profiles where display_name='Coach'), 'head_coach', 'creator becomes head_coach');
select isnt((select club_id from profiles where display_name='Coach'), null, 'creator joined club');
select is((select count(*) from category_rules where club_id = auth_club_id()), 4::bigint, 'default category rules seeded');
select throws_ok($$ select create_club('Second') $$, 'P0001', 'already in a club', 'cannot create a second club');

-- coach adds a paddler with an email (pre-linked path) and one without
select lives_ok($$ insert into paddlers (club_id, name, email, weight_kg, gender) values (auth_club_id(), 'Lily L', 'lily@test.dev', 60, 'female') $$, 'coach inserts paddler');
select lives_ok($$ insert into paddlers (club_id, name, weight_kg, gender) values (auth_club_id(), 'Sam S', 80, 'male') $$, 'coach inserts second paddler');
select tests.logout();
create temp table sam_row as select id from paddlers where name = 'Sam S';   -- as postgres: Sam cannot see this row before linking
grant select on sam_row to authenticated;   -- the argument expression is evaluated as the caller's role
create temp table invite as select invite_code as code from clubs;   -- codes are delivered out of band in the product;
grant select on invite to authenticated;                             -- clubs are invisible until you belong to one (RLS)

-- claimable list works before joining
select is((select count(*) from claimable_paddlers((select invite_code from clubs limit 1))), 1::bigint, 'claimable lists unlinked paddlers without earmarked email');

-- lily joins: linked by email automatically (linkage asserted as postgres — authenticated
-- must NOT be able to read auth.users, so the assertion runs after logout)
select tests.login_as('lily@test.dev');
select lives_ok($$ select join_club((select code from invite)) $$, 'lily joins with code');
select tests.logout();
select is((select profile_id from paddlers where name='Lily L'), (select id from auth.users where email='lily@test.dev'), 'lily linked by email');

-- sam joins claiming a name
select tests.login_as('sam@test.dev');
select lives_ok($$ select join_club((select code from invite), (select id from sam_row)) $$, 'sam claims his row');
select throws_ok($$ select join_club('NOPE1234') $$, 'P0001', 'invalid invite code', 'bad code rejected');
select throws_ok($$ update profiles set role = 'head_coach' where id = auth.uid() $$, '42501', null, 'paddler cannot self-promote');
select throws_ok($$ update profiles set club_id = null where id = auth.uid() $$, '42501', null, 'club_id is RPC-managed');
select throws_ok($$ delete from profiles where id = auth.uid() $$, '42501', null, 'users cannot delete profiles');
select throws_ok($$ insert into profiles (id, display_name) values (gen_random_uuid(), 'X') $$, '42501', null, 'users cannot insert profiles');
select tests.logout();
select is((select profile_id from paddlers where name='Sam S'), (select id from auth.users where email='sam@test.dev'), 'sam linked to his row');
select is((select role from profiles where display_name='Sam'), 'paddler', 'joiner is paddler');

-- positive guard path: a coach may change another member's role
select tests.login_as('coach@test.dev');
select lives_ok($$ update profiles set role = 'coach' where display_name = 'Sam' $$, 'coach can promote another member');
select tests.logout();

select * from finish();
rollback;
