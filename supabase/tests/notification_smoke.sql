begin;

insert into auth.users(id) values
 ('73000000-0000-4000-8000-000000000031'),
 ('73000000-0000-4000-8000-000000000032');

set local role service_role;
do $$
declare first_id uuid; retry_id uuid;
begin
  first_id := public.send_notification('73000000-0000-4000-8000-000000000031','payment_expired',
    'Pembayaran kedaluwarsa','Slot sudah dilepas.','klubby-test:notification');
  retry_id := public.send_notification('73000000-0000-4000-8000-000000000031','payment_expired',
    'Pembayaran kedaluwarsa','Slot sudah dilepas.','klubby-test:notification');
  if first_id is null or first_id is distinct from retry_id then raise exception 'Retry must return original ID'; end if;
  perform set_config('klubby_test.notification_id', first_id::text, true);
  begin
    perform public.send_notification('73000000-0000-4000-8000-000000000032','payment_expired',
      'Pembayaran kedaluwarsa','Slot sudah dilepas.','klubby-test:notification');
    raise exception 'Delivery key conflict was accepted';
  exception when unique_violation then null;
  end;
end;
$$;
reset role;

set local role authenticated;
do $$
declare target_id uuid := current_setting('klubby_test.notification_id')::uuid;
begin
  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000032',true);
  if exists(select 1 from public.notifications where id=target_id)
    or public.mark_notifications_read(array[target_id]) <> 0 then raise exception 'Inbox isolation failed'; end if;

  if has_function_privilege(current_user,'public.send_notification(uuid,text,text,text,text,jsonb)','execute') then
    raise exception 'Authenticated users must not send arbitrary notifications';
  end if;

  perform set_config('request.jwt.claim.sub','73000000-0000-4000-8000-000000000031',true);
  if not exists(select 1 from public.notifications where id=target_id and read_at is null) then
    raise exception 'Recipient cannot read notification';
  end if;
  if public.mark_notifications_read(array[target_id]) <> 1 then raise exception 'Mark read failed'; end if;
  if public.mark_notifications_read(array[target_id]) <> 0 then raise exception 'Mark read retry changed inbox'; end if;
end;
$$;
reset role;
rollback;
