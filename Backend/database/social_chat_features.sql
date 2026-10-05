-- Rich direct/group chat support. Attachments remain in private Supabase
-- Storage and are only exposed through short-lived signed URLs.

alter table public.social_conversations
  add column if not exists send_policy text not null default 'all_members'
    check (send_policy in ('all_members', 'admins_only'));

alter table public.social_messages
  add column if not exists message_type text not null default 'text',
  add column if not exists view_once boolean not null default false;

update storage.buckets
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp',
      'video/mp4', 'video/webm', 'video/quicktime',
      'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/webm'
    ]
where id = 'social-media';

create table if not exists public.social_message_views (
  message_id uuid not null references public.social_messages(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  viewed_at timestamptz not null default now(),
  primary key (message_id, account_id, profile_id)
);

create table if not exists public.social_chat_polls (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null unique references public.social_messages(id) on delete cascade,
  question text not null check (char_length(question) between 1 and 500),
  options jsonb not null check (jsonb_typeof(options) = 'array'),
  created_at timestamptz not null default now(),
  closes_at timestamptz
);

create table if not exists public.social_chat_poll_votes (
  poll_id uuid not null references public.social_chat_polls(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  option_index integer not null check (option_index >= 0),
  created_at timestamptz not null default now(),
  primary key (poll_id, account_id, profile_id)
);

alter table public.social_message_views enable row level security;
alter table public.social_chat_polls enable row level security;
alter table public.social_chat_poll_votes enable row level security;
