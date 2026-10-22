-- Movie edition years and television series run years.
-- Apply after streaming_service.sql, discovery_catalog.sql, and canonical_extensions.sql.
-- The original media_catalog.year remains the work's original release/first-air year.
-- A later movie cut/re-release uses media_editions.release_year and metadata.
--
-- These additions are nullable/additive so existing catalogs remain valid.

begin;

alter table if exists public.media_catalog
  add column if not exists series_start_year integer,
  add column if not exists series_end_year integer,
  add column if not exists series_status text;

alter table if exists public.external_media_catalog
  add column if not exists series_start_year integer,
  add column if not exists series_end_year integer,
  add column if not exists series_status text;

alter table if exists public.media_editions
  add column if not exists edition_features text[] not null default '{}';

alter table if exists public.external_media_editions
  add column if not exists edition_features text[] not null default '{}';

comment on column public.media_catalog.year is
  'Original work release year for a movie or first-air year for a series; not a later edition release year.';
comment on column public.media_catalog.series_start_year is
  'Original year the series first aired, used for banner run labels.';
comment on column public.media_catalog.series_end_year is
  'Year the series ended, derived from the final aired episode where verified.';
comment on column public.media_catalog.series_status is
  'Normalized series lifecycle status: upcoming, ongoing, ended, hiatus, or unknown.';
comment on column public.external_media_catalog.series_start_year is
  'Original year the external series first aired, used for banner run labels.';
comment on column public.external_media_catalog.series_end_year is
  'Final original-air year for a completed external series, when known.';
comment on column public.external_media_catalog.series_status is
  'Normalized external series lifecycle: upcoming, ongoing, ended, hiatus, or unknown.';
comment on column public.media_editions.edition_features is
  'Edition-specific differences such as additional scenes or an alternate ending.';
comment on column public.external_media_editions.edition_features is
  'Verified edition differences such as extra scenes or an alternate ending.';

commit;
