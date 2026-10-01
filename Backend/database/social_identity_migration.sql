-- Social identity / username hardening.
-- Usernames identify people for discovery and friend requests.
-- The existing account username remains the public account/person handle while
-- case-insensitive uniqueness is enforced by the database.

alter table if exists public.accounts
  add column if not exists social_discoverable boolean not null default true;

create unique index if not exists idx_accounts_username_lower
  on public.accounts(lower(trim(username)));

create index if not exists idx_accounts_social_discovery
  on public.accounts(social_discoverable)
  where social_discoverable = true;

