create extension if not exists pg_cron;

select cron.schedule('klubby-expire-mabar-payments', '* * * * *',
  'select public.expire_mabar_payments()');

create function public.discover_clubs(p_lat double precision,p_lon double precision,
  p_radius_km integer default 10,p_sport_id text default null)
returns table(club_id uuid,distance_km double precision)
language sql stable set search_path = '' as $$
  select c.id,extensions.st_distance(c.location,origin.point)/1000
  from public.clubs c
  cross join lateral (select extensions.st_setsrid(extensions.st_makepoint(p_lon,p_lat),4326)::extensions.geography as point) origin
  where p_lat between -90 and 90 and p_lon between -180 and 180 and p_radius_km between 1 and 100
    and (p_sport_id is null or c.sport_id=p_sport_id)
    and extensions.st_dwithin(c.location,origin.point,p_radius_km*1000)
  order by 2,c.id limit 100;
$$;
revoke all on function public.discover_clubs(double precision,double precision,integer,text) from public,anon,authenticated;
grant execute on function public.discover_clubs(double precision,double precision,integer,text) to authenticated;

create function public.klubby_notify_session_cancelled() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.cancelled and not new.cancelled then
    raise exception 'Cancelled sessions cannot be reopened';
  end if;
  if new.cancelled and not old.cancelled then
    insert into public.notifications(user_id,kind,payload)
    select user_id,'mabar_cancelled',jsonb_build_object('session_id',new.id)
    from public.session_participants where session_id=new.id and cancelled_at is null;
  end if;
  return new;
end;
$$;
revoke all on function public.klubby_notify_session_cancelled() from public,anon,authenticated;
create trigger klubby_notify_session_cancelled after update of cancelled on public.mabar_sessions
for each row execute function public.klubby_notify_session_cancelled();
