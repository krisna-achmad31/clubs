-- Source fixture for scripts/build-shared-dev.mjs. Do not run on hosted Prod.
begin;

insert into auth.users(id) values ('da5e0000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

update public.users set name='Budi (Host)', username='fixture_budi'
where id='da5e0000-0000-4000-8000-000000000001';

insert into public.clubs (id, created_by, name, sport_id, initials, emoji, privacy, schedule, note, pinned_note)
values
 ('da5e0000-0000-4000-8000-000000000101','da5e0000-0000-4000-8000-000000000001','PB Smash Ceria','badminton','SC','🏸','publik','Rab & Sab',null,'Rabu ini pakai lapangan 3–4 ya. Kok disediakan klub.'),
 ('da5e0000-0000-4000-8000-000000000102','da5e0000-0000-4000-8000-000000000001','Padel Pagi Senopati','padel','PP','🎾','publik','Sab 07.00','slot tersedia',null),
 ('da5e0000-0000-4000-8000-000000000103','da5e0000-0000-4000-8000-000000000001','Futsal Kebayoran FC','futsal','KF','⚽','persetujuan',null,null,null),
 ('da5e0000-0000-4000-8000-000000000104','da5e0000-0000-4000-8000-000000000001','Klub Hiu Jakarta','renang','HJ','🦈','publik',null,null,null),
 ('da5e0000-0000-4000-8000-000000000105','da5e0000-0000-4000-8000-000000000001','Klub Lari Santai GBK','lari','LG','🏃','publik',null,null,null)
on conflict (id) do nothing;

with seed(id,title,venue,court,fee,slots,start_shift,duration,club_id,sport_id,is_recurring) as (
  values
    ('da5e0000-0000-4000-8000-000000000201'::uuid,'Mabar Rabu Malam','GOR Mahakam','Lap 2',35000,12,interval '3 days',interval '3 hours','da5e0000-0000-4000-8000-000000000101'::uuid,'badminton',true),
    ('da5e0000-0000-4000-8000-000000000202'::uuid,'Mabar Sabtu Pagi','GOR Bulungan','Lap 1',30000,16,interval '6 days',interval '3 hours','da5e0000-0000-4000-8000-000000000101'::uuid,'badminton',false),
    ('da5e0000-0000-4000-8000-000000000203'::uuid,'Americano Bulanan','GOR Mahakam',null,50000,16,interval '7 days',interval '4 hours','da5e0000-0000-4000-8000-000000000101'::uuid,'badminton',false),
    ('da5e0000-0000-4000-8000-000000000204'::uuid,'Padel Pagi','Senopati Padel',null,75000,8,interval '8 days',interval '2 hours','da5e0000-0000-4000-8000-000000000102'::uuid,'padel',false)
)
insert into public.mabar_sessions(id,host_id,club_id,title,sport_id,starts_at,ends_at,deadline_at,venue,court,fee,slots,recurring)
select id,'da5e0000-0000-4000-8000-000000000001',club_id,
  title,sport_id,now()+start_shift,now()+start_shift+duration,now()+start_shift-interval '1 day',
  venue,court,fee,slots,is_recurring
from seed
on conflict (id) do nothing;

commit;
