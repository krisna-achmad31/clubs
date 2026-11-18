create or replace function public.create_club_full(p_club jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_club public.clubs;
  v_payout jsonb := p_club->'payout';
  v_name text := btrim(p_club->>'name');
  v_lat double precision := (p_club->>'area_lat')::double precision;
  v_lng double precision := (p_club->>'area_lng')::double precision;
  v_location extensions.geography;
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
  if v_lat is not null or v_lng is not null then
    if v_lat is null or v_lng is null or v_lat not between -90 and 90 or v_lng not between -180 and 180 then
      raise sqlstate 'PT400' using message = 'Koordinat area klub tidak valid. Pilih area lagi.';
    end if;
    v_location := extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography;
  end if;
  insert into public.clubs(created_by, name, sport_id, initials, color, emoji, area, privacy, code, logo_path, location)
  values(auth.uid(), v_name, p_club->>'sport_id', p_club->>'initials', (p_club->>'color')::bigint,
    p_club->>'emoji', p_club->>'area', p_club->>'privacy',
    upper(left(replace(gen_random_uuid()::text, '-', ''), 12)), p_club->>'logo_path', v_location)
  returning * into v_club;

  if v_payout is not null then
    insert into public.club_payout_accounts(club_id, provider, number, holder)
    values (v_club.id, v_payout->>'provider', v_payout->>'number', v_payout->>'holder');
  end if;
  return (to_jsonb(v_club) - array['payout_provider','payout_number','payout_holder'])
    || jsonb_build_object('club_payout_accounts', v_payout);
end;
$$;

notify pgrst, 'reload schema';
