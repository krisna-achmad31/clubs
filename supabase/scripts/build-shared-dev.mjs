import { readFileSync, writeFileSync } from 'node:fs';

const [, , destination, mode] = process.argv;
if (!destination) throw new Error('Pass an output path for the SQL bundle');
if (mode && mode !== '--upgrade-core') throw new Error('Unknown bundle mode');
const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8').replace(/^\uFEFF/, '');
const versions = [
  '20261116000100_klubby_core.sql',
  '20261116000200_klubby_access_and_rsvp.sql',
  '20261116000300_klubby_jobs_and_discovery.sql',
  '20261116000400_klubby_notification_api.sql',
  '20261116000500_manual_mabar_payment.sql',
  '20261116000600_activity_feed_and_devices.sql',
];

const foundation = `
create schema klubby_dev;
revoke all on schema klubby_dev from public, anon, authenticated;
grant usage on schema klubby_dev to authenticated, service_role;

create function klubby_dev.has_dev_access() returns boolean
language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null;
$$;
revoke all on function klubby_dev.has_dev_access() from public, anon, authenticated;
grant execute on function klubby_dev.has_dev_access() to authenticated;
`;

const parts = versions.map((version, i) => {
  let sql = read(`migrations/${version}`);
  if (i === 0) {
    sql = sql.replace(' references auth.users on delete cascade', '').replace(
      /create function public\.klubby_create_profile\(\)[\s\S]*?from auth\.users;/,
      '',
    );
  }
  return sql.replaceAll('public.', 'klubby_dev.')
    .replaceAll("if auth.uid() is null then raise exception using", "if not klubby_dev.has_dev_access() then raise exception using")
    .replace('and s.host_id=auth.uid() and not s.cancelled', 'and s.host_id=auth.uid() and klubby_dev.has_dev_access() and not s.cancelled')
    .replace('if s.host_id is distinct from auth.uid()', 'if not klubby_dev.has_dev_access() or s.host_id is distinct from auth.uid()')
    .replace('where token=p_token and user_id=auth.uid()', 'where token=p_token and user_id=auth.uid() and klubby_dev.has_dev_access()')
    .replaceAll('klubby-expire-mabar-payments', 'klubby-dev-expire-mabar-payments')
    .replaceAll("if auth.uid() is null then raise exception 'Login required'; end if;",
      "if not klubby_dev.has_dev_access() then raise exception 'Login required'; end if;")
    .replace('select exists(select 1 from klubby_dev.club_members',
      'select klubby_dev.has_dev_access() and exists(select 1 from klubby_dev.club_members')
    .replaceAll("'avatars'", "'dev-avatars'")
    .replaceAll("'club-logos'", "'dev-club-logos'")
    .replaceAll("'activity-photos'", "'dev-activity-photos'")
    .replace("'dev-avatars','dev-avatars',true", "'dev-avatars','dev-avatars',false")
    .replace("'dev-club-logos','dev-club-logos',true", "'dev-club-logos','dev-club-logos',false")
    .replaceAll("bucket_id in ('dev-avatars','dev-activity-photos')",
      "klubby_dev.has_dev_access() and bucket_id in ('dev-avatars','dev-activity-photos')")
    .replace('create policy klubby_user_images', 'create policy klubby_dev_user_images')
    .replace('create policy klubby_club_logos', 'create policy klubby_dev_club_logos')
    .replace('create policy klubby_payment_qr_read', 'create policy klubby_dev_payment_qr_read');
});

const guard = `
do $$
declare t text;
begin
  foreach t in array array['users','user_sports','clubs','club_members','club_messages',
    'mabar_sessions','session_participants','notifications','activities'] loop
    execute format('create policy dev_environment_gate on klubby_dev.%I as restrictive for all to authenticated using ((select klubby_dev.has_dev_access())) with check ((select klubby_dev.has_dev_access()))',t);
  end loop;
end;
$$;

create function klubby_dev.provision_dev_profile() returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Login required'; end if;
  insert into klubby_dev.users(id,username) values(v_user,'user_' || replace(v_user::text,'-',''))
  on conflict (id) do nothing;
  return v_user;
end;
$$;
revoke all on function klubby_dev.provision_dev_profile() from public,anon,authenticated;
grant execute on function klubby_dev.provision_dev_profile() to authenticated;

grant select,insert,update,delete on all tables in schema klubby_dev to service_role;
`;

const fixture = read('fixtures/dev_demo.sql')
  .replace(/^(begin|commit);\s*/gm, '')
  .replace(/insert into auth\.users[\s\S]*?where id='da5e0000-0000-4000-8000-000000000001';/, `
insert into klubby_dev.users(id,name,username)
values ('da5e0000-0000-4000-8000-000000000001','Budi (Host)','fixture_budi')
on conflict (id) do nothing;
`)
  .replaceAll('public.', 'klubby_dev.');

const smoke = `
do $$
begin
  if (select count(*) from klubby_dev.clubs) <> 5
     or (select count(*) from klubby_dev.mabar_sessions) <> 4 then
    raise exception 'Dev fixtures missing';
  end if;
  if exists(select 1 from public.clubs where id='da5e0000-0000-4000-8000-000000000101')
     or exists(select 1 from auth.users where id='da5e0000-0000-4000-8000-000000000001') then
    raise exception 'Fixture must not exist in Prod or shared Auth';
  end if;
end;
$$;

savepoint dev_access_smoke;
set local role authenticated;
select set_config('request.jwt.claim.sub','da5e0000-0000-4000-8000-000000000999',true);
do $$
begin
  perform klubby_dev.provision_dev_profile();
  if not exists(select 1 from klubby_dev.clubs) then raise exception 'Authenticated user cannot read Dev clubs'; end if;
  if (select count(*) from klubby_dev.users) <> 1 then raise exception 'Dev profile RLS failed'; end if;
end;
$$;
reset role;
rollback to savepoint dev_access_smoke;
`;

const upgrade = [
  ...parts.slice(4),
  `create policy dev_environment_gate on klubby_dev.activities as restrictive for all to authenticated
    using ((select klubby_dev.has_dev_access())) with check ((select klubby_dev.has_dev_access()));`,
  "notify pgrst, 'reload schema';",
];
const contents = ['begin;', ...(mode ? upgrade : [foundation, ...parts, guard, fixture, smoke]), 'commit;'].join('\n');
if (/on auth\.users|insert into auth\.users|create table public\.|\uFFFD/i.test(contents)) {
  throw new Error('Unexpected shared Auth mutation, production DDL or invalid text in Dev bundle');
}
writeFileSync(destination, contents, 'utf8');
