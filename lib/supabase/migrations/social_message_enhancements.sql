-- Message editing timestamps already exist in the base social schema; this
-- forward-compatible migration adds persistent pin state for conversation UI.
alter table if exists public.social_messages
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists is_pinned boolean not null default false;

create index if not exists social_messages_pinned_idx
  on public.social_messages(conversation_id, is_pinned, created_at desc)
  where is_pinned = true and deleted_at is null;
