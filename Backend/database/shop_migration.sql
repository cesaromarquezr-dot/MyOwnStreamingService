## -- Global marketplace association index.

-- Only lightweight entity metadata is stored here. Physical media remains on
-- each account server. The client can later add discoverability/privacy
-- controls without changing the product association model.

create table if not exists public.shop_entities (
entity_key text primary key,

entity_type text not null
check (length(trim(entity_type)) > 0),

entity_id text not null
check (length(trim(entity_id)) > 0),

name text not null
check (length(trim(name)) > 0),

subtitle text,

-- External account identifier only. No credentials or authentication
-- material is stored in this global association index.
account_external_id text,

is_public boolean not null default true,

updated_at timestamptz not null default now()
);

create index if not exists shop_entities_name_lower_idx
on public.shop_entities (lower(name));

create index if not exists shop_entities_type_idx
on public.shop_entities (entity_type);

create index if not exists shop_entities_account_idx
on public.shop_entities (account_external_id);

-- Useful for resolving all globally associated entities of the same logical
-- type without requiring callers to know the generated entity_key.
create index if not exists shop_entities_type_entity_idx
on public.shop_entities (entity_type, entity_id);

comment on table public.shop_entities is
'Global lightweight marketplace association metadata. Physical media remains on account servers.';

comment on column public.shop_entities.entity_key is
'Stable globally unique association key for the marketplace entity.';

comment on column public.shop_entities.entity_type is
'Logical entity category, such as movie, show, music, recording, artist, collection, or product.';

comment on column public.shop_entities.entity_id is
'Identifier of the entity in its owning account/server domain.';

comment on column public.shop_entities.account_external_id is
'Non-secret external account identifier used to associate the entity with its owning account server.';

comment on column public.shop_entities.is_public is
'Whether this lightweight association is discoverable through the global marketplace index.';
