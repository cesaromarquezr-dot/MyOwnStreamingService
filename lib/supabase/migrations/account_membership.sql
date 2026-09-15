-- Account membership / individual login identities.
-- Run after streaming_service.sql and live_persistence.sql.

alter table public.accounts add column if not exists email text;
create unique index if not exists idx_accounts_email_lower on public.accounts(lower(email));
-- IMPORTANT: email identifies a person/login, NOT a streaming account.
-- One identity can belong to multiple accounts. Each account owns exactly
-- one home server, and membership grants access to that account's server.

create table if not exists public.member_identities (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.account_members (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  identity_id uuid not null references public.member_identities(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'active' check (status in ('pending','active','suspended','revoked')),
  profile_id uuid references public.profiles(id) on delete set null,
  display_name text,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(account_id, identity_id)
);

create table if not exists public.account_invitations (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  email text not null,
  role text not null default 'member' check (role in ('admin','member')),
  token_hash text not null unique,
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz not null,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz
);

create index if not exists idx_account_members_account on public.account_members(account_id);
create index if not exists idx_account_members_identity on public.account_members(identity_id);
create index if not exists idx_account_invitations_email on public.account_invitations(lower(email));
create index if not exists idx_account_invitations_account on public.account_invitations(account_id);

create or replace function public.set_member_identity_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_member_identity_updated_at on public.member_identities;
create trigger trg_member_identity_updated_at
before update on public.member_identities
for each row execute function public.set_member_identity_updated_at();

create or replace function public.set_account_member_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_account_member_updated_at on public.account_members;
create trigger trg_account_member_updated_at
before update on public.account_members
for each row execute function public.set_account_member_updated_at();

-- Backfill the existing account owner as an individual login identity.
-- This uses the existing backend-only Argon2id credential hash.
insert into public.member_identities (email, password_hash)
select lower(a.email), c.password_hash
from public.accounts a
join public.account_private_credentials c on c.account_id = a.id
where a.email is not null and a.email <> ''
on conflict (email) do update set password_hash = excluded.password_hash;

insert into public.account_members (
  account_id, identity_id, role, status, display_name, accepted_at
)
select a.id, i.id, 'owner', 'active', a.username, coalesce(a.created_at, now())
from public.accounts a
join public.member_identities i on lower(i.email) = lower(a.email)
on conflict (account_id, identity_id) do update
set role = 'owner', status = 'active', display_name = excluded.display_name;

-- RLS: service-role backend performs membership administration. Clients do not
-- receive password hashes or invitation token hashes.
alter table public.member_identities enable row level security;
alter table public.account_members enable row level security;
alter table public.account_invitations enable row level security;

comment on table public.member_identities is
  'Login identities. Email identifies a person, not a streaming account. Passwords are Argon2id hashes only.';
comment on table public.account_members is
  'Membership connects a login identity to an account. One identity may belong to multiple accounts.';
comment on table public.account_invitations is
  'Pending invitations to join an existing account without creating another home server.';
