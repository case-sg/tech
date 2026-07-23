create table if not exists identity (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('machine','surface','target')),
  anchor text not null,
  handle text not null unique,
  label text,
  owner text not null default 'shared' check (owner in ('AJ','JJ','shared')),
  parent uuid references identity(id),
  dispatchable boolean not null default false,
  app text,
  profile_path text,
  account text,
  purpose text,
  serial text,
  setup_version text,
  first_registered_at timestamptz not null default now(),
  last_registered_at timestamptz not null default now(),
  attributes jsonb not null default '{}'::jsonb,
  unique (kind, anchor)
  );

create table if not exists fact (
  id uuid primary key default gen_random_uuid(),
  namespace text not null,
  key text not null,
  revision integer,
  value jsonb not null,
  observed_at timestamptz not null,
  written_at timestamptz not null default now(),
  asserted_by uuid references identity(id),
  origin text not null check (origin in ('human','script','claude')),
  status text not null check (status in ('proposed','current','superseded','rejected')),
  supersedes uuid references fact(id),
  note text
  );

create unique index if not exists fact_ns_key_rev on fact (namespace, key, revision) where revision is not null;
create unique index if not exists fact_one_current on fact (namespace, key) where status = 'current';
create index if not exists fact_lookup on fact (namespace, key, status);

create table if not exists write_attempt (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  namespace text,
  key text,
  attempted_by uuid references identity(id),
  origin text,
  reason text not null,
  detail text,
  payload jsonb
  );

create table if not exists lease (
  id uuid primary key default gen_random_uuid(),
  target uuid not null references identity(id),
  task text not null,
  holder uuid references identity(id),
  acquired_at timestamptz not null default now(),
  expires_at timestamptz not null,
  released_at timestamptz
  );

create unique index if not exists lease_one_active on lease (target) where released_at is null;

create or replace view fact_current as
select id, namespace, key, revision, value, observed_at, written_at, asserted_by, origin, note
from fact where status = 'current';

alter table identity enable row level security;
alter table fact enable row level security;
alter table write_attempt enable row level security;
alter table lease enable row level security;

create policy identity_read on identity for select to authenticated using (true);
create policy fact_read on fact for select to authenticated using (true);
create policy write_attempt_read on write_attempt for select to authenticated using (true);
create policy lease_read on lease for select to authenticated using (true);
