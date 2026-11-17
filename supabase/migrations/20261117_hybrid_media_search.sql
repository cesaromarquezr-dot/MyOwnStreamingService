-- Hybrid catalog search: weighted full-text + typo-tolerant trigram + optional
-- multilingual vector retrieval, fused with reciprocal-rank fusion.
-- Embeddings use OpenAI text-embedding-3-small at 384 dimensions. Keep the
-- embedding_model marker consistent; never compare vectors from mixed models.
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists vector with schema extensions;

-- Resolve extension objects whether a project already has them in public or
-- installed them in Supabase's dedicated extensions schema.
set search_path = public, extensions;

alter table public.external_media_catalog
  add column if not exists themes text[] not null default '{}',
  add column if not exists moods text[] not null default '{}',
  add column if not exists tags text[] not null default '{}',
  add column if not exists accessibility_features text[] not null default '{}',
  add column if not exists subtitle_languages text[] not null default '{}',
  add column if not exists audio_languages text[] not null default '{}',
  add column if not exists ad_supported boolean,
  add column if not exists embedding vector(384),
  add column if not exists embedding_model text,
  add column if not exists embedding_updated_at timestamptz;

alter table public.external_media_catalog
  add column if not exists search_document tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(original_title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('simple', array_to_string(genres, ' ')), 'B') ||
    setweight(to_tsvector('simple', array_to_string(themes, ' ')), 'C') ||
    setweight(to_tsvector('simple', array_to_string(moods, ' ')), 'C') ||
    setweight(to_tsvector('simple', array_to_string(tags, ' ')), 'C') ||
    setweight(to_tsvector('simple', array_to_string(subtitle_languages, ' ')), 'D') ||
    setweight(to_tsvector('simple', array_to_string(audio_languages, ' ')), 'D')
  ) stored;

create index if not exists external_media_catalog_search_document_gin
  on public.external_media_catalog using gin (search_document);
create index if not exists external_media_catalog_title_trgm_gin
  on public.external_media_catalog using gin (lower(title) gin_trgm_ops);
create index if not exists external_media_catalog_original_title_trgm_gin
  on public.external_media_catalog using gin (lower(coalesce(original_title, '')) gin_trgm_ops);
create index if not exists external_media_catalog_embedding_hnsw
  on public.external_media_catalog using hnsw (embedding vector_cosine_ops)
  where embedding is not null;
create index if not exists external_media_catalog_search_facets_gin
  on public.external_media_catalog using gin (genres, themes, moods, accessibility_features, subtitle_languages, audio_languages);

-- Metadata writes enqueue a refresh. The server-only Edge Function drains this
-- queue; the Flutter client receives no permission to read or mutate it.
create table if not exists public.media_search_embedding_queue (
  catalog_id text primary key references public.external_media_catalog(id) on delete cascade,
  queued_at timestamptz not null default now(),
  attempts integer not null default 0,
  last_error text
);
create index if not exists media_search_embedding_queue_time_idx
  on public.media_search_embedding_queue (queued_at);
alter table public.media_search_embedding_queue enable row level security;

create or replace function public.enqueue_media_search_embedding()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.media_search_embedding_queue (catalog_id, queued_at, attempts, last_error)
  values (new.id, now(), 0, null)
  on conflict (catalog_id) do update
    set queued_at = excluded.queued_at, attempts = 0, last_error = null;
  return new;
end;
$$;

drop trigger if exists external_media_catalog_enqueue_embedding on public.external_media_catalog;
create trigger external_media_catalog_enqueue_embedding
  after insert or update of title, original_title, description, genres, themes, moods, tags,
    subtitle_languages, audio_languages
  on public.external_media_catalog
  for each row execute function public.enqueue_media_search_embedding();
revoke all on function public.enqueue_media_search_embedding()
  from public, anon, authenticated;

