// Run with NODE_PATH pointing to an installation of @electric-sql/pglite.
// All fixtures and migrations run in memory. No remote database is contacted.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const { PGlite } = createRequire(import.meta.url)('@electric-sql/pglite');
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001';
const member = '00000000-0000-0000-0000-000000000002';
const outsider = '00000000-0000-0000-0000-000000000003';
const club = '00000000-0000-0000-0000-000000000011';
let checks = 0;
async function expectDenied(sql, code) {
  await assert.rejects(db.query(sql), error => error.code === code);
  checks++;
}
try {
  await db.exec(`
    create role authenticated;
    create role anon;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid;
    $$;
    grant usage on schema auth to authenticated,anon;
    create schema klubby_dev;
    grant usage on schema public,klubby_dev to authenticated;
  `);
  for (const schema of ['public', 'klubby_dev']) {
    await db.exec(`
      create table ${schema}.users(id uuid primary key,name text,username text);
      create table ${schema}.clubs(id uuid primary key,created_by uuid,privacy text);
      create table ${schema}.club_members(club_id uuid,user_id uuid,role text,status text,
        primary key(club_id,user_id));
      create table ${schema}.activities(id uuid primary key default gen_random_uuid(),
        user_id uuid default auth.uid(),source text default 'manual',title text,
        verified_at timestamptz,duration_seconds int);
      create table ${schema}.club_messages(id uuid primary key default gen_random_uuid(),
        club_id uuid,user_id uuid,body text,sticker boolean default false);
      alter table ${schema}.club_messages enable row level security;
      grant select on ${schema}.club_messages,${schema}.activities to authenticated;
      grant insert(club_id,user_id,body,sticker) on ${schema}.club_messages to authenticated;
      grant insert(user_id,title,duration_seconds) on ${schema}.activities to authenticated;
      create function ${schema}.is_club_member(p_club_id uuid,p_admin boolean default false)
        returns boolean language sql stable security definer set search_path='' as $$
        select exists(select 1 from ${schema}.club_members where club_id=p_club_id
          and user_id=auth.uid() and status='active' and (not p_admin or role='admin'));
      $$;
      insert into ${schema}.users values
        ('${owner}','Pemilik','pemilik'),('${member}','Anggota','anggota'),('${outsider}','Pemohon','pemohon');
      insert into ${schema}.clubs values('${club}','${owner}','persetujuan');
      insert into ${schema}.club_members values
        ('${club}','${owner}','admin','active'),('${club}','${member}','member','active'),
        ('${club}','${outsider}','member','pending');
      insert into ${schema}.activities(title,duration_seconds) values('Jalan Kaki (smartwatch)',60);
    `);
  }
  await db.exec(readFileSync(new URL('../review/club_management_all_schemas.sql', import.meta.url), 'utf8'));
  for (const schema of ['public', 'klubby_dev']) {
    const restored = (await db.query(`select source,recording_source,verified_at from ${schema}.activities`)).rows[0];
    assert.deepEqual(restored, { source: 'manual', recording_source: 'wearable', verified_at: null });
    checks++;
    await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${member}',false);`);
    assert.equal((await db.query(`select * from ${schema}.list_club_members('${club}',false)`)).rows.length, 2);
    checks++;
    await expectDenied(`select * from ${schema}.list_club_members('${club}',true)`, 'PT403');
    await expectDenied(`select ${schema}.set_club_member_admin('${club}','${member}',true)`, 'PT403');
    await expectDenied(`select ${schema}.review_club_request('${club}','${outsider}',true)`, 'PT403');
    await expectDenied(`insert into ${schema}.club_kas_entries(club_id,user_id,title,amount) values('${club}','${member}','Iuran',10000)`, '42501');
    await expectDenied(`insert into ${schema}.club_messages(club_id,user_id,body,announcement) values('${club}','${member}','Pengumuman',true)`, '42501');
    await db.query(`insert into ${schema}.club_messages(club_id,user_id,body) values('${club}','${member}','Pesan anggota')`);
    checks++;
    await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false);`);
    assert.equal((await db.query(`select * from ${schema}.list_club_members('${club}',true)`)).rows.length, 1);
    checks++;
    await db.query(`select ${schema}.review_club_request('${club}','${outsider}',false)`);
    assert.equal((await db.query(`select * from ${schema}.list_club_members('${club}',true)`)).rows.length, 0);
    checks++;
    await db.exec(`reset role; insert into ${schema}.club_members values('${club}','${outsider}','member','pending'); set role authenticated;`);
    await db.query(`select ${schema}.review_club_request('${club}','${outsider}',true)`);
    assert.equal((await db.query(`select * from ${schema}.list_club_members('${club}',false)`)).rows.length, 3);
    checks++;
    await db.query(`select ${schema}.set_club_member_admin('${club}','${member}',true)`);
    await db.exec(`select set_config('request.jwt.claim.sub','${member}',false);`);
    await db.query(`insert into ${schema}.club_kas_entries(club_id,user_id,title,amount) values('${club}','${member}','Iuran',10000)`);
    await db.query(`insert into ${schema}.club_messages(club_id,user_id,body,announcement) values('${club}','${member}','Jadwal baru',true)`);
    checks += 2;
    await expectDenied(`select ${schema}.set_club_member_admin('${club}','${owner}',false)`, 'PT409');
    await expectDenied(`select ${schema}.set_club_member_admin('${club}','${owner}',null)`, 'PT400');
    await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false);`);
    await db.query(`select ${schema}.set_club_member_admin('${club}','${member}',false)`);
    await db.exec(`select set_config('request.jwt.claim.sub','${member}',false);`);
    await expectDenied(`select ${schema}.set_club_member_admin('${club}','${outsider}',true)`, 'PT403');
    assert.equal((await db.query(`select * from ${schema}.club_kas_entries`)).rows.length, 1);
    checks++;
    await expectDenied(`insert into ${schema}.activities(user_id,title,duration_seconds,source) values('${member}','Palsu',60,'gps')`, '42501');
    await db.exec(`select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000099',false);`);
    await expectDenied(`select * from ${schema}.list_club_members('${club}',false)`, 'PT403');
    assert.equal((await db.query(`select * from ${schema}.club_kas_entries`)).rows.length, 0);
    checks++;
    await db.exec('reset role;');
  }
  console.log(`${checks} local PostgreSQL checks passed across public and klubby_dev.`);
} finally {
  await db.close();
}
