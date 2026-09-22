-- Live persistence bridge for the custom home-server backend.
--
-- Supabase stores account/application metadata only.
-- Physical media files remain on each user's own home server.
--
-- Synchronization architecture:
--
--   Flutter
--      |
--      | authenticated application session
--      v
--   Custom Dart backend
--      |
--      | sanitized metadata / backend-only credentials
--      v
--   Supabase
--
-- The Flutter client must never receive the Supabase service-role key.

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
--
-- This table intentionally has NO client RLS policy.
--
-- Only the backend service-role connection should read/write this table.
--
-- Passwords and security answers are stored as Argon2id hashes.
-- Plaintext passwords and security answers must never be stored.
--
-- MFA challenge state stores only a hash and expiration timestamp.
-- The plaintext MFA code must never be persisted.

create table if not exists public.account_private_credentials (
  account_id uuid primary key
    references public.accounts(id)
    on delete cascade,

  external_account_id text not null unique,

  password_hash text not null,

  security_question text not null default '',
  security_answer_hash text not null default '',

  mfa_enabled boolean not null default false,
  mfa_challenge_hash text,
  mfa_challenge_expires_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Support existing installations where the table was created before MFA
-- columns were introduced.

alter table public.account_private_credentials
  add column if not exists mfa_enabled boolean not null default false;

alter table public.account_private_credentials
  add column if not exists mfa_challenge_hash text;

alter table public.account_private_credentials
  add column if not exists mfa_challenge_expires_at timestamptz;


-- ---------------------------------------------------------------------------
-- Private credential updated-at trigger
-- ---------------------------------------------------------------------------

create or replace function public.set_private_credentials_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_account_private_credentials_updated_at
  on public.account_private_credentials;

create trigger trg_account_private_credentials_updated_at
before update
on public.account_private_credentials
for each row
execute function public.set_private_credentials_updated_at();

alter table public.account_private_credentials
  enable row level security;

-- No client policy is intentionally created here.
--
-- The backend uses the service-role connection for credential operations.
-- Service-role access bypasses RLS.


-- ---------------------------------------------------------------------------
-- Profile customization snapshot
-- ---------------------------------------------------------------------------
--
-- Stores profile-specific UI state only.
-- This does not contain physical media files.

create table if not exists public.profile_customization_snapshots (
  profile_id uuid primary key
    references public.profiles(id)
    on delete cascade,

  home_configuration jsonb not null default '{}'::jsonb,

  details_configuration jsonb not null default '{}'::jsonb,

  platform_configuration jsonb not null default '{}'::jsonb,

  updated_at timestamptz not null default now()
);


-- Dedicated timestamp trigger for profile customization.

create or replace function public.set_profile_customization_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profile_customization_snapshots_updated_at
  on public.profile_customization_snapshots;

create trigger trg_profile_customization_snapshots_updated_at
before update
on public.profile_customization_snapshots
for each row
execute function public.set_profile_customization_updated_at();

alter table public.profile_customization_snapshots
  enable row level security;


-- ---------------------------------------------------------------------------
-- Profile customization RLS
-- ---------------------------------------------------------------------------
--
-- A signed-in Supabase client may access customization belonging to a profile
-- whose account matches public.my_account_id().
--
-- Backend service-role access continues to bypass RLS.

drop policy if exists profile_customization_own
  on public.profile_customization_snapshots;

create policy profile_customization_own
on public.profile_customization_snapshots
for all
using (
  profile_id in (
    select id
    from public.profiles
    where account_id = public.my_account_id()
  )
)
with check (
  profile_id in (
    select id
    from public.profiles
    where account_id = public.my_account_id()
  )
);


-- ---------------------------------------------------------------------------
-- Server media -> global catalog relationship
-- ---------------------------------------------------------------------------
--
-- The global media catalog is independent from an individual account's
-- server index.
--
-- Deleting one account's server media record must never delete a catalog
-- title that another account/server may still reference.
--
-- A server_media row may temporarily have no catalog association when the
-- catalog record is unavailable or has been removed.

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
-- Backfill stable external account/profile IDs
-- ---------------------------------------------------------------------------
--
-- Existing UUID primary keys are used as deterministic external IDs when
-- no previous external ID exists.

update public.accounts
set external_account_id = id::text
where external_account_id is null;

update public.profiles
set external_profile_id = id::text
where external_profile_id is null;


-- ---------------------------------------------------------------------------
-- Deterministic external-ID lookup indexes
-- ---------------------------------------------------------------------------

create index if not exists idx_accounts_external_account_id
  on public.accounts(external_account_id);

create index if not exists idx_profiles_external_profile_id
  on public.profiles(external_profile_id);


-- ---------------------------------------------------------------------------
-- Documentation
-- ---------------------------------------------------------------------------

comment on table public.account_private_credentials is
  'Backend-only credential store. Contains Argon2id password/security-answer hashes and hashed MFA challenge state, never plaintext credentials.';

comment on column public.account_private_credentials.password_hash is
  'Argon2id password hash. Backend-only; never expose to normal clients.';

comment on column public.account_private_credentials.security_answer_hash is
  'Argon2id hash of the security answer. Backend-only; never store the plaintext answer.';

comment on column public.account_private_credentials.mfa_enabled is
  'Whether MFA is enabled for this account.';

comment on column public.account_private_credentials.mfa_challenge_hash is
  'Hash of the current MFA challenge code. The plaintext code must never be stored.';

comment on column public.account_private_credentials.mfa_challenge_expires_at is
  'Expiration time for the current MFA challenge.';

comment on table public.profile_customization_snapshots is
  'Profile-scoped UI customization state synchronized from the backend; physical media is never stored here.';

comment on column public.profile_customization_snapshots.home_configuration is
  'Serialized profile home-screen customization state.';

comment on column public.profile_customization_snapshots.details_configuration is
  'Serialized profile media-details customization state.';

comment on column public.profile_customization_snapshots.platform_configuration is
  'Serialized profile platform/UI customization state.';

comment on column public.accounts.external_account_id is
  'Stable application-facing account identifier used by the custom backend synchronization layer.';

comment on column public.profiles.external_profile_id is
  'Stable application-facing profile identifier used by the custom backend synchronization layer.';

comment on column public.server_media.media_catalog_id is
  'Optional reference to the global canonical media catalog. Removing a catalog row does not remove the server media record.';