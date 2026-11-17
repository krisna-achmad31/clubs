-- Serialize slot and queue changes on the session row.
create function public.rsvp_mabar(p_session_id uuid, p_via text default 'APP')
returns public.session_participants language plpgsql security definer set search_path = '' as $$
declare s public.mabar_sessions; p public.session_participants; v_name text; v_wait boolean;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select * into strict s from public.mabar_sessions where id = p_session_id for update;
  if s.cancelled or s.starts_at <= now() then raise exception 'Session closed'; end if;
  if not public.is_club_member(s.club_id) and not exists (
    select 1 from public.clubs where id=s.club_id and privacy='publik'
  ) then raise exception 'Club membership required'; end if;
  select * into p from public.session_participants where session_id=s.id and user_id=auth.uid();
  if found and p.cancelled_at is null then return p; end if;
  select coalesce(nullif(name,''),username) into strict v_name from public.users where id=auth.uid();
  select count(*) >= s.slots into v_wait from public.session_participants
    where session_id=s.id and not is_waitlist and cancelled_at is null;
  if v_wait and not s.auto_waitlist then raise exception 'Session full'; end if;
  insert into public.session_participants(session_id,user_id,name,status,via,is_waitlist,payment_expires_at)
  values(s.id,auth.uid(),v_name,case when v_wait then 'belumBayar' when s.fee=0 then 'lunas' else 'menunggu' end,
    p_via,v_wait,case when not v_wait and s.fee>0 and s.qris then least(now()+interval '15 minutes',s.starts_at) end)
  on conflict (session_id,user_id) do update set name=excluded.name,status=excluded.status,via=excluded.via,
    is_waitlist=excluded.is_waitlist,payment_expires_at=excluded.payment_expires_at,cancelled_at=null,created_at=now()
  returning * into p;
  return p;
end;
$$;
revoke all on function public.rsvp_mabar(uuid,text) from public, anon, authenticated;
grant execute on function public.rsvp_mabar(uuid,text) to authenticated;