create or replace function public.hybrid_search_media(
  query_text text,
  query_embedding vector(384) default null,
  result_limit integer default 50,
  filter_subtitles boolean default false,
  filter_audio_description boolean default false,
  filter_ad_free boolean default false
)
returns table (
  id text,
  media_type text,
  title text,
  original_title text,
  description text,
  release_year integer,
  artwork_url text,
  external_ids jsonb,
  genres text[],
  people jsonb,
  themes text[],
  moods text[],
  tags text[],
  accessibility_features text[],
  subtitle_languages text[],
  audio_languages text[],
  ad_supported boolean,
  metadata_source text,
  hybrid_score double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with params as (
    select trim(coalesce(query_text, '')) as q,
           plainto_tsquery('simple', trim(coalesce(query_text, ''))) as tsq
  ),
  eligible as (
    select c.*
    from public.external_media_catalog c
    where trim(coalesce(query_text, '')) <> ''
      and (not filter_subtitles or cardinality(c.subtitle_languages) > 0)
      and (not filter_audio_description or 'audio_description' = any(c.accessibility_features))
      -- Unknown ad support is not advertised as ad-free.
      and (not filter_ad_free or c.ad_supported = false)
  ),
  lexical as (
    select e.id,
           row_number() over (order by ts_rank_cd(e.search_document, p.tsq) desc, e.title asc) as pos
    from eligible e cross join params p
    where numnode(p.tsq) > 0 and e.search_document @@ p.tsq
    order by ts_rank_cd(e.search_document, p.tsq) desc
    limit 200
  ),
  fuzzy as (
    select e.id,
           row_number() over (
             order by greatest(
               similarity(lower(e.title), lower(p.q)),
               similarity(lower(coalesce(e.original_title, '')), lower(p.q))
             ) desc, e.title asc
           ) as pos
    from eligible e cross join params p
    where lower(e.title) % lower(p.q)
       or lower(coalesce(e.original_title, '')) % lower(p.q)
    order by greatest(
      similarity(lower(e.title), lower(p.q)),
      similarity(lower(coalesce(e.original_title, '')), lower(p.q))
    ) desc
    limit 200
  ),
  semantic as (
    select e.id,
           row_number() over (order by e.embedding <=> query_embedding asc) as pos
    from eligible e
    where query_embedding is not null
      and e.embedding is not null
      and e.embedding_model = 'text-embedding-3-small:384'
    order by e.embedding <=> query_embedding asc
    limit 200
  ),
  all_hits as (
    select id from lexical
    union select id from fuzzy
    union select id from semantic
  ),
  fused as (
    select h.id,
      coalesce(1.0 / (60 + l.pos), 0.0) * 0.45 +
      coalesce(1.0 / (60 + f.pos), 0.0) * 0.20 +
      coalesce(1.0 / (60 + s.pos), 0.0) * 0.35 as score
    from all_hits h
    left join lexical l on l.id = h.id
    left join fuzzy f on f.id = h.id
    left join semantic s on s.id = h.id
  )
  select e.id, e.media_type, e.title, e.original_title, e.description,
         e.release_year, e.artwork_url, e.external_ids, e.genres, e.people,
         e.themes, e.moods, e.tags, e.accessibility_features,
         e.subtitle_languages, e.audio_languages, e.ad_supported,
         e.metadata_source, fused.score
  from fused
  join eligible e on e.id = fused.id
  order by fused.score desc, e.updated_at desc
  limit greatest(1, least(coalesce(result_limit, 50), 100));
$$;

comment on function public.hybrid_search_media(text, vector, integer, boolean, boolean, boolean) is
  'Authenticated global search using weighted PostgreSQL full-text, pg_trgm typo tolerance, optional multilingual HNSW vector similarity, and reciprocal-rank fusion.';

revoke all on function public.hybrid_search_media(text, vector, integer, boolean, boolean, boolean)
  from public, anon;
grant execute on function public.hybrid_search_media(text, vector, integer, boolean, boolean, boolean)
  to authenticated;
