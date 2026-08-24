-- supabase/migrations/20260822000200_functions.sql

-- ---------- helpers (stable, security definer so they can read profiles regardless of RLS) ----------
create or replace function auth_club_id() returns uuid
language sql stable security definer set search_path = public as $$
  select club_id from profiles where id = auth.uid()
$$;

create or replace function is_coach() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('head_coach','coach') from profiles where id = auth.uid()), false)
$$;

create or replace function my_paddler_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from paddlers where profile_id = auth.uid()
$$;

create or replace function crew_club(p_crew uuid) returns uuid
language sql stable security definer set search_path = public as $$ select club_id from crews where id = p_crew $$;
create or replace function session_club(p_session uuid) returns uuid
language sql stable security definer set search_path = public as $$ select club_id from sessions where id = p_session $$;
create or replace function race_club(p_race uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select s.club_id from races r join sessions s on s.id = r.session_id where r.id = p_race $$;
create or replace function heat_club(p_heat uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select s.club_id from heats h join races r on r.id = h.race_id join sessions s on s.id = r.session_id where h.id = p_heat $$;

-- unambiguous 8-char codes (no 0/O/1/I), drawn from the CSPRNG
create or replace function gen_invite_code() returns text
language plpgsql volatile set search_path = extensions, public as $$
declare alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; code text := ''; b bytea; i int;
begin
  b := gen_random_bytes(8);
  for i in 0..7 loop
    code := code || substr(alphabet, 1 + (get_byte(b, i) % 32), 1);
  end loop;
  return code;
end $$;
alter table clubs alter column invite_code set default gen_invite_code();

-- ---------- profile lifecycle ----------
create or replace function link_paddler_by_email(p_user uuid, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare p record; n int;
begin
  if p_email is null then return; end if;
  select count(*) into n from paddlers where email = lower(p_email) and profile_id is null and archived_at is null;
  if n = 1 then
    select * into p from paddlers where email = lower(p_email) and profile_id is null and archived_at is null;
    perform set_config('paddltir.allow_profile_admin', '1', true);
    update profiles set club_id = p.club_id, role = coalesce(role, 'paddler') where id = p_user and club_id is null;
    if found then
      update paddlers set profile_id = p_user where id = p.id;
    end if;
    perform set_config('paddltir.allow_profile_admin', '0', true);
  end if;
end $$;

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  -- link by email only once the address is verified (OAuth + local test users arrive confirmed)
  if new.email_confirmed_at is not null then
    perform link_paddler_by_email(new.id, new.email);
  end if;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create or replace function handle_user_confirmed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform link_paddler_by_email(new.id, new.email);
  return new;
end $$;
create trigger on_auth_user_confirmed after update on auth.users for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function handle_user_confirmed();

-- club_id may only change via RPCs; role may be changed by coaches for other members of their club
create or replace function protect_profile_columns() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('paddltir.allow_profile_admin', true), '') = '1' then return new; end if;
  if auth.uid() is null then return new; end if;  -- service role / migrations / seed: trusted backend
  if new.club_id is distinct from old.club_id then
    raise exception 'club_id is managed by join_club/create_club' using errcode = '42501';
  end if;
  if new.role is distinct from old.role then
    if not (is_coach() and old.id is distinct from auth.uid()
            and old.club_id is not distinct from auth_club_id() and old.club_id is not null) then
      raise exception 'only a coach may change another member''s role' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger protect_profile before update on profiles for each row execute function protect_profile_columns();

-- ---------- RPCs ----------
create or replace function create_club(p_name text) returns clubs
language plpgsql security definer set search_path = public as $$
declare c clubs; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if (select club_id from profiles where id = uid) is not null then raise exception 'already in a club'; end if;
  insert into clubs (name, created_by) values (trim(p_name), uid) returning * into c;
  perform set_config('paddltir.allow_profile_admin', '1', true);
  update profiles set club_id = c.id, role = 'head_coach' where id = uid;
  if not found then raise exception 'profile missing for user'; end if;
  insert into category_rules (club_id, category, boat_size, min_women, max_women, min_men, max_men) values
    (c.id, 'mixed', 'standard', 8, 12, 8, 12),
    (c.id, 'mixed', 'small', 4, 6, 4, 6),
    (c.id, 'women', 'standard', null, null, null, 0),
    (c.id, 'women', 'small', null, null, null, 0);
  perform set_config('paddltir.allow_profile_admin', '0', true);
  return c;
end $$;

create or replace function claimable_paddlers(p_code text) returns table (id uuid, name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.name from paddlers p join clubs c on c.id = p.club_id
  where c.invite_code = upper(trim(p_code)) and p.profile_id is null and p.archived_at is null
    and p.email is null
  order by p.name
$$;

create or replace function join_club(p_code text, p_paddler_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); cid uuid; existing uuid; mail text;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  select id into cid from clubs where invite_code = upper(trim(p_code));
  if cid is null then raise exception 'invalid invite code'; end if;
  select club_id into existing from profiles where id = uid;
  if existing is not null and existing <> cid then raise exception 'already in another club'; end if;
  perform set_config('paddltir.allow_profile_admin', '1', true);
  update profiles set club_id = cid, role = coalesce(role, 'paddler') where id = uid;
  select email into mail from auth.users where id = uid;
  if p_paddler_id is not null then
    update paddlers set profile_id = uid
      where id = p_paddler_id and club_id = cid and profile_id is null and archived_at is null
        and (email is null or email = lower(mail));
    if not found then raise exception 'paddler not claimable'; end if;
  else
    update paddlers set profile_id = uid
      where club_id = cid and profile_id is null and archived_at is null and email = lower(mail);
  end if;
  perform set_config('paddltir.allow_profile_admin', '0', true);
  return cid;
end $$;

create or replace function regenerate_invite_code() returns text
language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if not is_coach() then raise exception 'coaches only' using errcode = '42501'; end if;
  update clubs set invite_code = gen_invite_code() where id = auth_club_id() returning invite_code into code;
  return code;
end $$;

create or replace function session_headcount(p_session_id uuid) returns table (status availability_status, n bigint)
language sql stable security definer set search_path = public as $$
  select a.status, count(*) from availability a
  where a.session_id = p_session_id and session_club(p_session_id) = auth_club_id()
  group by a.status
$$;

-- table access for API roles: privileges are broad here; ROW access is constrained by
-- RLS in the next migration. anon gets nothing (and is revoked again in 0003).
-- Empirically required: tables created by the migration role carry no ACL for
-- authenticated, so RLS policies alone would still yield "permission denied".
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated, service_role;
revoke insert, delete on profiles from authenticated;  -- profiles are created by the signup trigger and never deleted by users
revoke truncate on all tables in schema public from anon, authenticated;
grant execute on all functions in schema public to service_role;

-- lock down execution
revoke execute on all functions in schema public from public, anon;
grant execute on function auth_club_id(), is_coach(), my_paddler_id(), crew_club(uuid), session_club(uuid), race_club(uuid), heat_club(uuid) to authenticated;
grant execute on function create_club(text), join_club(text, uuid), claimable_paddlers(text), regenerate_invite_code(), session_headcount(uuid) to authenticated;
