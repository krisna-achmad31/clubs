alter table public.notifications
  add column delivery_key text unique;

create function public.send_notification(
  p_user_id uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_delivery_key text,
  p_payload jsonb default '{}'
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare v_id uuid;
begin
  if p_kind is null or p_kind !~ '^[a-z][a-z0-9_]{0,63}$'
    or length(btrim(coalesce(p_title,''))) not between 1 and 120
    or length(btrim(coalesce(p_body,''))) not between 1 and 500
    or length(btrim(coalesce(p_delivery_key,''))) not between 1 and 200
    or jsonb_typeof(p_payload) is distinct from 'object'
    or octet_length(p_payload::text) > 4096
  then
    raise exception using errcode='22023', message='Invalid notification';
  end if;

  insert into public.notifications(user_id,kind,payload,delivery_key)
  values(p_user_id,p_kind,p_payload || jsonb_build_object('title',p_title,'body',p_body),p_delivery_key)
  on conflict(delivery_key) do nothing returning id into v_id;

  if v_id is null then
    select id into v_id from public.notifications
    where delivery_key=p_delivery_key and user_id=p_user_id and kind=p_kind
      and payload=p_payload || jsonb_build_object('title',p_title,'body',p_body);
    if v_id is null then
      raise exception using errcode='23505', message='Notification delivery key already in use';
    end if;
  end if;
  return v_id;
end;
$$;

revoke all on function public.send_notification(uuid,text,text,text,text,jsonb) from public, anon, authenticated;
grant select,insert on public.notifications to service_role;
grant execute on function public.send_notification(uuid,text,text,text,text,jsonb) to service_role;

create function public.mark_notifications_read(p_ids uuid[])
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_updated integer;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if coalesce(cardinality(p_ids),0) not between 1 and 100 then
    raise exception using errcode='22023', message='Provide 1 to 100 notification IDs';
  end if;
  update public.notifications set read_at=now()
  where id=any(p_ids) and user_id=auth.uid() and read_at is null;
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke all on function public.mark_notifications_read(uuid[]) from public, anon, authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
