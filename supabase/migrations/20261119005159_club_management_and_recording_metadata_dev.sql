-- Recording metadata is client-reported; trusted source/verified_at remain server-owned.
create schema if not exists klubby_internal;
revoke all on schema klubby_internal from public, anon;
grant usage on schema klubby_internal to authenticated;

alter table klubby_dev.activities
 add column if not exists recording_source text check (recording_source in ('manual','gps','wearable','qr','goyang')),
 add column if not exists elapsed_seconds integer check (elapsed_seconds >= duration_seconds),
 add column if not exists device text,
 add column if not exists samples jsonb not null default '[]'::jsonb check (jsonb_typeof(samples) = 'array'),
 add column if not exists hide_hr boolean not null default false;
grant insert(recording_source,elapsed_seconds,device,samples,hide_hr) on klubby_dev.activities to authenticated;
grant update(recording_source,elapsed_seconds,device,samples,hide_hr) on klubby_dev.activities to authenticated;
-- This exact suffix was written by the Health import, before metadata was synced.
update klubby_dev.activities set recording_source='wearable'
 where recording_source is null and source='manual' and title like '% (smartwatch)';

create table if not exists klubby_dev.club_kas_entries (
 id uuid primary key default gen_random_uuid(),
 club_id uuid not null references klubby_dev.clubs(id) on delete cascade,
 user_id uuid not null default auth.uid() references klubby_dev.users(id),
 title varchar(150) not null,
 amount integer not null check(amount > 0),
 is_income boolean not null default true,
 counts boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists club_kas_club on klubby_dev.club_kas_entries(club_id,created_at desc);
alter table klubby_dev.club_kas_entries enable row level security;
revoke all on klubby_dev.club_kas_entries from public,anon,authenticated;
grant select on klubby_dev.club_kas_entries to authenticated;
grant insert(club_id,user_id,title,amount,is_income,counts) on klubby_dev.club_kas_entries to authenticated;
drop policy if exists club_kas_read on klubby_dev.club_kas_entries;
create policy club_kas_read on klubby_dev.club_kas_entries for select to authenticated
 using (klubby_dev.is_club_member(club_id));
drop policy if exists club_kas_write on klubby_dev.club_kas_entries;
create policy club_kas_write on klubby_dev.club_kas_entries for insert to authenticated
 with check (user_id=(select auth.uid()) and amount > 0 and klubby_dev.is_club_member(club_id,true));

alter table klubby_dev.club_messages add column if not exists announcement boolean not null default false;
grant insert(announcement) on klubby_dev.club_messages to authenticated;
drop policy if exists write_chat on klubby_dev.club_messages;
create policy write_chat on klubby_dev.club_messages for insert to authenticated
 with check (user_id=(select auth.uid()) and klubby_dev.is_club_member(club_id)
 and (not announcement or klubby_dev.is_club_member(club_id,true)));

-- Membership mutations need protected access: clients have no direct UPDATE grant.
create or replace function klubby_internal.klubby_dev_list_club_members(p_club_id uuid,p_pending boolean)
 returns table(user_id uuid,name text,role text,status text,owner boolean)
 language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null or not klubby_dev.is_club_member(p_club_id,p_pending) then
  raise sqlstate 'PT403' using message='Daftar anggota hanya untuk anggota klub; permintaan hanya untuk admin.';
 end if;
 return query select m.user_id,coalesce(nullif(u.name,''),nullif(u.username,''),'Anggota')::text,m.role,m.status,c.created_by=m.user_id
 from klubby_dev.club_members m join klubby_dev.users u on u.id=m.user_id join klubby_dev.clubs c on c.id=m.club_id
 where m.club_id=p_club_id and m.status=case when p_pending then 'pending' else 'active' end
 order by (c.created_by=m.user_id) desc,(m.role='admin') desc,u.name,m.user_id;
end; $fn$;
revoke all on function klubby_internal.klubby_dev_list_club_members(uuid,boolean) from public,anon;
grant execute on function klubby_internal.klubby_dev_list_club_members(uuid,boolean) to authenticated;
create or replace function klubby_dev.list_club_members(p_club_id uuid,p_pending boolean default false)
 returns table(user_id uuid,name text,role text,status text,owner boolean)
 language sql stable security invoker set search_path='' as $fn$
 select * from klubby_internal.klubby_dev_list_club_members(p_club_id,p_pending);
$fn$;
revoke all on function klubby_dev.list_club_members(uuid,boolean) from public,anon;
grant execute on function klubby_dev.list_club_members(uuid,boolean) to authenticated;

create or replace function klubby_internal.klubby_dev_set_club_member_admin(p_club_id uuid,p_user_id uuid,p_admin boolean)
 returns void language plpgsql security definer set search_path='' as $fn$
declare creator uuid;
begin
 if p_admin is null then raise sqlstate 'PT400' using message='Peran harus diisi.'; end if;
 select created_by into creator from klubby_dev.clubs where id=p_club_id for update;
 if auth.uid() is null or not klubby_dev.is_club_member(p_club_id,true) then
  raise sqlstate 'PT403' using message='Hanya admin klub yang bisa mengubah peran anggota.';
 end if;
 if not p_admin and (p_user_id=creator or (select count(*) from klubby_dev.club_members where club_id=p_club_id and status='active' and role='admin') <= 1) then
  raise sqlstate 'PT409' using message='Pemilik dan admin terakhir harus tetap menjadi admin.';
 end if;
 update klubby_dev.club_members set role=case when p_admin then 'admin' else 'member' end
 where club_id=p_club_id and user_id=p_user_id and status='active';
 if not found then raise sqlstate 'PT404' using message='Anggota tidak ditemukan.'; end if;
end; $fn$;
revoke all on function klubby_internal.klubby_dev_set_club_member_admin(uuid,uuid,boolean) from public,anon;
grant execute on function klubby_internal.klubby_dev_set_club_member_admin(uuid,uuid,boolean) to authenticated;
create or replace function klubby_dev.set_club_member_admin(p_club_id uuid,p_user_id uuid,p_admin boolean)
 returns void language sql security invoker set search_path='' as $fn$
 select klubby_internal.klubby_dev_set_club_member_admin(p_club_id,p_user_id,p_admin);
$fn$;
revoke all on function klubby_dev.set_club_member_admin(uuid,uuid,boolean) from public,anon;
grant execute on function klubby_dev.set_club_member_admin(uuid,uuid,boolean) to authenticated;

create or replace function klubby_internal.klubby_dev_review_club_request(p_club_id uuid,p_user_id uuid,p_approve boolean)
 returns void language plpgsql security definer set search_path='' as $fn$
begin
 perform 1 from klubby_dev.clubs where id=p_club_id for update;
 if auth.uid() is null or not klubby_dev.is_club_member(p_club_id,true) then
  raise sqlstate 'PT403' using message='Hanya admin klub yang bisa meninjau permintaan.';
 end if;
 if p_approve then
  update klubby_dev.club_members set status='active' where club_id=p_club_id and user_id=p_user_id and status='pending';
 else
  delete from klubby_dev.club_members where club_id=p_club_id and user_id=p_user_id and status='pending';
 end if;
 if not found then raise sqlstate 'PT409' using message='Permintaan sudah ditinjau. Muat ulang daftar.'; end if;
end; $fn$;
revoke all on function klubby_internal.klubby_dev_review_club_request(uuid,uuid,boolean) from public,anon;
grant execute on function klubby_internal.klubby_dev_review_club_request(uuid,uuid,boolean) to authenticated;
create or replace function klubby_dev.review_club_request(p_club_id uuid,p_user_id uuid,p_approve boolean)
 returns void language sql security invoker set search_path='' as $fn$
 select klubby_internal.klubby_dev_review_club_request(p_club_id,p_user_id,p_approve);
$fn$;
revoke all on function klubby_dev.review_club_request(uuid,uuid,boolean) from public,anon;
grant execute on function klubby_dev.review_club_request(uuid,uuid,boolean) to authenticated;

notify pgrst,'reload schema';