create function public.klubby_promote_waitlist(p_session_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare s public.mabar_sessions; v_slots integer; v_user uuid;
begin
  select * into strict s from public.mabar_sessions where id=p_session_id for update;
  if not s.auto_waitlist or s.cancelled or now() >= coalesce(s.deadline_at,s.starts_at) then return; end if;
  select s.slots-count(*) into v_slots from public.session_participants
    where session_id=s.id and not is_waitlist and cancelled_at is null;
  for v_user in
    update public.session_participants set is_waitlist=false,
      status=case when s.fee=0 then 'lunas' else 'menunggu' end,
      payment_expires_at=case when s.fee>0 and s.qris then least(now()+interval '15 minutes',s.starts_at) end
    where id in (select id from public.session_participants where session_id=s.id and is_waitlist
      and cancelled_at is null order by created_at,id limit greatest(v_slots,0))
    returning user_id
  loop
    insert into public.notifications(user_id,kind,payload)
    values(v_user,'waitlist_promoted',jsonb_build_object('session_id',s.id));
  end loop;
end;
$$;
revoke all on function public.klubby_promote_waitlist(uuid) from public, anon, authenticated;

create function public.cancel_mabar_rsvp(p_session_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare s public.mabar_sessions;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select * into strict s from public.mabar_sessions where id=p_session_id for update;
  if now() >= coalesce(s.deadline_at,s.starts_at) then raise exception 'Cancellation closed'; end if;
  update public.session_participants set cancelled_at=now()
    where session_id=s.id and user_id=auth.uid() and cancelled_at is null
    and (status<>'lunas' or s.fee=0);
  if not found then
    if exists (select 1 from public.session_participants where session_id=s.id and user_id=auth.uid()
      and cancelled_at is null and status='lunas') then raise exception 'Paid RSVP requires a refund'; end if;
    return;
  end if;
  perform public.klubby_promote_waitlist(s.id);
end;
$$;
revoke all on function public.cancel_mabar_rsvp(uuid) from public, anon, authenticated;
grant execute on function public.cancel_mabar_rsvp(uuid) to authenticated;

create function public.expire_mabar_payments() returns void
language plpgsql security definer set search_path = '' as $$
declare v_session uuid; v_user uuid;
begin
  for v_session in select s.id from public.mabar_sessions s where exists (
    select 1 from public.session_participants p where p.session_id=s.id and p.status='menunggu'
      and p.cancelled_at is null and p.payment_expires_at<=now()
  ) order by s.id for update of s skip locked loop
    for v_user in
      update public.session_participants set cancelled_at=now(),status='belumBayar'
      where session_id=v_session and status='menunggu' and cancelled_at is null and payment_expires_at<=now()
      returning user_id
    loop
      insert into public.notifications(user_id,kind,payload)
      values(v_user,'payment_expired',jsonb_build_object('session_id',v_session));
    end loop;
    perform public.klubby_promote_waitlist(v_session);
  end loop;
end;
$$;
revoke all on function public.expire_mabar_payments() from public, anon, authenticated;
grant execute on function public.expire_mabar_payments() to service_role;
create index participants_payment_expiry on public.session_participants(payment_expires_at)
where status='menunggu' and cancelled_at is null;

alter table public.users enable row level security;
alter table public.user_sports enable row level security;
alter table public.clubs enable row level security;
alter table public.club_members enable row level security;
alter table public.club_messages enable row level security;
alter table public.mabar_sessions enable row level security;
alter table public.session_participants enable row level security;
alter table public.notifications enable row level security;

revoke all on public.users, public.user_sports, public.clubs, public.club_members, public.club_messages,
  public.mabar_sessions, public.session_participants, public.notifications from public, anon, authenticated;
grant select on public.users, public.user_sports, public.clubs, public.club_members, public.club_messages,
  public.mabar_sessions, public.session_participants, public.notifications to authenticated;
grant update(name,username,gender,avatar,photo_path,avatar_bg,accessory,area,location,radius_km,active_sport_id,settings)
  on public.users to authenticated;
grant insert,update,delete on public.user_sports to authenticated;
grant insert(created_by,name,sport_id,initials,color,emoji,area,schedule,note,logo_path,location,privacy,pinned_note)
  on public.clubs to authenticated;
grant update(name,sport_id,initials,color,emoji,area,schedule,note,logo_path,location,privacy,pinned_note)
  on public.clubs to authenticated;
grant insert(club_id,user_id,body,sticker) on public.club_messages to authenticated;
grant insert(host_id,club_id,title,sport_id,starts_at,ends_at,deadline_at,venue,court,level,shuttle,
  fee,slots,guest_max,recurring,qris,auto_waitlist) on public.mabar_sessions to authenticated;
-- Keep capacity, fees, deadlines, and ownership immutable after publication.
grant update(title,venue,court,level,shuttle,cancelled,cancellation_reason) on public.mabar_sessions to authenticated;
grant update(read_at) on public.notifications to authenticated;

create policy self_profile_read on public.users for select to authenticated using (id=(select auth.uid()));
create policy self_profile_update on public.users for update to authenticated
  using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy self_sports on public.user_sports for all to authenticated
  using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy discover_clubs on public.clubs for select to authenticated using (true);
create policy create_club on public.clubs for insert to authenticated with check (created_by=(select auth.uid()));
create policy edit_club on public.clubs for update to authenticated
  using (public.is_club_member(id,true)) with check (public.is_club_member(id,true));
create policy read_members on public.club_members for select to authenticated
  using (user_id=(select auth.uid()) or (status='active' and public.is_club_member(club_id))
    or public.is_club_member(club_id,true));
create policy read_chat on public.club_messages for select to authenticated using (public.is_club_member(club_id));
create policy write_chat on public.club_messages for insert to authenticated
  with check (user_id=(select auth.uid()) and public.is_club_member(club_id));
create policy read_sessions on public.mabar_sessions for select to authenticated
  using (host_id=(select auth.uid()) or public.is_club_member(club_id)
    or exists(select 1 from public.clubs c where c.id=club_id and c.privacy='publik'));
create policy host_session on public.mabar_sessions for insert to authenticated
  with check (host_id=(select auth.uid()) and public.is_club_member(club_id,true));
create policy edit_session on public.mabar_sessions for update to authenticated
  using (host_id=(select auth.uid())) with check (host_id=(select auth.uid()));
create policy read_participants on public.session_participants for select to authenticated
  using (user_id=(select auth.uid()) or exists (
    select 1 from public.mabar_sessions s where s.id=session_id and s.host_id=(select auth.uid())
  ));
create policy read_notifications on public.notifications for select to authenticated using (user_id=(select auth.uid()));
create policy mark_notifications on public.notifications for update to authenticated
  using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp']),
  ('club-logos','club-logos',true,5242880,array['image/jpeg','image/png','image/webp']),
  ('activity-photos','activity-photos',false,10485760,array['image/jpeg','image/png','image/webp']);

create policy klubby_user_images on storage.objects for all to authenticated
  using (bucket_id in ('avatars','activity-photos') and (storage.foldername(name))[1]=(select auth.uid())::text)
  with check (bucket_id in ('avatars','activity-photos') and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy klubby_club_logos on storage.objects for all to authenticated
  using (bucket_id='club-logos' and public.is_club_member(
    case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid end,true))
  with check (bucket_id='club-logos' and public.is_club_member(
    case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid end,true));

alter publication supabase_realtime add table public.club_messages, public.mabar_sessions,
  public.session_participants, public.notifications;
