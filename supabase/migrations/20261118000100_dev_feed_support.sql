-- Repair missing Dev feed dependencies without changing public tables.
create table if not exists klubby_dev.activity_reactions (
  activity_id uuid not null references klubby_dev.activities(id) on delete cascade,
  user_id uuid not null default auth.uid() references klubby_dev.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (activity_id, user_id, emoji)
);
alter table klubby_dev.activity_reactions enable row level security;
revoke all on klubby_dev.activity_reactions from public, anon, authenticated;
grant select, insert, delete on klubby_dev.activity_reactions to authenticated;
drop policy if exists reactions_read on klubby_dev.activity_reactions;
create policy reactions_read on klubby_dev.activity_reactions for select to authenticated using (exists (select 1 from klubby_dev.activities a where a.id = activity_id));
drop policy if exists reactions_insert on klubby_dev.activity_reactions;
create policy reactions_insert on klubby_dev.activity_reactions for insert to authenticated with check (user_id = (select auth.uid()) and exists (select 1 from klubby_dev.activities a where a.id = activity_id));
drop policy if exists reactions_delete on klubby_dev.activity_reactions;
create policy reactions_delete on klubby_dev.activity_reactions for delete to authenticated using (user_id = (select auth.uid()));

create table if not exists klubby_dev.activity_comments (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references klubby_dev.activities(id) on delete cascade,
  user_id uuid not null default auth.uid() references klubby_dev.users(id) on delete cascade,
  author_name text not null,
  author_emoji text not null default '🐰',
  body text not null check (length(btrim(body)) between 1 and 1000),
  sticker boolean not null default false,
  sticker_bg bigint,
  sticker_fg bigint,
  created_at timestamptz not null default now()
);
create index if not exists activity_comments_idx on klubby_dev.activity_comments(activity_id, created_at);
alter table klubby_dev.activity_comments enable row level security;
revoke all on klubby_dev.activity_comments from public, anon, authenticated;
grant select, insert on klubby_dev.activity_comments to authenticated;
drop policy if exists comments_read on klubby_dev.activity_comments;
create policy comments_read on klubby_dev.activity_comments for select to authenticated using (exists (select 1 from klubby_dev.activities a where a.id = activity_id));
drop policy if exists comments_insert on klubby_dev.activity_comments;
create policy comments_insert on klubby_dev.activity_comments for insert to authenticated with check (user_id = (select auth.uid()) and exists (select 1 from klubby_dev.activities a where a.id = activity_id));

create table if not exists klubby_dev.user_mutes (
  user_id uuid not null default auth.uid() references klubby_dev.users(id) on delete cascade,
  muted_author text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, muted_author)
);
alter table klubby_dev.user_mutes enable row level security;
revoke all on klubby_dev.user_mutes from public, anon, authenticated;
grant select, insert, delete on klubby_dev.user_mutes to authenticated;
drop policy if exists mutes_owner on klubby_dev.user_mutes;
create policy mutes_owner on klubby_dev.user_mutes for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

DO $$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['activity_reactions', 'activity_comments', 'user_mutes'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS dev_environment_gate ON klubby_dev.%I', target);
    EXECUTE format('CREATE POLICY dev_environment_gate ON klubby_dev.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((SELECT klubby_dev.has_dev_access())) WITH CHECK ((SELECT klubby_dev.has_dev_access()))', target);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON klubby_dev.%I TO service_role', target);
  END LOOP;
END;
$$;
NOTIFY pgrst, 'reload schema';
