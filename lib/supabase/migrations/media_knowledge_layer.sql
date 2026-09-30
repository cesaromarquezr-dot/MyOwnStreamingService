-- Sourced, spoiler-aware knowledge attached to canonical media identity.
-- This is editorial/catalog data, not user reviews, ratings, or graph edges.

create table if not exists public.media_knowledge_facts (
  id uuid primary key default gen_random_uuid(),
  media_work_id text not null
    references public.media_works(id) on delete cascade,
  media_version_id uuid
    references public.media_versions(id) on delete set null,
  category text not null,
  title text not null,
  body text not null,
  claim_status text not null default 'established'
    check (claim_status in ('established', 'reported', 'disputed', 'interpretation')),
  spoiler_scope text not null default 'none'
    check (spoiler_scope in ('none', 'current_scene', 'current_work', 'franchise', 'everything')),
  difficulty text not null default 'casual'
    check (difficulty in ('casual', 'fan', 'superfan', 'collector', 'deep_cut')),
  related_entities jsonb not null default '[]'::jsonb
    check (jsonb_typeof(related_entities) = 'array'),
  editorial_status text not null default 'draft'
    check (editorial_status in ('draft', 'published', 'withdrawn')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.media_knowledge_fact_sources (
  id uuid primary key default gen_random_uuid(),
  fact_id uuid not null
    references public.media_knowledge_facts(id) on delete cascade,
  title text not null,
  url text not null,
  source_type text not null,
  publisher text,
  published_at date,
  accessed_at date,
  supporting_note text,
  created_at timestamptz not null default now()
);

alter table public.media_knowledge_fact_sources
  add column if not exists evidence_relation text not null default 'direct_support'
  check (evidence_relation in ('direct_support', 'corroboration', 'context', 'contradiction'));
alter table public.media_knowledge_fact_sources
  add column if not exists locator text;

create table if not exists public.media_knowledge_stories (
  id uuid primary key default gen_random_uuid(),
  anchor_media_work_id text not null
    references public.media_works(id) on delete cascade,
  title text not null,
  summary text,
  editorial_status text not null default 'draft'
    check (editorial_status in ('draft', 'published', 'withdrawn')),
  spoiler_scope text not null default 'none'
    check (spoiler_scope in ('none', 'current_scene', 'current_work', 'franchise', 'everything')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.media_knowledge_story_steps (
  story_id uuid not null
    references public.media_knowledge_stories(id) on delete cascade,
  step_number integer not null check (step_number > 0),
  fact_id uuid not null
    references public.media_knowledge_facts(id) on delete cascade,
  transition_note text,
  primary key (story_id, step_number),
  unique (story_id, fact_id)
);

create index if not exists media_knowledge_facts_work_idx
  on public.media_knowledge_facts(media_work_id, editorial_status, category);
create index if not exists media_knowledge_facts_version_idx
  on public.media_knowledge_facts(media_version_id)
  where media_version_id is not null;
create index if not exists media_knowledge_fact_sources_fact_idx
  on public.media_knowledge_fact_sources(fact_id);
create index if not exists media_knowledge_stories_anchor_idx
  on public.media_knowledge_stories(anchor_media_work_id, editorial_status);
create index if not exists media_knowledge_story_steps_fact_idx
  on public.media_knowledge_story_steps(fact_id);

create or replace function public.require_source_for_published_knowledge_fact()
returns trigger
language plpgsql
as $$
begin
  if new.editorial_status = 'published'
    and not exists (
      select 1 from public.media_knowledge_fact_sources source
      where source.fact_id = new.id
    ) then
    raise exception 'A published knowledge fact must have at least one source.';
  end if;
  return new;
end;
$$;

drop trigger if exists media_knowledge_fact_source_required
  on public.media_knowledge_facts;
create trigger media_knowledge_fact_source_required
  before insert or update of editorial_status
  on public.media_knowledge_facts
  for each row execute function public.require_source_for_published_knowledge_fact();

alter table public.media_knowledge_facts enable row level security;
alter table public.media_knowledge_fact_sources enable row level security;
alter table public.media_knowledge_stories enable row level security;
alter table public.media_knowledge_story_steps enable row level security;

create policy "Authenticated users can read published knowledge facts"
  on public.media_knowledge_facts for select to authenticated
  using (editorial_status = 'published');

create policy "Authenticated users can read sources for published facts"
  on public.media_knowledge_fact_sources for select to authenticated
  using (exists (
    select 1 from public.media_knowledge_facts fact
    where fact.id = fact_id and fact.editorial_status = 'published'
  ));

create policy "Authenticated users can read published knowledge stories"
  on public.media_knowledge_stories for select to authenticated
  using (editorial_status = 'published');

create policy "Authenticated users can read steps in published knowledge stories"
  on public.media_knowledge_story_steps for select to authenticated
  using (exists (
    select 1 from public.media_knowledge_stories story
    join public.media_knowledge_facts fact on fact.id = fact_id
    where story.id = story_id
      and story.editorial_status = 'published'
      and fact.editorial_status = 'published'
  ));

comment on column public.media_knowledge_facts.related_entities is
  'Typed references into shared entity/relationship identity; does not copy related entities.';
comment on column public.media_knowledge_facts.media_version_id is
  'Optional exact version/edition scope for collector, cut, or release-specific facts.';
comment on column public.media_knowledge_facts.claim_status is
  'Editorial framing for evidence quality; reported/disputed claims must not display as established.';
comment on column public.media_knowledge_fact_sources.evidence_relation is
  'Identifies whether the citation supports, corroborates, contextualizes, or contradicts this claim.';
comment on column public.media_knowledge_fact_sources.locator is
  'Optional page, chapter, timestamp, or section identifying the evidence within the source.';
comment on table public.media_knowledge_story_steps is
  'Ordered, cited fact links for editorial rabbit-hole narratives; facts remain independently addressable.';
