create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table public.users (
  id uuid primary key references auth.users on delete cascade,
  name varchar(100) not null default '',
  username varchar(50) not null,
  gender text check (gender in ('lakiLaki','perempuan','rahasia')),
  avatar text, photo_path text, avatar_bg bigint, accessory text,
  area text, location extensions.geography(Point,4326),
  radius_km smallint not null default 10 check (radius_km between 1 and 100),
  active_sport_id text not null default 'badminton',
  settings jsonb not null default '{}',
  joined timestamptz not null default now()
);
create unique index users_username_ci on public.users (lower(username));

create function public.klubby_create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.users(id, username) values (new.id, 'user_' || replace(new.id::text, '-', ''));
  return new;
end;
$$;
revoke all on function public.klubby_create_profile() from public, anon, authenticated;
create trigger klubby_on_auth_user_created after insert on auth.users
for each row execute function public.klubby_create_profile();

insert into public.users(id, username)
select id, 'user_' || replace(id::text, '-', '') from auth.users;

create table public.user_sports (
  user_id uuid not null references public.users on delete cascade,
  sport_id text not null,
  level text not null check (level in ('pemula','pemulaPlus','menengah','menengahPlus','mahir','pro')),
  positions text[] not null default '{}',
  primary key (user_id,sport_id)
);

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.users,
  name varchar(100) not null check (btrim(name) <> ''),
  sport_id text not null,
  initials text, color bigint, emoji text, area text, schedule text, note text, logo_path text,
  location extensions.geography(Point,4326),
  privacy text not null default 'publik' check (privacy in ('publik','persetujuan')),
  pinned_note text, pro boolean not null default false
);
create index clubs_location_idx on public.clubs using gist(location);

create table public.club_members (
  club_id uuid not null references public.clubs on delete cascade,
  user_id uuid not null references public.users on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  status text not null default 'pending' check (status in ('pending','active')),
  joined_at timestamptz not null default now(),
  primary key (club_id,user_id)
);
create table public.club_messages (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs on delete cascade,
  user_id uuid not null references public.users,
  body text not null check (length(btrim(body)) between 1 and 4000),
  sticker boolean not null default false,
  created_at timestamptz not null default now()
);
create index club_messages_timeline on public.club_messages (club_id,created_at desc);

create table public.mabar_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.users,
  club_id uuid not null references public.clubs on delete cascade,
  title varchar(150) not null, sport_id text not null,
  starts_at timestamptz not null, ends_at timestamptz not null check (ends_at > starts_at),
  deadline_at timestamptz check (deadline_at <= starts_at),
  venue varchar(150) not null, court text, level text, shuttle text,
  fee integer not null default 0 check (fee >= 0),
  slots smallint not null check (slots > 0),
  guest_max smallint not null default 2 check (guest_max >= 0),
  recurring boolean not null default false, qris boolean not null default true,
  auto_waitlist boolean not null default true, cancelled boolean not null default false,
  cancellation_reason text
);
create index mabar_sessions_club_schedule on public.mabar_sessions (club_id,starts_at);

create table public.session_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.mabar_sessions on delete cascade,
  user_id uuid not null references public.users,
  name varchar(100) not null,
  status text not null check (status in ('lunas','menunggu','belumBayar')),
  via text not null default 'APP' check (via in ('APP','WEB')),
  present boolean not null default false,
  refunded boolean not null default false,
  no_show boolean not null default false,
  is_waitlist boolean not null default false,
  cancelled_at timestamptz,
  payment_expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (session_id,user_id)
);
create index participants_queue on public.session_participants(session_id,created_at,id)
  where is_waitlist and cancelled_at is null;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users on delete cascade,
  kind text not null, payload jsonb not null default '{}',
  created_at timestamptz not null default now(), read_at timestamptz
);
create index notifications_inbox on public.notifications(user_id,created_at desc);

create function public.is_club_member(p_club_id uuid, p_admin boolean default false)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.club_members
    where club_id = p_club_id and user_id = auth.uid() and status = 'active'
      and (not p_admin or role = 'admin'));
$$;
revoke all on function public.is_club_member(uuid,boolean) from public, anon, authenticated;
grant execute on function public.is_club_member(uuid,boolean) to authenticated;

create function public.klubby_club_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.club_members(club_id,user_id,role,status) values(new.id,new.created_by,'admin','active');
  return new;
end;
$$;
revoke all on function public.klubby_club_owner() from public, anon, authenticated;
create trigger klubby_club_owner after insert on public.clubs
for each row execute function public.klubby_club_owner();

create function public.join_club(p_club_id uuid) returns public.club_members
language plpgsql security definer set search_path = '' as $$
declare v_privacy text; v_member public.club_members;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select privacy into strict v_privacy from public.clubs where id = p_club_id;
  insert into public.club_members(club_id,user_id,status)
  values (p_club_id,auth.uid(),case when v_privacy = 'publik' then 'active' else 'pending' end)
  on conflict (club_id,user_id) do nothing;
  select * into strict v_member from public.club_members where club_id=p_club_id and user_id=auth.uid();
  return v_member;
end;
$$;
revoke all on function public.join_club(uuid) from public, anon, authenticated;
grant execute on function public.join_club(uuid) to authenticated;

create function public.approve_club_member(p_club_id uuid,p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_club_member(p_club_id,true) then raise exception 'Club admin required'; end if;
  update public.club_members set status='active'
  where club_id=p_club_id and user_id=p_user_id and status='pending';
  if found then
    insert into public.notifications(user_id,kind,payload)
    values(p_user_id,'club_join_approved',jsonb_build_object('club_id',p_club_id));
  end if;
end;
$$;
revoke all on function public.approve_club_member(uuid,uuid) from public, anon, authenticated;
grant execute on function public.approve_club_member(uuid,uuid) to authenticated;
