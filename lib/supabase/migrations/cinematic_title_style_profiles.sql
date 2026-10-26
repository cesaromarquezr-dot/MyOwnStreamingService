-- Optional, per-media title typography overrides.
-- Existing title_style_key / title_accent_color continue to work when these
-- nullable properties are unset. Font assets must be correctly licensed.
alter table if exists public.external_media_catalog
  add column if not exists title_font_family text,
  add column if not exists title_font_fallback_family text,
  add column if not exists title_font_size numeric,
  add column if not exists title_font_weight integer,
  add column if not exists title_font_letter_spacing numeric,
  add column if not exists title_font_color text,
  add column if not exists title_font_shadow_color text,
  add column if not exists title_font_shadow_blur numeric,
  add column if not exists title_style_source text,
  add column if not exists title_style_license text;

comment on column public.external_media_catalog.title_font_family is
  'Optional explicitly registered and licensed Flutter font family for the title.';
comment on column public.external_media_catalog.title_font_size is
  'Optional base title font size in logical pixels; renderer scales longer titles to fit.';
comment on column public.external_media_catalog.title_font_weight is
  'Optional Flutter-style numeric weight from 100 through 900.';
comment on column public.external_media_catalog.title_font_letter_spacing is
  'Optional title letter spacing in logical pixels.';
comment on column public.external_media_catalog.title_font_color is
  'Optional #RRGGBB or #AARRGGBB title text color; falls back to title_accent_color/style registry.';
comment on column public.external_media_catalog.title_font_shadow_color is
  'Optional #RRGGBB or #AARRGGBB title shadow color.';
comment on column public.external_media_catalog.title_font_shadow_blur is
  'Optional title text shadow blur radius in logical pixels.';
comment on column public.external_media_catalog.title_style_source is
  'Provenance for a manually curated or researched title typography profile.';
comment on column public.external_media_catalog.title_style_license is
  'Font/software license note for the selected title style.';
