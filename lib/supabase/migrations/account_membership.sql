-- Account membership / individual login identities.
--
-- Run after streaming_service.sql and live_persistence.sql.
--
-- Architecture:
--   - Email identifies an individual login identity, not a streaming account.
--   - One identity can belong to multiple streaming accounts.
--   - Each streaming account owns exactly one home server.
--   - Account membership grants access to that account and its home server.
--   - Passwords remain backend-only Argon2id hashes.
--   - Invitation token hashes remain backend-only.

alter table public.accounts
  add column if not exists email text;

-- Normalize existing account email values before creating the unique index.
update public.accounts
set email = lower(trim(email))
where email is not null
  and email <> lower(trim(email));

create unique index if not exists idx_accounts_email_lower
  on public.accounts(lower(email));

-- IMPORTANT:
-- email identifies a person/login, NOT a streaming account.

create table if not exists public.member_identities (
  id uuid primary key default gen_random_uuid(),

  email text not null unique,

  -- Backend-only Argon2id password hash.
  -- Never expose this column to Flutter clients.
  password_hash text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.account_members (
  id uuid primary key default gen_random_uuid(),

  account_id uuid not null
    references public.accounts(id)
    on delete cascade,

  identity_id uuid not null
    references public.member_identities(id)
    on delete cascade,

  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),

  status text not null default 'active'
    check (status in ('pending', 'active', 'suspended', 'revoked')),

  profile_id uuid
    references public.profiles(id)
    on delete set null,

  display_name text,

  invited_at timestamptz not null default now(),
  accepted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(account_id, identity_id)
);

create table if not exists public.account_invitations (
  id uuid primary key default gen_random_uuid(),

  account_id uuid not null
    references public.accounts(id)
    on delete cascade,

  email text not null,

  role text not null default 'member'
    check (role in ('admin', 'member')),

  -- Backend-only hash of the invitation token.
  token_hash text not null unique,

  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'expired', 'revoked')),

  expires_at timestamptz not null,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists idx_account_members_account
  on public.account_members(account_id);

create index if not exists idx_account_members_identity
  on public.account_members(identity_id);

create index if not exists idx_account_members_profile
  on public.account_members(profile_id);

create index if not exists idx_account_invitations_email
  on public.account_invitations(lower(email));

create index if not exists idx_account_invitations_account
  on public.account_invitations(account_id);

create index if not exists idx_account_invitations_status
  on public.account_invitations(status);

create index if not exists idx_account_invitations_expires_at
  on public.account_invitations(expires_at);

-- ---------------------------------------------------------------------------
-- Email normalization
-- ---------------------------------------------------------------------------

create or replace function public.normalize_member_identity_email()
returns trigger
language plpgsql
as $$
begin
  new.email = lower(trim(new.email));
  return new;
end;
$$;

drop trigger if exists trg_normalize_member_identity_email
  on public.member_identities;

create trigger trg_normalize_member_identity_email
before insert or update of email
on public.member_identities
for each row
execute function public.normalize_member_identity_email();

create or replace function public.normalize_account_invitation_email()
returns trigger
language plpgsql
as $$
begin
  new.email = lower(trim(new.email));
  return new;
end;
$$;

drop trigger if exists trg_normalize_account_invitation_email
  on public.account_invitations;

create trigger trg_normalize_account_invitation_email
before insert or update of email
on public.account_invitations
for each row
execute function public.normalize_account_invitation_email();

-- ---------------------------------------------------------------------------
-- Updated-at triggers
-- ---------------------------------------------------------------------------

create or replace function public.set_member_identity_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_member_identity_updated_at
  on public.member_identities;

create trigger trg_member_identity_updated_at
before update
on public.member_identities
for each row
execute function public.set_member_identity_updated_at();

create or replace function public.set_account_member_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_account_member_updated_at
  on public.account_members;

create trigger trg_account_member_updated_at
before update
on public.account_members
for each row
execute function public.set_account_member_updated_at();

-- ---------------------------------------------------------------------------
-- Backfill existing account owners
-- ---------------------------------------------------------------------------
--
-- Existing accounts are converted into individual login identities.
--
-- The existing backend-only Argon2id credential hash is reused.
--
-- An account owner becomes an account_members row connecting:
--
--   member_identities -> account_members -> accounts
--
-- This does NOT create another account or another home server.

insert into public.member_identities (
  email,
  password_hash
)
select
  lower(trim(a.email)),
  c.password_hash
from public.accounts a
join public.account_private_credentials c
  on c.account_id = a.id
where a.email is not null
  and trim(a.email) <> ''
on conflict (email) do update
set password_hash = excluded.password_hash;

insert into public.account_members (
  account_id,
  identity_id,
  role,
  status,
  display_name,
  accepted_at
)
select
  a.id,
  i.id,
  'owner',
  'active',
  a.username,
  coalesce(a.created_at, now())
from public.accounts a
join public.member_identities i
  on lower(i.email) = lower(trim(a.email))
where a.email is not null
  and trim(a.email) <> ''
on conflict (account_id, identity_id) do update
set
  role = 'owner',
  status = 'active',
  display_name = excluded.display_name,
  accepted_at = coalesce(
    public.account_members.accepted_at,
    excluded.accepted_at
  );

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
--
-- Membership administration is performed by the authenticated backend using
-- the Supabase service-role connection.
--
-- Flutter clients do not receive:
--   - password hashes
--   - invitation token hashes
--
-- The service-role key must never be embedded in Flutter.

alter table public.member_identities
  enable row level security;

alter table public.account_members
  enable row level security;

alter table public.account_invitations
  enable row level security;

-- ---------------------------------------------------------------------------
-- Documentation
-- ---------------------------------------------------------------------------

comment on table public.member_identities is
  'Login identities. Email identifies a person, not a streaming account. Passwords are Argon2id hashes only.';

comment on column public.member_identities.password_hash is
  'Backend-only Argon2id password hash. Never expose to normal clients.';

comment on table public.account_members is
  'Membership connects a login identity to an account. One identity may belong to multiple accounts.';

comment on column public.account_members.account_id is
  'Streaming account whose server and application state this membership can access.';

comment on column public.account_members.identity_id is
  'Individual login identity. The same identity may belong to multiple accounts.';

comment on table public.account_invitations is
  'Pending invitations to join an existing account without creating another home server.';

comment on column public.account_invitations.token_hash is
  'Backend-only hash of the invitation token. The raw invitation token is never stored.';