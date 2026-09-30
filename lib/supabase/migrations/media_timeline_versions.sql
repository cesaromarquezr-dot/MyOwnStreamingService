-- Keep scenes and story-time annotations bound to the exact playable version.
-- Canonical media relationships remain separate from profile collection order.

alter table public.media_timeline_events
  add column if not exists media_version_id uuid
    references public.media_versions(id)
    on delete set null,
  add column if not exists sequence_order integer,
  add column if not exists story_time_label text,
  add column if not exists related_media_catalog_id uuid
    references public.media_catalog(id)
    on delete set null,
  add column if not exists provenance text not null default 'catalog',
  add column if not exists confidence numeric(5,4) not null default 1.0
    check (confidence >= 0 and confidence <= 1),
  add column if not exists spoiler_level text not null default 'none'
    check (spoiler_level in ('none', 'mild', 'major'));

create index if not exists idx_media_timeline_version_order
  on public.media_timeline_events(media_version_id, sequence_order);

create index if not exists idx_media_timeline_related_media
  on public.media_timeline_events(related_media_catalog_id)
  where related_media_catalog_id is not null;

comment on column public.media_timeline_events.media_version_id is
  'Version that owns the timeline event; timestamps are not assumed to transfer between cuts.';

comment on column public.media_timeline_events.story_time_label is
  'Human-readable story chronology such as after a named film; separate from credit-scene sequence order.';
