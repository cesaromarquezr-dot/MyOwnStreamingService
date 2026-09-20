-- Live persistence bridge for the custom home-server backend.
-- Supabase stores account/application metadata only. Physical media files
-- remain on each user's own home server.

-- ---------------------------------------------------------------------------
-- Stable external IDs
-- ---------------------------------------------------------------------------
alter table public.accounts
  add column if not exists external_account_id text unique;

alter table public.profiles
  add column if not exists external_profile_id text unique;


-- ---------------------------------------------------------------------------
-- Private backend credentials
-- ---------------------------------------------------------------------------
-- This table intentionally has NO client RLS policy. Only the backend
-- service-role connection should read/write it. Passwords are Argon2id hashes,
-- never plaintext passwords.
create table if not exists public.account_private_credentials (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  external_account_id text not null unique,
  password_hash text not null,
  security_question text not null default '',
  security_answer_hash text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_private_credentials_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_account_private_credentials_updated_at
on public.account_private_credentials;
create trigger trg_account_private_credentials_updated_at
before update on public.account_private_credentials
for each row execute function public.set_private_credentials_updated_at();

alter table public.account_private_credentials enable row level security;

-- No policy is intentionally created here.
-- Service-role backend access bypasses RLS.

-- ---------------------------------------------------------------------------
-- Profile customization snapshot
-- ---------------------------------------------------------------------------
create table if not exists public.profile_customization_snapshots (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  home_configuration jsonb not null default '{}'::jsonb,
  details_configuration jsonb not null default '{}'::jsonb,
  platform_configuration jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_profile_customization_snapshots_updated_at
on public.profile_customization_snapshots;
create trigger trg_profile_customization_snapshots_updated_at
before update on public.profile_customization_snapshots
for each row execute function public.set_private_credentials_updated_at();

alter table public.profile_customization_snapshots enable row level security;

create policy profile_customization_own
on public.profile_customization_snapshots
for all
using (
  profile_id in (
    select id from public.profiles
    where account_id = public.my_account_id()
  )
)
with check (
  profile_id in (
    select id from public.profiles
    where account_id = public.my_account_id()
  )
);


-- Keep the global catalog independent from an individual account's server.
-- Deleting one account's server index must never delete a title catalog row
-- that another account/server may still reference.
alter table public.server_media
  drop constraint if exists server_media_media_catalog_id_fkey;

alter table public.server_media
  alter column media_catalog_id drop not null;

alter table public.server_media
  add constraint server_media_media_catalog_id_fkey
  foreign key (media_catalog_id)
  references public.media_catalog(id)
  on delete set null;

-- ---------------------------------------------------------------------------
-- Backfill the new stable external account/profile IDs where possible.
-- ---------------------------------------------------------------------------
update public.accounts
set external_account_id = id::text
where external_account_id is null;

update public.profiles
set external_profile_id = id::text
where external_profile_id is null;


-- The application backend uses these indexes for deterministic lookup.
create index if not exists idx_accounts_external_account_id
  on public.accounts(external_account_id);
create index if not exists idx_profiles_external_profile_id
  on public.profiles(external_profile_id);

comment on table public.account_private_credentials is
  'Backend-only credential store. Contains Argon2id password/security-answer hashes, never plaintext passwords.';

comment on table public.profile_customization_snapshots is
  'Profile-scoped UI customization state synchronized from the backend; physical media is never stored here.';


-- Security: MFA challenge state stores only a hash and expiration, never the plaintext code.
alter table public.account_private_credentials add column if not exists mfa_enabled boolean not null default false;
alter table public.account_private_credentials add column if not exists mfa_challenge_hash text;
alter table public.account_private_credentials add column if not exists mfa_challenge_expires_at timestamptz;
