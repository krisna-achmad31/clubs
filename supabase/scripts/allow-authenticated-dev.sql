begin;

-- Dev and Live use the same Supabase Auth users. Existing policies and RPCs
-- still check ownership, club membership, and role on each resource.
create or replace function klubby_dev.has_dev_access() returns boolean
language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null;
$$;

revoke all on function klubby_dev.has_dev_access() from public, anon, authenticated;
grant execute on function klubby_dev.has_dev_access() to authenticated;

commit;
