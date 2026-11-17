-- A host supplies an existing static QR image from the club's Storage folder.
alter table public.mabar_sessions add column payment_qr_path text;
alter table public.session_participants add column payment_reported_at timestamptz;

create function public.reset_mabar_payment_report() returns trigger
language plpgsql set search_path='' as $$
begin
  if old.cancelled_at is not null and new.cancelled_at is null then
    new.payment_reported_at := null;
  end if;
  return new;
end;
$$;
revoke all on function public.reset_mabar_payment_report() from public,anon,authenticated;
create trigger reset_mabar_payment_report before update of cancelled_at on public.session_participants
for each row execute function public.reset_mabar_payment_report();

create policy klubby_payment_qr_read on storage.objects for select to authenticated using (
  bucket_id='club-logos' and exists (
    select 1 from public.mabar_sessions s where s.payment_qr_path=objects.name and not s.cancelled
  )
);

create function public.set_mabar_payment_qr(p_session_id uuid,p_path text) returns void
language plpgsql security definer set search_path='' as $$
begin
  update public.mabar_sessions s set payment_qr_path=p_path
  where s.id=p_session_id and s.host_id=auth.uid() and not s.cancelled
    and s.fee>0 and split_part(p_path,'/',1)=s.club_id::text
    and exists(select 1 from storage.objects where bucket_id='club-logos' and name=p_path);
  if not found then raise exception using errcode='42501',message='Host and existing club QR image required'; end if;
end;
$$;

create function public.report_mabar_payment(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare s public.mabar_sessions;
begin
  if auth.uid() is null then raise exception using errcode='42501',message='Login required'; end if;
  select * into strict s from public.mabar_sessions where id=p_session_id for update;
  if s.cancelled or s.starts_at<=now() or s.payment_qr_path is null then
    raise exception using errcode='22023',message='Session is closed or has no payment QR';
  end if;
  update public.session_participants set payment_reported_at=coalesce(payment_reported_at,now()),payment_expires_at=null
  where session_id=s.id and user_id=auth.uid() and status='menunggu' and not is_waitlist
    and cancelled_at is null and (payment_expires_at is null or payment_expires_at>now());
  if not found then raise exception using errcode='42501',message='An active payment reservation is required'; end if;
end;
$$;

create function public.review_mabar_payment(p_session_id uuid,p_participant_id uuid,p_approved boolean) returns void
language plpgsql security definer set search_path='' as $$
declare s public.mabar_sessions; v_user uuid;
begin
  select * into strict s from public.mabar_sessions where id=p_session_id for update;
  if s.host_id is distinct from auth.uid() or s.cancelled or s.starts_at<=now() or p_approved is null then
    raise exception using errcode='42501',message='Active session host required';
  end if;
  update public.session_participants
  set status=case when p_approved then 'lunas' else 'menunggu' end,
    payment_reported_at=case when p_approved then payment_reported_at end,
    payment_expires_at=case when not p_approved then least(now()+interval '15 minutes',s.starts_at) end
  where id=p_participant_id and session_id=s.id and status='menunggu' and not is_waitlist
    and cancelled_at is null and payment_reported_at is not null
  returning user_id into v_user;
  if found then
    insert into public.notifications(user_id,kind,payload)
    values(v_user,case when p_approved then 'payment_confirmed' else 'payment_rejected' end,jsonb_build_object('session_id',s.id));
  end if;
end;
$$;

revoke all on function public.set_mabar_payment_qr(uuid,text),public.report_mabar_payment(uuid),
  public.review_mabar_payment(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.set_mabar_payment_qr(uuid,text),public.report_mabar_payment(uuid),
  public.review_mabar_payment(uuid,uuid,boolean) to authenticated;
