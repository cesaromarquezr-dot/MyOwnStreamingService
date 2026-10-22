-- Hybrid genre metadata support. Apply after media_universe_foundation.sql and
-- discovery_catalog.sql. Additive and safe to rerun.
-- Genres are stored as canonical components; these fields are optional display hints.

begin;

alter table if exists public.media_works
  add column if not exists primary_genre text,
  add column if not exists genre_blend_label_override text;

alter table if exists public.external_media_catalog
  add column if not exists primary_genre text,
  add column if not exists genre_blend_label_override text;

alter table if exists public.tv_content_intelligence
  add column if not exists primary_genre text,
  add column if not exists genre_blend_label_override text;

commit;
