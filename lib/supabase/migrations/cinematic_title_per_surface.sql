-- Independent title artwork preferences for the Home hero and Details page.
-- All columns are additive; legacy rows inherit the prior shared artwork mode.
alter table if exists public.external_media_catalog
  add column if not exists hero_title_artwork_mode text not null default 'inherit',
  add column if not exists detail_title_artwork_mode text not null default 'inherit',
  add column if not exists hero_title_artwork_url text,
  add column if not exists detail_title_artwork_url text,
  add column if not exists hero_title_artwork_source text,
  add column if not exists detail_title_artwork_source text,
  add column if not exists hero_title_artwork_authorized boolean not null default false,
  add column if not exists detail_title_artwork_authorized boolean not null default false;

do $block$
begin
  if to_regclass('public.external_media_catalog') is not null then
    execute 'comment on column public.external_media_catalog.hero_title_artwork_mode is ''Per-screen Home hero mode: inherit, auto, text, logo, trailer_title_card, movie_title_card, or case_cover.''';
    execute 'comment on column public.external_media_catalog.detail_title_artwork_mode is ''Per-screen media Details mode: inherit, auto, text, logo, trailer_title_card, movie_title_card, or case_cover.''';
    execute 'comment on column public.external_media_catalog.hero_title_artwork_url is ''User-selected image URL for the Home hero title treatment; use an authorized HTTPS asset.''';
    execute 'comment on column public.external_media_catalog.detail_title_artwork_url is ''User-selected image URL for the Details title treatment; use an authorized HTTPS asset.''';
    execute 'comment on column public.external_media_catalog.hero_title_artwork_authorized is ''Explicit authorization confirmation for Home hero artwork.''';
    execute 'comment on column public.external_media_catalog.detail_title_artwork_authorized is ''Explicit authorization confirmation for Details artwork.''';
  end if;
end;
$block$;
