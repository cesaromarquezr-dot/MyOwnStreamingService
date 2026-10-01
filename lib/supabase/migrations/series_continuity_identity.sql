-- Account-owned physical media and import provenance.
-- Run after streaming_service.sql and canonical_extensions.sql.
-- Provider catalog records do not create rows in physical_items or
-- profile_library; only an acquired copy and validated import can do that.

create table if not exists public.physical_items (
  id uuid primary key default gen_random_uuid(),
  external_item_id text not null,
  account_id uuid not null references public.accounts(id) on delete cascade,
  title text not null,
  format text not null check (format in ('uhd4k', 'bluRay', 'dvd', 'cd', 'other')),
  region text,
  edition text,
  media_edition_id uuid references public.media_editions(id) on delete set null,
  physical_release_ref text,
  release_date date,
  barcode text,
  catalog_number text,
  disc_count integer not null default 1 check (disc_count > 0),
  acquired_at timestamptz not null,
  item_condition text,
  ownership_status text not null default 'owned'
    check (ownership_status in ('owned', 'loaned', 'lost', 'damaged', 'sold', 'archived')),
  notes text,
  artwork_url text,
  included_extras jsonb not null default '[]'::jsonb,
  ownership_history jsonb not null default '[]'::jsonb
    check (jsonb_typeof(ownership_history) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, external_item_id)
);

create index if not exists idx_physical_items_account_status
  on public.physical_items(account_id, ownership_status, acquired_at desc);
create index if not exists idx_physical_items_barcode
  on public.physical_items(barcode)
  where barcode is not null;

create table if not exists public.physical_ownership_events (
  id uuid primary key default gen_random_uuid(),
  physical_item_id uuid not null references public.physical_items(id) on delete cascade,
  event_key text not null,
  previous_status text check (previous_status is null or previous_status in
    ('owned', 'loaned', 'lost', 'damaged', 'sold', 'archived')),
  new_status text not null check (new_status in
    ('owned', 'loaned', 'lost', 'damaged', 'sold', 'archived')),
  actor_ref text,
  note text,
  changed_at timestamptz not null default now(),
  unique (physical_item_id, event_key)
);

create index if not exists idx_physical_ownership_events_item
  on public.physical_ownership_events(physical_item_id, changed_at);

-- Associates imported server media with the physical copy and exact disc
-- content that justified its presence in the account library.
create table if not exists public.physical_item_imports (
  id uuid primary key default gen_random_uuid(),
  external_import_id text not null,
  account_id uuid not null references public.accounts(id) on delete cascade,
  physical_item_id uuid not null references public.physical_items(id) on delete cascade,
  physical_disc_ref text,
  disc_content_ref text,
  media_catalog_id uuid not null references public.media_catalog(id) on delete restrict,
  media_version_id uuid references public.media_versions(id) on delete set null,
  server_media_id uuid not null references public.server_media(id) on delete restrict,
  imported_at timestamptz not null,
  integrity_status text not null default 'unknown'
    check (integrity_status in ('unknown', 'verified', 'needs_revalidation', 'corrupt')),
  integrity_checked_at timestamptz,
  file_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (account_id, external_import_id),
  check (jsonb_typeof(file_metadata) = 'object')
);

create index if not exists idx_physical_item_imports_item
  on public.physical_item_imports(physical_item_id, imported_at desc);
create index if not exists idx_physical_item_imports_server_media
  on public.physical_item_imports(server_media_id);

alter table public.physical_items enable row level security;
alter table public.physical_ownership_events enable row level security;
alter table public.physical_item_imports enable row level security;

drop policy if exists physical_items_account on public.physical_items;
drop policy if exists physical_items_account_select on public.physical_items;
drop policy if exists physical_items_account_insert on public.physical_items;
drop policy if exists physical_items_account_update on public.physical_items;
create policy physical_items_account_select on public.physical_items
for select using (account_id = public.my_account_id());
create policy physical_items_account_insert on public.physical_items
for insert with check (account_id = public.my_account_id());
create policy physical_items_account_update on public.physical_items
for update using (account_id = public.my_account_id())
with check (account_id = public.my_account_id());

drop policy if exists physical_ownership_events_account on public.physical_ownership_events;
drop policy if exists physical_ownership_events_account_select on public.physical_ownership_events;
drop policy if exists physical_ownership_events_account_insert on public.physical_ownership_events;
create policy physical_ownership_events_account_select on public.physical_ownership_events
for select using (
  exists (
    select 1 from public.physical_items item
    where item.id = physical_item_id
      and item.account_id = public.my_account_id()
  )
);
create policy physical_ownership_events_account_insert on public.physical_ownership_events
for insert with check (
  exists (
    select 1 from public.physical_items item
    where item.id = physical_item_id
      and item.account_id = public.my_account_id()
  )
);

drop policy if exists physical_item_imports_account on public.physical_item_imports;
drop policy if exists physical_item_imports_account_select on public.physical_item_imports;
drop policy if exists physical_item_imports_account_insert on public.physical_item_imports;
create policy physical_item_imports_account_select on public.physical_item_imports
for select using (account_id = public.my_account_id());
create policy physical_item_imports_account_insert on public.physical_item_imports
for insert with check (
  account_id = public.my_account_id()
  and exists (
    select 1 from public.physical_items item
    where item.id = physical_item_id
      and item.account_id = physical_item_imports.account_id
      and item.ownership_status = 'owned'
  )
  and exists (
    select 1
    from public.server_media media
    join public.servers server on server.id = media.server_id
    where media.id = server_media_id
      and server.account_id = physical_item_imports.account_id
  )
);

drop trigger if exists physical_items_updated_at on public.physical_items;
create trigger physical_items_updated_at
before update on public.physical_items
for each row execute function public.set_updated_at();

comment on table public.physical_items is
  'Account ownership ledger for physical copies. This record is separate from catalog identity and imported server files.';
comment on table public.physical_item_imports is
  'Provenance linking owned physical items and disc content to validated server media and its canonical/version identity.';
