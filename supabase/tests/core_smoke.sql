-- Run within a transaction. The caller rolls back to the smoke-test savepoint.
insert into auth.users(id) values
 ('73000000-0000-4000-8000-000000000001'),
 ('73000000-0000-4000-8000-000000000002'),
 ('73000000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000001',true);
insert into public.clubs(created_by,name,sport_id) values(auth.uid(),'Klubby smoke test','badminton');
insert into public.mabar_sessions(host_id,club_id,title,sport_id,starts_at,ends_at,venue,slots)
select auth.uid(),id,'Test','badminton',now()+interval '1 day',now()+interval '25 hours','Test',1
from public.clubs where name='Klubby smoke test' and created_by=auth.uid();

do $$
declare sid uuid; p public.session_participants;
begin
  select id into strict sid from public.mabar_sessions where title='Test'
    and host_id='73000000-0000-4000-8000-000000000001';
  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000002',true);
  if (select count(*) from public.users) <> 1 then raise exception 'Profile isolation failed'; end if;
  p := public.rsvp_mabar(sid);
  if p.is_waitlist or p.status<>'lunas' then raise exception 'Free RSVP failed'; end if;
  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000003',true);
  if exists(select 1 from public.session_participants where id=p.id) then raise exception 'RSVP isolation failed'; end if;
  p := public.rsvp_mabar(sid);
  if not p.is_waitlist then raise exception 'Capacity check failed'; end if;
  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000002',true);
  perform public.cancel_mabar_rsvp(sid);
  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000003',true);
  select * into strict p from public.session_participants where session_id=sid;
  if p.is_waitlist or p.status<>'lunas' then raise exception 'Waitlist promotion failed'; end if;
  if not exists(select 1 from public.notifications where kind='waitlist_promoted')
    then raise exception 'Waitlist notification missing'; end if;
end;
$$;
reset role;
