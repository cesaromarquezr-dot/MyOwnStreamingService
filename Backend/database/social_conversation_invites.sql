-- Secure, expiring invite links for social group conversations.
-- Apply using the Supabase SQL editor before enabling group-chat share links.

create table if not exists public.social_conversation_invites (
  token text primary key,
  conversation_id uuid not null references public.social_conversations(id) on delete cascade,
  created_by_account_id uuid references public.accounts(id) on delete set null,
  created_by_profile_id text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  max_uses integer not null default 100 check (max_uses between 1 and 10000),
  used_count integer not null default 0 check (used_count >= 0),
  last_used_at timestamptz,
  revoked_at timestamptz
);

create index if not exists social_conversation_invites_conversation_idx
  on public.social_conversation_invites(conversation_id, created_at desc);

create index if not exists social_conversation_invites_expiry_idx
  on public.social_conversation_invites(expires_at)
  where revoked_at is null;

alter table public.social_conversation_invites enable row level security;
-- Access is performed by the authenticated backend with its server-side key.
-- Do not add an anon/authenticated table policy for this invite-token table.
