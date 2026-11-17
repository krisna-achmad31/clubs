-- Full API sync migration: extends core tables and adds Gear, Club Kas/Invites,
-- Feed Reactions/Comments/Mutes/Reports, League, Goyang, Shop, and Tournaments.

-- 1. Extend users for full profile & gamification sync
alter table public.users
  add column if not exists phone text not null default '',
  add column if not exists streak integer not null default 0,
  add column if not exists best_streak integer not null default 0,
  add column if not exists xp integer not null default 0,
  add column if not exists freezes integer not null default 0,
  add column if not exists max_freezes integer not null default 2,
  add column if not exists gems integer not null default 0,
  add column if not exists stamps integer not null default 0,
  add column if not exists saldo integer not null default 0,
  add column if not exists following integer not null default 0,
  add column if not exists followers integer not null default 0,
  add column if not exists last_active timestamptz,
  add column if not exists adopted jsonb not null default '{}',
  add column if not exists verified_sport_sessions jsonb not null default '{}',
  add column if not exists owned text[] not null default '{}',
  add column if not exists stamp_history jsonb not null default '[]';

-- 2. Gear
create table if not exists public.user_gear (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  name varchar(120) not null,
  kind text not null check (kind in ('sepatu', 'raket', 'sepeda', 'lainnya')),
  sport_id text not null,
  km double precision not null default 0,
  limit_km integer,
  hours integer not null default 0,
  minutes integer not null default 0,
  restrung_at timestamptz,
  retired boolean not null default false,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists user_gear_owner on public.user_gear(user_id, created_at);
alter table public.user_gear enable row level security;
revoke all on public.user_gear from public, anon, authenticated;
grant select, insert, update, delete on public.user_gear to authenticated;
create policy user_gear_owner_all on public.user_gear
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 3. Extend clubs + Kas + Invites
alter table public.clubs
  add column if not exists code text,
  add column if not exists sessions_per_week integer not null default 1,
  add column if not exists payout_provider text,
  add column if not exists payout_number text,
  add column if not exists payout_holder text;

create table if not exists public.club_kas_entries (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.users(id),
  title varchar(150) not null,
  amount integer not null,
  is_income boolean not null default true,
  counts boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists club_kas_club on public.club_kas_entries(club_id, created_at desc);
alter table public.club_kas_entries enable row level security;
revoke all on public.club_kas_entries from public, anon, authenticated;
grant select, insert on public.club_kas_entries to authenticated;
create policy club_kas_read on public.club_kas_entries
  for select to authenticated
  using (public.is_club_member(club_id));
create policy club_kas_write on public.club_kas_entries
  for insert to authenticated
  with check (public.is_club_member(club_id, true));

create table if not exists public.club_invites (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  invited_user_id uuid not null references public.users(id) on delete cascade,
  invited_by uuid not null default auth.uid() references public.users(id),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  unique (club_id, invited_user_id)
);
alter table public.club_invites enable row level security;
revoke all on public.club_invites from public, anon, authenticated;
grant select, insert, update on public.club_invites to authenticated;
create policy club_invites_read on public.club_invites
  for select to authenticated
  using (invited_user_id = (select auth.uid()) or public.is_club_member(club_id, true));
create policy club_invites_insert on public.club_invites
  for insert to authenticated
  with check (public.is_club_member(club_id, true));
create policy club_invites_update on public.club_invites
  for update to authenticated
  using (invited_user_id = (select auth.uid()));

-- 4. Extend activities + Feed Reactions, Comments, Mutes, Reports
alter table public.activities
  add column if not exists note text not null default '',
  add column if not exists distance_km double precision,
  add column if not exists avg_hr integer,
  add column if not exists route jsonb not null default '[]',
  add column if not exists splits integer[] not null default '{}',
  add column if not exists segment text,
  add column if not exists segment_id text;

grant insert(note, distance_km, avg_hr, route, splits, segment, segment_id) on public.activities to authenticated;
grant update(note) on public.activities to authenticated;

create table if not exists public.activity_reactions (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (activity_id, user_id, emoji)
);
alter table public.activity_reactions enable row level security;
revoke all on public.activity_reactions from public, anon, authenticated;
grant select, insert, delete on public.activity_reactions to authenticated;
create policy reactions_read on public.activity_reactions for select to authenticated using (true);
create policy reactions_insert on public.activity_reactions for insert to authenticated with check (user_id = (select auth.uid()));
create policy reactions_delete on public.activity_reactions for delete to authenticated using (user_id = (select auth.uid()));

create table if not exists public.activity_comments (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  author_name text not null,
  author_emoji text not null default '🐰',
  body text not null check (length(btrim(body)) between 1 and 1000),
  sticker boolean not null default false,
  sticker_bg bigint,
  sticker_fg bigint,
  created_at timestamptz not null default now()
);
create index if not exists activity_comments_idx on public.activity_comments(activity_id, created_at);
alter table public.activity_comments enable row level security;
revoke all on public.activity_comments from public, anon, authenticated;
grant select, insert on public.activity_comments to authenticated;
create policy comments_read on public.activity_comments for select to authenticated using (true);
create policy comments_insert on public.activity_comments for insert to authenticated with check (user_id = (select auth.uid()));

create table if not exists public.user_mutes (
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  muted_author text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, muted_author)
);
alter table public.user_mutes enable row level security;
revoke all on public.user_mutes from public, anon, authenticated;
grant select, insert, delete on public.user_mutes to authenticated;
create policy mutes_owner on public.user_mutes for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists public.post_reports (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  reporter_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table public.post_reports enable row level security;
revoke all on public.post_reports from public, anon, authenticated;
grant insert on public.post_reports to authenticated;
create policy reports_insert on public.post_reports for insert to authenticated with check (reporter_id = (select auth.uid()));

-- 5. Goyang Ajak Main
create table if not exists public.goyang_lobbies (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  sport_id text not null default 'badminton',
  venue text not null default '',
  audience text not null default 'semuaKlub',
  active boolean not null default true,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  created_at timestamptz not null default now()
);
alter table public.goyang_lobbies enable row level security;
revoke all on public.goyang_lobbies from public, anon, authenticated;
grant select, insert, update on public.goyang_lobbies to authenticated;
create policy goyang_lobbies_read on public.goyang_lobbies for select to authenticated using (true);
create policy goyang_lobbies_write on public.goyang_lobbies for insert to authenticated with check (host_id = (select auth.uid()));
create policy goyang_lobbies_update on public.goyang_lobbies for update to authenticated using (host_id = (select auth.uid()));

create table if not exists public.goyang_responses (
  lobby_id uuid not null references public.goyang_lobbies(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  name text not null,
  initials text not null,
  status text not null check (status in ('ikut', 'nanti', 'dilihat')),
  note text not null default '',
  share_paid boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (lobby_id, user_id)
);
alter table public.goyang_responses enable row level security;
revoke all on public.goyang_responses from public, anon, authenticated;
grant select, insert, update on public.goyang_responses to authenticated;
create policy goyang_responses_read on public.goyang_responses for select to authenticated using (true);
create policy goyang_responses_upsert on public.goyang_responses for insert to authenticated with check (user_id = (select auth.uid()));
create policy goyang_responses_update on public.goyang_responses for update to authenticated using (user_id = (select auth.uid()));

-- 6. Shop
create table if not exists public.shop_products (
  id text primary key,
  name text not null,
  price integer not null check (price >= 0),
  category text not null,
  description text not null,
  icon text not null,
  available boolean not null default true
);
alter table public.shop_products enable row level security;
revoke all on public.shop_products from public, anon, authenticated;
grant select on public.shop_products to authenticated;
create policy shop_products_read on public.shop_products for select to authenticated using (true);

insert into public.shop_products (id, name, price, category, description, icon, available) values
  ('es_batu', 'Es Batu Pelindung', 200, 'Pelindung', 'Melindungi satu hari terlewat. Maksimal sesuai kapasitas profil.', 'esBatu', true),
  ('bingkai_emas', 'Bingkai Emas', 300, 'Bingkai', 'Lingkaran emas pada avatar profil.', 'bingkaiEmas', true),
  ('stiker_hewan', 'Paket Stiker Hewan', 150, 'Stiker', 'Stiker ekspresi maskot untuk chat klub dan feed.', 'stikerHewan', true)
on conflict (id) do nothing;

create or replace function public.buy_shop_item(p_product_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user public.users;
  v_prod public.shop_products;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select * into strict v_prod from public.shop_products where id = p_product_id and available = true;
  select * into strict v_user from public.users where id = auth.uid() for update;
  if v_user.gems < v_prod.price then
    raise exception 'Insufficient gems';
  end if;
  if p_product_id = 'es_batu' then
    if v_user.freezes >= v_user.max_freezes then
      raise exception 'Freezes full';
    end if;
    update public.users
      set gems = gems - v_prod.price, freezes = freezes + 1
      where id = auth.uid()
      returning * into v_user;
  else
    update public.users
      set gems = gems - v_prod.price,
          owned = case when p_product_id = any(owned) then owned else array_append(owned, p_product_id) end
      where id = auth.uid()
      returning * into v_user;
  end if;
  return jsonb_build_object('gems', v_user.gems, 'freezes', v_user.freezes, 'owned', v_user.owned);
end;
$$;
revoke all on function public.buy_shop_item(text) from public, anon, authenticated;
grant execute on function public.buy_shop_item(text) to authenticated;

-- 7. Tournaments
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
create policy tournaments_owner on public.tournaments for all to authenticated
  using (host_id = (select auth.uid())) with check (host_id = (select auth.uid()));

-- 8. League RPC: computes club standings & contributor points from live activities & clubs
create or replace function public.get_league_standings(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_club public.clubs;
  v_area text;
  v_standings jsonb;
  v_teammates jsonb;
begin
  select * into v_club from public.clubs where id = p_club_id;
  if not found then
    return jsonb_build_object('area', '[]'::jsonb, 'national', '[]'::jsonb, 'teammates', '[]'::jsonb);
  end if;
  v_area := coalesce(v_club.area, '');
  with club_points as (
    select
      c.id,
      c.name,
      coalesce(c.emoji, '🏆') as emoji,
      c.area,
      (select count(*) from public.club_members cm where cm.club_id = c.id and cm.status = 'active')::int as members,
      coalesce((
        select sum(greatest(1, a.duration_seconds / 60))::int
        from public.activities a
        where a.club_id = c.id and a.occurred_at >= date_trunc('month', now())
      ), 0) as points
    from public.clubs c
    where c.sport_id = v_club.sport_id
  ),
  ranked_nat as (
    select row_number() over (order by points desc, name asc)::int as rank, id, name, emoji, members, points, area
    from club_points
  ),
  ranked_area as (
    select row_number() over (order by points desc, name asc)::int as rank, id, name, emoji, members, points
    from club_points
    where v_area = '' or area = v_area
  ),
  team as (
    select
      coalesce(nullif(u.name, ''), u.username) as name,
      coalesce(u.avatar, 'kapi') as avatar,
      coalesce((
        select sum(greatest(1, a.duration_seconds / 60))::int
        from public.activities a
        where a.user_id = u.id and a.club_id = p_club_id and a.occurred_at >= date_trunc('month', now())
      ), 0) as points
    from public.club_members cm
    join public.users u on u.id = cm.user_id
    where cm.club_id = p_club_id and cm.status = 'active'
    order by points desc
    limit 20
  )
  select
    coalesce((select jsonb_agg(to_jsonb(r)) from ranked_area r limit 20), '[]'::jsonb),
    coalesce((select jsonb_agg(to_jsonb(r)) from ranked_nat r limit 20), '[]'::jsonb),
    coalesce((select jsonb_agg(to_jsonb(t)) from team t), '[]'::jsonb)
  into v_standings, v_area, v_teammates;

  return jsonb_build_object(
    'area', coalesce(v_standings, '[]'::jsonb),
    'national', coalesce((select jsonb_agg(to_jsonb(r)) from (
      select row_number() over (order by coalesce((
        select sum(greatest(1, a.duration_seconds / 60))::int
        from public.activities a
        where a.club_id = c.id and a.occurred_at >= date_trunc('month', now())
      ), 0) desc, c.name asc)::int as rank,
      c.id, c.name, coalesce(c.emoji, '🏆') as emoji,
      (select count(*) from public.club_members cm where cm.club_id = c.id and cm.status = 'active')::int as members,
      coalesce((
        select sum(greatest(1, a.duration_seconds / 60))::int
        from public.activities a
        where a.club_id = c.id and a.occurred_at >= date_trunc('month', now())
      ), 0) as points
      from public.clubs c where c.sport_id = v_club.sport_id limit 20
    ) r), '[]'::jsonb),
    'teammates', coalesce(v_teammates, '[]'::jsonb)
  );
end;
$$;
revoke all on function public.get_league_standings(uuid) from public, anon, authenticated;
grant execute on function public.get_league_standings(uuid) to authenticated;
