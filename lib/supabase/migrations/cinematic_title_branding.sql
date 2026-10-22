-- Cinematic title branding metadata. Additive; existing rows remain valid.
-- Only display logo assets when the catalog marks their usage as authorized.
alter table if exists public.external_media_catalog
  add column if not exists title_logo_url text,
  add column if not exists title_logo_source text,
  add column if not exists title_logo_authorized boolean not null default false,
  add column if not exists title_style_key text,
  add column if not exists title_accent_color text,
  add column if not exists title_reveal_animation boolean not null default true;

do $block$
declare
  item record;
begin
  if to_regclass('public.external_media_catalog') is not null then
    for item in select * from (values
      ('title_logo_url', 'Optional URL for a dedicated title-logo asset; not a frame extracted from the trailer.'),
      ('title_logo_source', 'Provenance/provider/rights note for title-logo metadata.'),
      ('title_logo_authorized', 'Explicit catalog flag permitting this client to show the title-logo asset.'),
      ('title_style_key', 'Fallback text style key for the cinematic title component.'),
      ('title_accent_color', 'Optional hexadecimal fallback accent color.'),
      ('title_reveal_animation', 'Whether this title may use reveal animation; user reduced-motion settings take precedence.')
    ) as metadata(column_name, description) loop
      execute format(
        'comment on column public.external_media_catalog.%I is %L',
        item.column_name,
        item.description
      );
    end loop;
  end if;
end;
$block$;
