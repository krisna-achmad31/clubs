alter table public.clubs
  add column if not exists code text,
  add column if not exists sessions_per_week integer not null default 1;
grant insert(code) on public.clubs to authenticated;

create table public.club_payout_accounts (
  club_id uuid primary key references public.clubs(id) on delete cascade,
  provider text not null check (length(btrim(provider)) > 0),
  number text not null check (length(btrim(number)) > 0),
  holder text not null check (length(btrim(holder)) > 0)
);
alter table public.club_payout_accounts enable row level security;
revoke all on public.club_payout_accounts from public, anon, authenticated;
grant select, insert, update on public.club_payout_accounts to authenticated;
create policy club_payout_admin on public.club_payout_accounts for all to authenticated
  using (public.is_club_member(club_id, true))
  with check (public.is_club_member(club_id, true));

insert into public.club_payout_accounts(club_id, provider, number, holder)
select c.id, to_jsonb(c)->>'payout_provider', to_jsonb(c)->>'payout_number', to_jsonb(c)->>'payout_holder'
from public.clubs c
where nullif(btrim(to_jsonb(c)->>'payout_provider'), '') is not null
  and nullif(btrim(to_jsonb(c)->>'payout_number'), '') is not null
  and nullif(btrim(to_jsonb(c)->>'payout_holder'), '') is not null;

create function public.create_club_full(p_club jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_club public.clubs;
  v_payout jsonb := p_club->'payout';
  v_name text := btrim(p_club->>'name');
begin
  if auth.uid() is null then raise sqlstate 'PT401' using message = 'Masuk dulu untuk membuat klub.'; end if;
  if v_name is null or length(v_name) not between 1 and 100 then
    raise sqlstate 'PT400' using message = 'Nama klub harus berisi 1–100 karakter.';
  end if;
  if v_payout is not null and (
    coalesce(btrim(v_payout->>'provider'), '') = ''
    or coalesce(btrim(v_payout->>'number'), '') = ''
    or coalesce(btrim(v_payout->>'holder'), '') = ''
  ) then
    raise sqlstate 'PT400' using message = 'Lengkapi data rekening klub.';
  end if;
  insert into public.clubs(created_by, name, sport_id, initials, color, emoji, area, privacy, code, logo_path)
  values(auth.uid(), v_name, p_club->>'sport_id', p_club->>'initials', (p_club->>'color')::bigint,
    p_club->>'emoji', p_club->>'area', p_club->>'privacy',
    upper(left(replace(gen_random_uuid()::text, '-', ''), 12)), p_club->>'logo_path')
  returning * into v_club;

  if v_payout is not null then
    insert into public.club_payout_accounts(club_id, provider, number, holder)
    values (v_club.id, v_payout->>'provider', v_payout->>'number', v_payout->>'holder');
  end if;
  return (to_jsonb(v_club) - array['payout_provider','payout_number','payout_holder'])
    || jsonb_build_object('club_payout_accounts', v_payout);
end;
$$;

create function public.find_club_users(p_terms text[])
returns table (id uuid, name text, username text, phone text)
language sql stable security definer set search_path = '' as $$
  with terms as (
    select distinct lower(ltrim(btrim(term), '@')) as key
    from unnest(p_terms[1:100]) as term
    where length(btrim(term)) between 1 and 80
  )
  select u.id, coalesce(nullif(u.name, ''), u.username)::text, u.username::text, coalesce(matched.phone, '')
  from public.users u
  left join lateral (
    select a.phone
    from auth.users a join terms t on t.key = a.phone
    where a.id = u.id and a.phone_confirmed_at is not null
      and t.key ~ '^[0-9]{9,15}$'
    limit 1
  ) matched on true
  where u.id <> auth.uid() and (matched.phone is not null
    or exists(select 1 from terms t where t.key = lower(u.username)))
  order by u.username
  limit 100;
$$;

create function public.add_club_member(p_club_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_club_member(p_club_id, true) then
    raise sqlstate 'PT403' using message = 'Hanya admin klub yang bisa menambah anggota.';
  end if;
  if not exists(select 1 from public.users where id = p_user_id) then
    raise sqlstate 'PT404' using message = 'Akun anggota sudah tidak tersedia.';
  end if;
  insert into public.club_members(club_id,user_id,role,status)
  values(p_club_id,p_user_id,'member','active')
  on conflict (club_id,user_id) do update set status = 'active'
  where club_members.status = 'pending';
end;
$$;

revoke all on function public.create_club_full(jsonb), public.find_club_users(text[]), public.add_club_member(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.create_club_full(jsonb), public.find_club_users(text[]), public.add_club_member(uuid,uuid)
  to authenticated;
notify pgrst, 'reload schema';
