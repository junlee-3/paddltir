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
