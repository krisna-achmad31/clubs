# Klubby audit: FEED tab (read-only)

Scope: `lib/features/feed/**`, post detail (`/post/:id`), notifications (`/notifications`), and the links from the feed to activity, profile, clubs and sessions.
All paths below are relative to `D:\Bismillah jadi kaya dunia akhirat\clubus\clubs\mobile\lib\`.
I read the code to confirm every finding. Each one is labelled **BUG** (wrong behaviour) or **MOCK** (demo seed data that is inconsistent by design, but a tester will still notice it).

---

## 1. Missing flows / navigation

| # | Sev | Type | Where | What happens | What should happen |
|---|---|---|---|---|---|
| 1.1 | **High** | BUG | `features/feed/presentation/pages/feed_pages.dart:569-578` (`_showPostMenu`) | The "•••" menu shows the same options on **your own post**: "Bisukan Budi", "Laporkan", "Sembunyikan". `cubit.mute(post.author)` adds your own name to `_muted` (`feed_repository_impl.dart:370`). After that, every post you make disappears from KOMUNITAS, PUBLIK and the club feed (`feed_repository_impl.dart:325, 338`). No screen lets you unmute or unhide (`_muted` and `_hidden` are only written, never cleared). The only fix is to restart the app. | When `post.mine` is true, show "Lihat aktivitas / Hapus / Ubah privasi" instead of Mute and Report. Add an "Unmute" or "Hidden posts" list. |
| 1.2 | Med | BUG | `feed_pages.dart:262-267, 987, 1011` (`_openCommenter`) | Tapping your **own comment** avatar or name opens `showUserSheet` showing "Anggota Klubby" with an **IKUTI** button, so you can "follow" yourself. `c.mine` is never checked. (`_openAuthor` handles `post.mine` at line 239, but this function does not.) | If `c.mine`, run `context.go(R.profile)`, the same as `_openAuthor`. |
| 1.3 | Med | BUG (disconnected) | `core/widgets/sheets.dart:48, 78-84` (`showUserSheet`, opened from feed author/commenter) | The IKUTI / DIIKUTI button only flips a local `var following` and shows a toast. Nothing is saved. When you reopen the sheet it says IKUTI again. It also does not change who appears in KOMUNITAS (`FeedPost.circle` is static). | Save the follow state (ProfileRepository or a follow repo) and use it in the KOMUNITAS filter. |
| 1.4 | Med | BUG | `feed_pages.dart:271, 535` | "Bagikan" / "Salin tautan" create `https://klubby.id/p/<id>`. The router has no `/p/:id` route (only `/post/:id`, `core/router/app_router.dart:107`). The Android manifest has no https intent-filter (only `klubby://`, `android/app/src/main/AndroidManifest.xml:78-83`). For your own posts the id is `activity:act_123…`, so the link contains a raw `:`. The link cannot open the app. Private activities ("Pengikut"/"Hanya Klub") can also be shared with no warning. | Add a `/p/:id` route (or share `/post/`), add App Links, URL-encode the id, and hide or warn on Share for non-public posts. |
| 1.5 | Med | BUG / MOCK | `features/feed/data/feed_repository_impl.dart:264-273` + `features/session/presentation/pages/session_flow_pages.dart:549-551` | The static notification "Slot mabar terbuka" opens `R.slot('padel-pagi')`. `SlotPage.initState` calls `SessionsCubit.promote()`, so **tapping a fake notification changes real RSVP state** (waiting → pendingPayment with a 30-minute hold, `sessions_cubit.dart:167-180`). The notification never goes away, so a tester can trigger this at any time. | Only create this notification when a promote event actually happens, or have the tap open SessionPage instead of SlotPage. |
| 1.6 | Low | MOCK (hardcoded id) | `feed_repository_impl.dart:281` | "Pembayaran QRIS berhasil" always opens `R.ticket('rabu-malam')`, even if you cancelled that RSVP or never paid. | Generate it from the real payment event and use the real session id. |
| 1.7 | Low | BUG | `feed_pages.dart:239-241` | Tapping your own avatar or name in Post Detail runs `context.go(R.profile)`, which clears the pushed stack. You cannot go back to the post you were reading. | Use `push` to the profile view, or accept this and document it. |
| 1.8 | Low | Missing | (no code) | No link from your feed post to your saved activity page (`/activity/:id`), and none back. `/activity/:id` shows no reactions or comments. One workout has two separate detail pages. | Add "Lihat detail aktivitas" on mine posts and "Lihat di feed" on SavedActivityDetailPage. |
| 1.9 | Low | UX | `feed_pages.dart:1041-1049` | "TANDAI DIBACA" always shows and is tappable, even with 0 unread. | Disable it when `unread == 0`. |
| 1.10 | Low | UX | `feed_pages.dart:76-86`, `feed_cubit.dart:8-13` | `FeedState` has no loading flag. On cold start the "Belum ada aktivitas di sini" mascot flashes before `load()` finishes. | Add `loading` and show a skeleton or spinner. |

