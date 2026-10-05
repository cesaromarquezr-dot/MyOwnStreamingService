-- Per-member delivery watermarks and short-lived typing presence for chats.

alter table public.social_conversation_members
  add column if not exists last_delivered_at timestamptz,
  add column if not exists chat_background_color text,
  add column if not exists chat_background_image_path text;

alter table public.social_messages
  add column if not exists text_format jsonb not null default '{}'::jsonb;

create table if not exists public.social_profile_presence (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  availability text not null default 'active'
    check (availability in ('active', 'away', 'busy')),
  activity_type text,
  activity_text text,
  nickname text,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id),
  check (activity_type is null or activity_type in ('watching', 'listening'))
);

create index if not exists social_profile_presence_last_seen_idx
  on public.social_profile_presence(last_seen_at);

create table if not exists public.social_conversation_typing (
  conversation_id uuid not null,
  account_id uuid not null,
  profile_id text not null,
  typing_until timestamptz not null,
  primary key (conversation_id, account_id, profile_id),
  foreign key (conversation_id, account_id, profile_id)
    references public.social_conversation_members
      (conversation_id, account_id, profile_id)
    on delete cascade
);

create index if not exists social_conversation_typing_expiry_idx
  on public.social_conversation_typing(conversation_id, typing_until);

alter table public.social_conversation_typing enable row level security;
alter table public.social_profile_presence enable row level security;
