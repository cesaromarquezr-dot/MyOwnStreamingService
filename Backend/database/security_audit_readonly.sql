-- READ-ONLY SECURITY AUDIT
-- Run in the Supabase SQL editor with an administrative account.
-- This script reports configuration; it intentionally makes no changes.

-- 1) Public tables/partitions without Row Level Security enabled.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relkind as relation_kind,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and not c.relrowsecurity
order by c.relname;

-- 2) Tables with RLS enabled but no policies. These may be intentionally
-- inaccessible through client roles; review each case rather than blindly
-- adding permissive policies.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and c.relrowsecurity
  and not exists (
    select 1
    from pg_policies p
    where p.schemaname = n.nspname
      and p.tablename = c.relname
  )
order by c.relname;

-- 3) Full policy inventory. Review roles, command, USING and WITH CHECK
-- expressions to verify account/member/profile isolation.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as using_expression,
  with_check as check_expression
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 4) Confirm whether the security-events table exists and has RLS enabled.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'security_events';