Routes from the feed that I checked and found **OK**: `/post/:id`, `/notifications`, `/segment?id=tanjakan-senayan` (exists), `/goyang/invite`, `/record/gps` (pushed inside the RecorderCubit ShellRoute, works), `/streak/saved`, `/liga` (go), `R.stamps`/`R.challenges`/`R.shop` from MeTopStats. Post Detail "not found" falls back to "KEMBALI KE FEED" (`feed_pages.dart:713-720`), so there is no dead end. I found no `onTap: () {}` or TODO handlers in the feed files.

---

## 2. Disconnected features / stale data

| # | Sev | Type | Where | What happens | What should happen |
|---|---|---|---|---|---|
| 2.1 | **High** | BUG | `features/feed/domain/entities/feed_post.dart:193` (`props => [id, reactions, comments, activity, mine]`) + `feed_cubit.dart:57` + `feed_pages.dart:42-47` | When you **rename yourself**, the MeCubit listener calls `FeedCubit.load()`, and the repo rebuilds your posts with the new `author`/`initials` (`feed_repository_impl.dart:185-186`). But `FeedPost` equality ignores `author`, `initials`, `title`, `meta`, `stats`, `publik`. So the new `FeedState` equals the old one and bloc **skips the emit**. Your cards keep the old name until something else changes (a reaction, for example). Post Detail's `context.select` (`feed_pages.dart:703`) has the same problem. | Include every displayed field in `props` (or drop Equatable on FeedPost). |
| 2.2 | **High** | BUG / MOCK | `features/activity/data/activity_repository_impl.dart:40-53` (seed activity `gbk`, `published:false`, the user's own) + `feed_repository_impl.dart:69-114, 232-239` | Seed post **"Rian Saputra – Lari Pagi GBK"** has `activityId: 'gbk'`. `_syncActivities` attaches the **current user's** private activity `gbk` to Rian's post. Post Detail then shows the full `ActivityDataSections` of *your* run under Rian's name (`feed_pages.dart:908-909`, `owner:false`). The same run shows in your profile as "TERSIMPAN PRIBADI" (`activity_pages.dart:69`). The segment "Tanjakan Senayan · 4:12 · PR" on Rian's post is also "Kamu 4:12 PR" in the segment page (`league_repository_impl.dart:289`). Rian's seeded "SPLIT PER KM" section is hidden because `post.activity != null` (`feed_pages.dart:845`). | Either make this the user's own post (`mine:true`), or give Rian a separate activity object. A private activity must never show under another author. |
| 2.3 | Med | BUG | `feed_repository_impl.dart:322-323` + seed `circle` flags | KOMUNITAS = `p.mine \|\| p.circle`, and `circle` is hardcoded per seed post. It ignores `ClubsCubit` membership and follows. If you leave "Klub Hiu Jakarta", Dinda's post stays in KOMUNITAS. If you join PB Smash Ceria or follow Sisca, nothing new appears. The subtitle at `feed_pages.dart:68` promises "anggota klubmu". | Compute `circle` from ClubsCubit memberships and the (persisted) follow list. |
| 2.4 | Med | BUG | `features/profile/presentation/cubit/me_cubit.dart` (streak is only recomputed in `recordActivity`, ~line 161-217) + `feed_pages.dart:71-75, 177-184` | The streak banner shows the stored `streak` even after the user missed several days. Example: seed `streak:13`, last active 5 days ago, 0 Es Batu. The banner says "13 hari beruntun! · amankan hari ke-14", but the next activity sets streak to 1 (`streak_rules.dart` `nextStreak`: `missed > freezes → 1`). | Work out the "effective" streak when the app loads or the feed is built (gap > 1 + freezes → 0 / broken state). |
| 2.5 | Med | MOCK | `feed_repository_impl.dart:254-263` | The notification "Streak kamu dalam bahaya! … 4 jam lagi" is static and unread on every launch, even after you record today (the banner then says "Streak hari ini aman ✓"). The two contradict each other on the same screen. | Generate it from `MeCubit.lastActive`/the reminder hour, or hide it when `safeToday`. |
| 2.6 | Med | MOCK | `feed_repository_impl.dart:303-312`, `:293-302`, `:243-253`, `:284-292` | Notifications don't match real data. "Es Batu dipakai · Streak 14 hari" (seed streak is 13, no freeze used). "PB Smash Ceria #4 · kurang 240 poin" is not read from LeagueCubit. "Budi ngajak main!" comes from "Budi", and the default user is **Budi Santoso** (`profile_repository_impl.dart:33`). The "kudoz" notification "Dinda & 7 lainnya" points to **Dinda's own post**, which has 25 reactions, not to one of yours. | Build notifications from events, or at least make the seed text match the seed profile/league. |
| 2.7 | Med | BUG | `feed_pages.dart:703-707` vs `feed_cubit.dart:25-26` | Post Detail reads `details[id]` **first**, then `posts`. `FeedState.byId` does the opposite. `details` is only refreshed after react/comment (`_refresh`), not after the MeCubit-triggered `load()`. So a post cached in `details` (opened while it was not in the current list, e.g. from a club page while on PUBLIK) shows stale title, stats, author or privacy the next time you open it. | Use `state.byId(id)` (posts first), or refresh `details` inside `load()`. |
| 2.8 | Low | BUG | `feed_pages.dart:309` | The feed card's comment preview shows `comments.firstOrNull` (the oldest). A new comment you send never appears on the card, and there is no comment count, so the feed looks like your comment didn't save. | Show the latest comment plus "N komentar". |
| 2.9 | Low | BUG | `feed_pages.dart:684-686` | A comment stores `author: me.firstName` as a fixed string. After a rename, your old comments show the old name. A seed comment by another "Budi" (`feed_repository_impl.dart:99`) looks identical to yours. | Store `mine` plus a user id and resolve the name from MeCubit. |
| 2.10 | Low | BUG | `features/club/presentation/pages/club_pages.dart:438-442` + `feed_repository_impl.dart:331-341` | The club feed matches by club **name** string (`p.club == clubName \|\| p.meta.contains(clubName)`). If a club is renamed, or one club's name is a substring of another's, posts get lost or mixed. | Match on club id. |
| 2.11 | Low | Doc mismatch | `features/profile/presentation/widgets/me_top_stats.dart` (`showSportSwitcher` doc: "drives … feed") | The feed never filters by `activeSportId`. | Filter the feed, or fix the comment. |

---

## 3. Calculations / formatting

| # | Sev | Type | Where | What happens | What should happen |
|---|---|---|---|---|---|
| 3.1 | Med | BUG | `core/utils/format.dart` `Fmt.pace` | `s = (secPerKm % 60).round()` can be **60**. Example: 359.6 s/km gives `5'60"` instead of `6'00"`. This is used for your own posts' PACE (`feed_repository_impl.dart:211-214`). Splits use whole seconds, so they are safe. | Round the total seconds first: `t = secPerKm.round(); m = t ~/ 60; s = t % 60`. |
| 3.2 | Med | BUG | `feed_repository_impl.dart:210-215` | Your posts always show PACE as min/km, for every sport. A swim shows "PACE 19'05"" (the seed swim post uses `/100m`) and a ride shows min/km (the seed ride uses `KEC. km/j`). There is no unit suffix. Seed posts and your own posts are formatted differently. | Choose by sport: renang → /100m, sepeda → km/j, lari/jalan → /km. |
| 3.3 | Med | BUG | `feed_repository_impl.dart:216` + QR check-in (`activity_pages.dart:196-205`) + Goyang (`goyang_flow_pages.dart:551-558`) | QR check-in and Goyang activities are saved with `duration: Duration.zero`. Their feed cards show **"WAKTU 0:00"** as the only stat. A manual entry's `score` (e.g. "3-1") and `feel` never appear on the card. | Hide WAKTU when it is zero, and show SET/score for racket sports. |
| 3.4 | Low | BUG | `feed_repository_impl.dart:178-230` | Your posts are always put above every friend post, in repo insert order. A back-dated manual activity (`activity_result_pages.dart:45-60`, `start: _at`) jumps to the top, above today's friend posts. | Sort the whole feed by activity start time. |
| 3.5 | Low | MOCK | Seed `meta` strings (`feed_repository_impl.dart:24, 55, 76, 120, 140`) and notification `ago` (`:249-309`) | Times like "Hari ini 06.10", "Kemarin", "2m", "1j" are fixed strings with no timestamp. Your posts use an absolute `Fmt.dayDate` ("Sab, 7 Nov · 06.12"), so the feed mixes two time styles. In the notifications list, `n7 ago:'2h'` (2 days) sits under the header **KEMARIN** (`feed_pages.dart:1060-1065`). | Store a `DateTime` and format a relative time in one place. Group by real date. |
| 3.6 | Low | BUG (dead code) | `feed_repository_impl.dart:197-200` | `splits` is computed for your posts but never shown, because "SPLIT PER KM" only renders when `post.activity == null` (`feed_pages.dart:845`). ActivityDataSections shows its own splits. | Remove it. |
| 3.7 | Low | MOCK | `feed_repository_impl.dart:80, 360-363` + `core/widgets/osm_route_map.dart:85-97` | Rian's card has `hasRoute:true`, but `gbk` has no `samples` with lat/lng. The map shows "Koordinat GPS belum tersedia" on the second card of the default feed. | Seed real GPS samples or set `hasRoute:false`. |

Checked and **correct**: the split bar width formula `.55 + .45*(worst-s+1)/(worst-best+1)` (the denominator is never 0). `Fmt.pace` guards `km < .05`. `averagePace` guards distance or duration of 0. Reaction toggle adds or removes 1 and drops pills at 0 (`feed_post.dart:69-70`, `feed_repository_impl.dart:363`). The reaction total in detail (`fold`) is correct. The unread badge is computed from the same list the notifications page shows (`feed_cubit.dart:22`), so the badge and the list always agree. Seed numbers check out: Rian's 4 splits average 369.75 s ≈ 6'08". The swim 1.2 km / 38:12 works out to 3:11/100m (seed says 3:10, close enough).

---

## 4. Persistence (what survives an app restart)

| Data | Stored in | Survives restart? | Should it? |
|---|---|---|---|
| Your activities, and so your own feed posts | SharedPreferences `activities` | Yes | Yes |
| Reactions you give (any post, including on your own posts) | `FeedRepositoryImpl._posts` (memory) | **No** | Yes. **Med** |
| Comments / stickers you send | memory | **No** | Yes. **Med** |
| Hidden posts, reported posts | `_hidden` Set (memory) | **No**: hidden or reported posts come back | Yes. **Med** |
| Muted authors | `_muted` Set (memory) | **No** | Yes. **Med** (also the only way to undo 1.1) |
| Notification read state | `_notifs` list (memory) | **No**: badge is back to 4 every launch | Yes. **Med** |
| Follow (IKUTI) from the user sheet | local `var` in a StatefulBuilder | **No**, not even while the app is open | Yes. **Med** |
| KOMUNITAS/PUBLIK tab choice | `FeedState.publik` | No (resets to KOMUNITAS) | Fine |

---

## 5. Manual test cases (real device)

1. **Self-mute trap.** Record or save any activity → Feed → "•••" on your own card → "Bisukan <name>". *Expected:* the option is not there for your own posts. *Today:* all your posts disappear until the app restarts.
2. **Rename propagation.** Profile → change your name → go back to Feed. *Expected:* your cards show the new name right away. *Today:* the old name stays until you react to a post.
3. **Rian / GBK privacy.** Feed → open "Rian Saputra – Lari Pagi GBK". *Expected:* Rian's data only. *Today:* it shows your private seed run (`gbk`) with charts, and the same run is listed in your Profile as "TERSIMPAN PRIBADI".
4. **Pace format.** Record a run where pace lands near a whole minute (e.g. 1.00 km in 5:59.6, or use a manual entry "5 km" with duration 29:58). *Expected:* `6'00"` / `5'60"` never appears.
5. **Swim / ride units.** Manual entry: Renang "1,5 km", 30 min, and Sepeda "20 km", 45 min. *Expected:* /100m and km/j. *Today:* min/km.
6. **QR / Goyang zero duration.** Check in with a session QR → Feed. *Expected:* no "WAKTU 0:00".
7. **Reactions and comments persistence.** React 🔥 on Dinda's post and comment on Raka's → kill the app → reopen. *Expected:* both kept. *Today:* both lost.
8. **Card vs detail sync.** React on a card → open detail → remove the reaction → back. *Expected:* card count updates (this works). Then send a comment. *Expected:* the card shows it or a count (today it only shows the oldest comment).
9. **Notification badge.** Open Notifikasi → TANDAI DIBACA → back. *Expected:* badge hidden. Restart the app. *Expected:* still hidden. *Today:* 4 again.
10. **Streak notification vs banner.** Record any activity today → Feed. *Expected:* the banner says "Streak hari ini aman ✓" and there is no "Streak kamu dalam bahaya" notification. *Today:* both show.
11. **Slot notification side effect.** Notifikasi → "Slot mabar terbuka" → go back without paying → open the Padel Pagi session. *Expected:* nothing changed. *Today:* you are on pendingPayment with a 30-minute hold, which then expires.
12. **Share link.** "•••" → Salin tautan → paste into a browser or WhatsApp and tap it. *Expected:* the app opens that post. *Today:* `/p/…` is not routed.
13. **Self-follow.** Comment on any post → tap your own comment avatar. *Expected:* opens your Profile. *Today:* "Anggota Klubby" sheet with IKUTI.
14. **Follow persistence.** Tap Sisca's avatar → IKUTI → close → reopen. *Expected:* DIIKUTI, and Sisca's posts appear in KOMUNITAS.
15. **Club membership.** Leave "Klub Hiu Jakarta" → Feed KOMUNITAS. *Expected:* Dinda's club post gone (unless you follow her). *Today:* still there.
16. **Broken streak.** Set the device date 5 days ahead (0 Es Batu) → open Feed. *Expected:* streak broken or 0. *Today:* still "13 hari beruntun · amankan hari ke-14".
17. **Hide and report.** Hide one post, report another → pull to refresh → restart. *Expected:* both stay hidden, with some "undo"/"hidden posts" place to restore them.
18. **Back navigation.** Notifikasi → kudoz → Post detail → tap your own avatar (on your own post) → system back. Note where you land (today the stack is replaced by Profil).
