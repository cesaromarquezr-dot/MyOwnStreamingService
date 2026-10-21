-- Platform operations foundations. Apply through the normal migration pipeline.
-- RLS is enabled by default; no client access is granted by this migration.

create table if not exists public.platform_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_kind text not null default 'user' check (actor_kind in ('user','support_agent','admin','service')),
  action text not null,
  resource_type text not null,
  resource_id text,
  request_id text,
  ip_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists platform_audit_events_created_idx on public.platform_audit_events(created_at desc);
create index if not exists platform_audit_events_actor_idx on public.platform_audit_events(actor_user_id, created_at desc);
alter table public.platform_audit_events enable row level security;


create table if not exists public.platform_admin_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_key text not null check (role_key in ('platform_admin','support_agent','support_lead','catalog_manager','billing_operator','privacy_operator','incident_manager','auditor')),
  granted_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id, role_key)
);
create index if not exists platform_admin_roles_user_idx on public.platform_admin_role_assignments(user_id);
alter table public.platform_admin_role_assignments enable row level security;

-- Store provider event identifiers and processing outcomes, never raw card data.
create table if not exists public.platform_billing_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  processing_status text not null default 'received' check (processing_status in ('received','processing','processed','failed','ignored')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique(provider, provider_event_id)
);
create index if not exists platform_billing_events_status_idx on public.platform_billing_webhook_events(processing_status, received_at);
alter table public.platform_billing_webhook_events enable row level security;

create table if not exists public.platform_incidents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  severity text not null check (severity in ('sev1','sev2','sev3','sev4')),
  status text not null default 'investigating' check (status in ('investigating','identified','monitoring','resolved')),
  affected_services text[] not null default '{}',
  public_message text,
  started_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists platform_incidents_status_idx on public.platform_incidents(status, started_at desc);
alter table public.platform_incidents enable row level security;

create table if not exists public.platform_support_sla_policies (
  id uuid primary key default gen_random_uuid(),
  priority text not null unique check (priority in ('urgent','high','normal','low')),
  first_response_minutes integer not null check (first_response_minutes > 0),
  resolution_target_minutes integer not null check (resolution_target_minutes > 0),
  business_hours_only boolean not null default false,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.platform_support_sla_policies(priority, first_response_minutes, resolution_target_minutes)
values ('urgent',15,240),('high',60,1440),('normal',480,4320),('low',1440,10080)
on conflict (priority) do nothing;
alter table public.platform_support_sla_policies enable row level security;

create table if not exists public.platform_privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check (request_type in ('export','delete','correct','consent_review')),
  status text not null default 'received' check (status in ('received','verifying','in_progress','completed','rejected')),
  verification_completed_at timestamptz,
  due_at timestamptz,
  completed_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists platform_privacy_requests_user_idx on public.platform_privacy_requests(user_id, created_at desc);
alter table public.platform_privacy_requests enable row level security;

create table if not exists public.platform_rights_windows (
  id uuid primary key default gen_random_uuid(),
  media_id text not null,
  territory_code text not null,
  starts_at timestamptz,
  ends_at timestamptz,
  license_source text,
  playback_allowed boolean not null default false,
  download_allowed boolean not null default false,
  age_rating text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at > starts_at),
  unique(media_id, territory_code, starts_at, ends_at)
);
create index if not exists platform_rights_lookup_idx on public.platform_rights_windows(media_id, territory_code, starts_at, ends_at);
alter table public.platform_rights_windows enable row level security;

create table if not exists public.platform_release_checks (
  id uuid primary key default gen_random_uuid(),
  release_version text not null,
  environment text not null check (environment in ('development','staging','production')),
  check_name text not null,
  status text not null check (status in ('pending','passed','failed','waived')),
  report_uri text,
  executed_at timestamptz,
  executed_by text,
  created_at timestamptz not null default now(),
  unique(release_version, environment, check_name)
);
create index if not exists platform_release_checks_status_idx on public.platform_release_checks(release_version, environment, status);
alter table public.platform_release_checks enable row level security;

-- Do not add permissive client policies here. Access is granted only after
-- the application has a reviewed role model and server-side authorization.
