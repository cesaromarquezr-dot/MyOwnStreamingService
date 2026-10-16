-- End-to-end encrypted text chat public-key directory.
-- Only public X25519 keys are stored. Never add private keys or message plaintext here.
create table if not exists public.social_profile_e2ee_keys (
  account_id uuid not null references public.accounts(id) on delete cascade,
  profile_id text not null,
  public_key text not null check (char_length(public_key) between 40 and 128),
  updated_at timestamptz not null default now(),
  primary key (account_id, profile_id)
);

alter table public.social_profile_e2ee_keys enable row level security;
-- No client RLS policies by design; trusted backend service-role access only.
revoke all on public.social_profile_e2ee_keys from anon, authenticated;
grant select, insert, update, delete on public.social_profile_e2ee_keys to service_role;
