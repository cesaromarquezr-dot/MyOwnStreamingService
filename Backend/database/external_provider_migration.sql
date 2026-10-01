create table if not exists public.external_provider_links (
  id uuid primary key default gen_random_uuid(),
  media_id text not null,
  provider text not null,
  provider_media_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique(media_id, provider)
);
create index if not exists idx_external_provider_links_lookup on public.external_provider_links(provider, provider_media_id);
