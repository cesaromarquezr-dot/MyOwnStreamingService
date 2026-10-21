-- Public usernames belong to profiles, not subscription accounts.
-- All backend instances that must share global username uniqueness need to use
-- this shared Supabase database. Isolated databases cannot coordinate handles.

begin;

alter table public.profiles
  add column if not exists username text;

-- Give existing profiles stable handles before enforcing uniqueness. Existing
-- profiles can later expose a user-facing rename workflow; newly created profiles
-- provide a handle directly in the profile creation form.
do $$
declare
  item record;
  base_handle text;
  candidate text;
  suffix integer;
begin
  for item in
    select id, name
    from public.profiles
    where username is null or btrim(username) = ''
    order by created_at nulls first, id
  loop
    base_handle := lower(regexp_replace(coalesce(item.name, ''), '[^a-zA-Z0-9_]+', '_', 'g'));
    base_handle := regexp_replace(base_handle, '_+', '_', 'g');
    base_handle := trim(both '_' from base_handle);
    base_handle := left(base_handle, 32);
    if length(base_handle) < 3 then
      base_handle := 'profile';
    end if;

    candidate := base_handle;
    suffix := 1;
    while exists (
      select 1 from public.profiles p
      where p.id <> item.id and lower(btrim(p.username)) = candidate
    ) loop
      suffix := suffix + 1;
      candidate := left(base_handle, 32 - length('_' || suffix::text)) || '_' || suffix::text;
    end loop;

    update public.profiles set username = candidate where id = item.id;
  end loop;
end $$;

create unique index if not exists profiles_username_ci_unique
  on public.profiles (lower(btrim(username)))
  where username is not null and btrim(username) <> '';

comment on column public.profiles.username is
  'Case-insensitive globally unique public handle for a profile. Account login remains email-based.';

commit;
