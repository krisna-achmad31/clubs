create table public.challenges (
  id text primary key,
  title text not null,
  description text not null,
  kind text not null check (kind in ('pribadi', 'klub', 'teman')),
  sport_id text not null,
  metric text not null check (metric in ('distance', 'active_days', 'club_hours', 'friend_sessions')),
  goal integer not null check (goal > 0),
  unit text not null check (unit in ('km', 'hari', 'jam', 'sesi')),
  sort_order integer not null
);

create table public.challenge_memberships (
  challenge_id text not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (user_id, challenge_id)
);

alter table public.challenges enable row level security;
alter table public.challenge_memberships enable row level security;
revoke all on public.challenges, public.challenge_memberships from public, anon, authenticated;

-- Accept the recorder's activity payload on installations with the original activity schema.
alter table public.activities
  add column if not exists note text not null default '',
  add column if not exists distance_km double precision,
  add column if not exists avg_hr integer,
  add column if not exists route jsonb not null default '[]',
  add column if not exists splits integer[] not null default '{}';
grant insert(note, distance_km, avg_hr, route, splits) on public.activities to authenticated;
grant update(note) on public.activities to authenticated;

create index if not exists challenges_activity_user_time_idx on public.activities(user_id, occurred_at);
create index if not exists challenges_rsvp_user_idx on public.session_participants(user_id, session_id);

insert into public.challenges (id, title, description, kind, sport_id, metric, goal, unit, sort_order) values
  ('run', 'Lari 50 km', 'Kumpulkan 50 km dari aktivitas lari yang tersimpan setelah bergabung.', 'pribadi', 'lari', 'distance', 50, 'km', 1),
  ('club', '100 jam Mabar klub', 'Hitung durasi Mabar klub yang sudah berakhir dan reservasinya terkonfirmasi setelah kamu bergabung ke tantangan.', 'klub', 'badminton', 'club_hours', 100, 'jam', 2),
  ('friends', '5 Mabar bareng teman', 'Ikuti 5 Mabar yang sudah berakhir dengan minimal satu akun yang kamu ikuti. Reservasi kalian harus terkonfirmasi.', 'teman', 'futsal', 'friend_sessions', 5, 'sesi', 3),
  ('active', '7 hari aktif', 'Simpan aktivitas pada 7 hari berbeda setelah bergabung. Hari dihitung berdasarkan waktu Jakarta.', 'pribadi', 'lari', 'active_days', 7, 'hari', 4),
  ('cycle', 'Gowes 200 km', 'Kumpulkan 200 km dari aktivitas sepeda yang tersimpan setelah bergabung.', 'pribadi', 'sepeda', 'distance', 200, 'km', 5);

create function public.list_challenges()
returns table (
  id text, title text, description text, kind text, sport_id text,
  goal integer, unit text, joined boolean, progress numeric, completed boolean
)
language sql stable security definer set search_path = '' as $$
  select c.id, c.title, c.description, c.kind, c.sport_id, c.goal, c.unit,
    m.joined_at is not null, score.value, score.value >= c.goal
  from public.challenges c
  left join public.challenge_memberships m on m.challenge_id = c.id and m.user_id = auth.uid()
  cross join lateral (
    select case when m.joined_at is null then 0::numeric else
      case c.metric
        when 'distance' then (
          select coalesce(sum(a.distance_km::numeric), 0)
          from public.activities a
          where a.user_id = m.user_id and a.sport_id = c.sport_id
            and a.occurred_at between m.joined_at and now()
            and a.distance_km > 0 and a.distance_km < 'Infinity'::double precision
        )
        when 'active_days' then (
          select count(distinct (a.occurred_at at time zone 'Asia/Jakarta')::date)
          from public.activities a
          where a.user_id = m.user_id and a.occurred_at between m.joined_at and now()
        )
        else (
          select case c.metric
            when 'club_hours' then coalesce(sum(extract(epoch from (s.ends_at - s.starts_at))), 0) / 3600
            else count(*)::numeric
          end
          from public.session_participants p
          join public.mabar_sessions s on s.id = p.session_id
          where p.user_id = m.user_id and p.status = 'lunas'
            and not p.is_waitlist and not p.refunded and not p.no_show and p.cancelled_at is null
            and not s.cancelled and s.starts_at >= m.joined_at and s.ends_at <= now()
            and (c.metric = 'club_hours' or exists (
              select 1 from public.session_participants friend
              join public.user_follows f on f.follower_id = m.user_id and f.followed_id = friend.user_id
              where friend.session_id = s.id and friend.status = 'lunas'
                and not friend.is_waitlist and not friend.refunded and not friend.no_show
                and friend.cancelled_at is null
            ))
        )
      end
    end as value
  ) score
  where auth.uid() is not null
  order by c.sort_order, c.id;
$$;

create function public.set_challenge_membership(p_challenge_id text, p_join boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Login required'; end if;
  if p_challenge_id is null or p_join is null then raise exception 'Invalid challenge request'; end if;
  if p_join then
    insert into public.challenge_memberships(challenge_id, user_id)
    values (p_challenge_id, v_user_id)
    on conflict (user_id, challenge_id) do nothing;
  else
    delete from public.challenge_memberships
    where user_id = v_user_id and challenge_id = p_challenge_id;
  end if;
end;
$$;

revoke all on function public.list_challenges(), public.set_challenge_membership(text, boolean)
  from public, anon, authenticated;
grant execute on function public.list_challenges(), public.set_challenge_membership(text, boolean)
  to authenticated;
notify pgrst, 'reload schema';
