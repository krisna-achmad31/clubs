create table public.user_follows (
  follower_id uuid not null references public.users(id) on delete cascade,
  followed_id uuid not null references public.users(id) on delete cascade,
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create index user_follows_followed_idx on public.user_follows(followed_id, follower_id);
alter table public.user_follows enable row level security;
revoke all on public.user_follows from public, anon, authenticated;

create function public.my_follow_counts()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'following', (select count(*) from public.user_follows where follower_id = auth.uid()),
    'followers', (select count(*) from public.user_follows where followed_id = auth.uid())
  );
$$;

create function public.find_people(p_mode text, p_query text, p_offset integer)
returns table (id uuid, name text, username text, avatar text, is_following boolean)
language sql stable security definer set search_path = '' as $$
  with term as (
    select lower(left(ltrim(btrim(p_query), '@'), 100)) as value
  )
  select u.id, coalesce(nullif(u.name, ''), u.username)::text, u.username::text,
    u.avatar, mine.followed_id is not null
  from public.users u
  cross join term
  left join public.user_follows mine on mine.follower_id = auth.uid() and mine.followed_id = u.id
  left join public.user_follows incoming on incoming.follower_id = u.id and incoming.followed_id = auth.uid()
  where u.id <> auth.uid()
    and case p_mode
      when 'search' then u.name <> '' and length(term.value) >= 2 and
        (strpos(lower(u.name), term.value) > 0 or strpos(lower(u.username), term.value) > 0)
      when 'following' then mine.followed_id is not null
      when 'followers' then incoming.follower_id is not null
      else false
    end
  order by lower(u.name), u.id
  limit 31 offset greatest(p_offset, 0);
$$;

create function public.set_user_follow(p_user_id uuid, p_follow boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Login required'; end if;
  if p_user_id is null or p_user_id = v_user_id or p_follow is null then
    raise exception 'Invalid follow request';
  end if;
  if p_follow then
    insert into public.user_follows(follower_id, followed_id) values (v_user_id, p_user_id)
    on conflict (follower_id, followed_id) do nothing;
  else
    delete from public.user_follows where follower_id = v_user_id and followed_id = p_user_id;
  end if;
end;
$$;

revoke all on function public.my_follow_counts(),
  public.find_people(text, text, integer), public.set_user_follow(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.my_follow_counts(),
  public.find_people(text, text, integer), public.set_user_follow(uuid, boolean)
  to authenticated;
notify pgrst, 'reload schema';
