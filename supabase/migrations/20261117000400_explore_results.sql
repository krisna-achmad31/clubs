-- The tournament writer already uses this table in both app modes.
create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  title text not null default '',
  format text not null,
  state jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.tournaments enable row level security;
revoke all on public.tournaments from public, anon, authenticated;
grant select, insert, update, delete on public.tournaments to authenticated;
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_policies where schemaname = split_part('public.tournaments', '.', 1)
      and tablename = 'tournaments' and policyname = 'tournaments_owner'
  ) then
    create policy tournaments_owner on public.tournaments for all to authenticated
      using (host_id = (select auth.uid())) with check (host_id = (select auth.uid()));
  end if;
end;
$$;

create function public.explore_results(
  p_kind text, p_query text, p_sport text, p_area text,
  p_lat double precision, p_lon double precision, p_offset integer,
  p_matching_sports text[]
)
returns table (
  id uuid, title text, subtitle text, sport_id text, area text,
  distance_km double precision, total integer, slots integer,
  fee integer, status text, session_id uuid, starts_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  with caller as (
    select auth.uid() as uid, lower(left(btrim(coalesce(p_query, '')), 100)) as term,
      case when p_lat between -90 and 90 and p_lon between -180 and 180
        then extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography end as origin
    where auth.uid() is not null
  ), upcoming as (
    select s.*, c.name::text as club_name, c.area as club_area
    from public.mabar_sessions s join public.clubs c on c.id = s.club_id
    cross join caller x
    where p_kind in ('mabar', 'venue') and not s.cancelled and s.starts_at > now()
      and (s.deadline_at is null or s.deadline_at > now())
      and (c.privacy = 'publik' or s.host_id = x.uid or public.is_club_member(c.id))
  ), venues as (
    select distinct on (lower(btrim(s.venue)), coalesce(s.club_area, ''), s.sport_id) s.*
    from upcoming s where p_kind = 'venue' and btrim(s.venue) <> ''
    order by lower(btrim(s.venue)), coalesce(s.club_area, ''), s.sport_id, s.starts_at, s.id
  ), my_tournaments as (
    select distinct on (coalesce(t.state->>'startedAt', t.id::text)) t.*
    from public.tournaments t cross join caller x
    where p_kind = 'tournament' and t.host_id = x.uid
    order by coalesce(t.state->>'startedAt', t.id::text), t.updated_at desc, t.id
  ), entries as (
    select c.id, c.name::text as title, coalesce(c.schedule, '') as subtitle,
      c.sport_id, c.area, extensions.st_distance(c.location, x.origin) / 1000 as distance_km,
      (select count(*)::int from public.club_members m where m.club_id = c.id and m.status = 'active') as total,
      (select count(*)::int from public.mabar_sessions s where s.club_id = c.id and not s.cancelled
        and s.starts_at between now() and now() + interval '7 days'
        and (c.privacy = 'publik' or s.host_id = x.uid or public.is_club_member(c.id))) as slots,
      null::int as fee, coalesce(mine.status, c.privacy) as status,
      null::uuid as session_id, null::timestamptz as starts_at
    from public.clubs c cross join caller x
    left join public.club_members mine on mine.club_id = c.id and mine.user_id = x.uid
    where p_kind = 'club'
    union all
    select s.id, s.title::text, concat_ws(' · ', s.venue, s.club_name),
      s.sport_id, s.club_area, null::double precision,
      (select count(*)::int from public.session_participants p where p.session_id = s.id
        and p.cancelled_at is null and not p.is_waitlist and not p.refunded),
      s.slots::int, s.fee, null, s.id, s.starts_at
    from upcoming s where p_kind = 'mabar'
    union all
    select s.id, btrim(s.venue)::text, 'Lihat Mabar di venue ini', s.sport_id, s.club_area,
      null::double precision, null::int, null::int, null::int, null::text, s.id, s.starts_at
    from venues s
  ), other_entries as (
    select t.id, coalesce(nullif(t.title, ''), 'Turnamen saya'), t.format, null::text, null::text,
      null::double precision, null::int, null::int, null::int,
      case when t.state->>'finished' = 'true' then 'finished' else 'running' end,
      null::uuid, t.updated_at
    from my_tournaments t
    union all
    select u.id, u.name::text, u.username::text, u.active_sport_id, null::text,
      null::double precision, null::int, null::int, null::int,
      case when f.followed_id is null then 'available' else 'following' end,
      null::uuid, null::timestamptz
    from public.users u cross join caller x
    left join public.user_follows f on f.follower_id = x.uid and f.followed_id = u.id
    where p_kind = 'people' and u.id <> x.uid and u.name <> '' and length(ltrim(x.term, '@')) >= 2
      and (p_sport is null or exists (
        select 1 from public.user_sports us where us.user_id = u.id and us.sport_id = p_sport
      ) or u.active_sport_id = p_sport)
  ), all_entries as (
    select * from entries union all select * from other_entries
  )
  select e.* from all_entries e cross join caller x
  where (p_sport is null or e.sport_id = p_sport or p_kind in ('people', 'tournament'))
    and (x.term = '' or strpos(lower(concat_ws(' ', e.title, e.subtitle, e.area, e.sport_id)),
        case when p_kind = 'people' then ltrim(x.term, '@') else x.term end) > 0
      or e.sport_id = any(p_matching_sports))
  order by e.distance_km nulls last,
    case when lower(e.area) = lower(p_area) then 0 else 1 end,
    case when p_kind in ('mabar', 'venue') then e.starts_at end,
    case when p_kind = 'tournament' then e.starts_at end desc,
    lower(e.title), e.id
  limit 31 offset greatest(p_offset, 0);
$$;
revoke all on function public.explore_results(text,text,text,text,double precision,double precision,integer,text[])
  from public, anon, authenticated;
grant execute on function public.explore_results(text,text,text,text,double precision,double precision,integer,text[])
  to authenticated;
notify pgrst, 'reload schema';
