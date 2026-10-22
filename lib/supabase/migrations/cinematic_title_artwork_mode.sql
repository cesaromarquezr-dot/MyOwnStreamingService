-- Cinematic title artwork metadata. All additions are additive and safe for
-- existing records. Legacy rows default to automatic/logo/text behavior.
alter table if exists public.external_media_catalog
  add column if not exists title_logo_url text,
  add column if not exists title_logo_source text,
  add column if not exists title_logo_authorized boolean not null default false,
  add column if not exists title_artwork_mode text not null default 'auto',
  add column if not exists title_style_key text,
  add column if not exists title_accent_color text,
  add column if not exists title_reveal_animation boolean not null default true;

do $block$
begin
  if to_regclass('public.external_media_catalog') is not null then
    execute 'comment on column public.external_media_catalog.title_artwork_mode is ''Presentation mode: auto, logo, trailer_title_card, movie_title_card, or case_cover. Artwork itself must be authorized.''';
    execute 'comment on column public.external_media_catalog.title_logo_source is ''Provenance/provider/rights note for the selected logo or title-card still.''';
    execute 'comment on column public.external_media_catalog.title_logo_authorized is ''Explicit flag permitting the client to show selected title artwork.''';
  end if;
end;
$block$;
