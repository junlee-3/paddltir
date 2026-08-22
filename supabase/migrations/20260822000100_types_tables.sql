create extension if not exists pgcrypto;

create type user_role as enum ('head_coach','coach','paddler');
create type side_pref as enum ('left','right','either');
create type boat_side as enum ('left','right');
create type gender as enum ('female','male');
create type seat_pref as enum ('stroke','pace','engine','sprint','none');
create type boat_role as enum ('paddler','drummer','sweep');
create type boat_size as enum ('small','standard');
create type crew_category as enum ('open','women','mixed');
create type session_kind as enum ('training','race_day');
create type availability_status as enum ('in','out','maybe');
create type erg_source as enum ('coach','self');

create or replace function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create table clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80),
  invite_code text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  club_id uuid references clubs(id) on delete set null,
  role user_role,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table paddlers (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs(id) on delete cascade,
  profile_id uuid unique references profiles(id) on delete set null,
  name text not null check (length(trim(name)) between 1 and 80),
  email text check (email is null or email = lower(email)),
  weight_kg numeric(5,1) not null check (weight_kg > 20 and weight_kg < 250),
  preferred_side side_pref not null default 'either',
  gender gender not null,
  seat_preference seat_pref not null default 'none',
  boat_role boat_role not null default 'paddler',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index paddlers_club_email_uq on paddlers (club_id, email) where email is not null;
create index paddlers_club_idx on paddlers (club_id);

create table erg_tests (
  id uuid primary key default gen_random_uuid(),
  paddler_id uuid not null references paddlers(id) on delete cascade,
  tested_at date not null default current_date,
  metres integer not null check (metres between 1 and 2000),
  source erg_source not null,
  recorded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index erg_tests_paddler_idx on erg_tests (paddler_id, tested_at desc, created_at desc);

create table crews (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  age_division text not null check (age_division in ('16U','18U','24U','Premier','Senior A','Senior B','Senior C')),
  category crew_category not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index crews_club_idx on crews (club_id);

create table crew_members (
  crew_id uuid not null references crews(id) on delete cascade,
  paddler_id uuid not null references paddlers(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (crew_id, paddler_id)
);

create table sessions (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references clubs(id) on delete cascade,
  kind session_kind not null,
  title text not null check (length(trim(title)) between 1 and 120),
  starts_at timestamptz not null,
  venue text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index sessions_club_time_idx on sessions (club_id, starts_at);

create table availability (
  session_id uuid not null references sessions(id) on delete cascade,
  paddler_id uuid not null references paddlers(id) on delete cascade,
  status availability_status not null,
  note text,
  updated_at timestamptz not null default now(),
  primary key (session_id, paddler_id)
);
create index availability_paddler_idx on availability (paddler_id);

create table races (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions(id) on delete cascade,
  crew_id uuid not null references crews(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  boat_size boat_size not null default 'standard',
  distance_m integer check (distance_m is null or distance_m between 100 and 5000),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index races_session_idx on races (session_id);

create table heats (
  id uuid primary key default gen_random_uuid(),
  race_id uuid not null references races(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 60),
  sort_order integer not null default 0,
  drummer_id uuid references paddlers(id) on delete set null,
  sweep_id uuid references paddlers(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index heats_race_idx on heats (race_id);

create table seats (
  heat_id uuid not null references heats(id) on delete cascade,
  bench smallint not null check (bench between 1 and 10),
  side boat_side not null,
  paddler_id uuid not null references paddlers(id) on delete cascade,
  locked boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (heat_id, bench, side),
  unique (heat_id, paddler_id)
);

create table heat_reserves (
  heat_id uuid not null references heats(id) on delete cascade,
  paddler_id uuid not null references paddlers(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (heat_id, paddler_id)
);

create table category_rules (
  club_id uuid not null references clubs(id) on delete cascade,
  category crew_category not null,
  boat_size boat_size not null,
  min_women integer check (min_women is null or min_women >= 0),
  max_women integer check (max_women is null or max_women >= 0),
  min_men integer check (min_men is null or min_men >= 0),
  max_men integer check (max_men is null or max_men >= 0),
  updated_at timestamptz not null default now(),
  primary key (club_id, category, boat_size)
);

create table optimize_cache (
  input_hash text primary key,
  club_id uuid references clubs(id) on delete cascade,
  result jsonb not null,
  created_at timestamptz not null default now()
);

-- updated_at triggers
do $$ declare t text;
begin
  foreach t in array array['clubs','profiles','paddlers','crews','sessions','availability','races','heats','seats','category_rules'] loop
    execute format('create trigger %I_updated_at before update on %I for each row execute function set_updated_at()', t, t);
  end loop;
end $$;
