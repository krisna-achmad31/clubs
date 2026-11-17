create table public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  sport_id text not null check(length(btrim(sport_id)) between 1 and 50),
  title text not null check(length(btrim(title)) between 1 and 120),
  occurred_at timestamptz not null check(occurred_at<=now()+interval '5 minutes'),
  duration_seconds integer not null check(duration_seconds between 1 and 86400),
  visibility text not null default 'private' check(visibility in ('private','public','club')),
  club_id uuid references public.clubs(id) on delete set null,
  source text not null default 'manual' check(source in ('manual','gps','wearable','checkin')),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
create index activities_timeline on public.activities(occurred_at desc,id desc);
alter table public.activities enable row level security;
revoke all on public.activities from public,anon,authenticated;
grant select,delete on public.activities to authenticated;
grant insert(id,sport_id,title,occurred_at,duration_seconds,visibility,club_id) on public.activities to authenticated;
grant update(title,visibility,club_id) on public.activities to authenticated;
grant select,insert,update,delete on public.activities to service_role;
create policy activity_read on public.activities for select to authenticated using (
  user_id=(select auth.uid()) or visibility='public'
  or (visibility='club' and public.is_club_member(club_id))
);
create policy activity_insert on public.activities for insert to authenticated with check (
  user_id=(select auth.uid()) and (club_id is null or public.is_club_member(club_id))
  and (visibility<>'club' or club_id is not null)
);
create policy activity_update on public.activities for update to authenticated using(user_id=(select auth.uid()))
  with check(user_id=(select auth.uid()) and (club_id is null or public.is_club_member(club_id))
    and (visibility<>'club' or club_id is not null));
create policy activity_delete on public.activities for delete to authenticated using(user_id=(select auth.uid()));

create table public.push_devices (
  token text primary key check(length(token) between 20 and 4096),
  user_id uuid not null references public.users(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index push_devices_user on public.push_devices(user_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from public,anon,authenticated;
grant select,delete on public.push_devices to service_role;

create function public.register_fcm_token(p_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception using errcode='42501',message='Login required'; end if;
  insert into public.push_devices(token,user_id) values(p_token,auth.uid())
  on conflict(token) do update set user_id=excluded.user_id,updated_at=now();
end;
$$;
create function public.unregister_fcm_token(p_token text) returns void
language sql security definer set search_path='' as $$
  delete from public.push_devices where token=p_token and user_id=auth.uid();
$$;
revoke all on function public.register_fcm_token(text),public.unregister_fcm_token(text) from public,anon,authenticated;
grant execute on function public.register_fcm_token(text),public.unregister_fcm_token(text) to authenticated;
