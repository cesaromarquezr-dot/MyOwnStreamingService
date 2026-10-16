-- Social messaging compile/feature contract repair.
-- This migration is additive and safe to run more than once.
-- All access to these records is intended to go through the authenticated backend.

alter table public.social_messages
  add column if not exists is_pinned boolean not null default false,
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_by_account_id uuid
    references public.accounts(id) on delete set null;

create index if not exists social_messages_pinned_conversation_idx
  on public.social_messages(conversation_id, pinned_at desc)
  where is_pinned = true and deleted_at is null;

create table if not exists public.social_profile_e2ee_keys (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  device_id text not null default 'default',
  device_name text not null default '',
  key_id text not null default '',
  algorithm text not null default 'unspecified',
  key_fingerprint text not null default '',
  public_key text not null check (char_length(public_key) between 1 and 8192),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id, device_id)
);

create index if not exists social_profile_e2ee_keys_profile_idx
  on public.social_profile_e2ee_keys(profile_id, updated_at desc);

alter table public.social_profile_e2ee_keys enable row level security;
