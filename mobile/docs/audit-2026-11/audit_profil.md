# Klubby – PROFIL tab audit (read-only)

Root: `D:\Bismillah jadi kaya dunia akhirat\clubus\clubs\mobile` (paths below are relative to it).
Date: 2026-11-07. Method: code reading only (no build/run). "Confirmed" = traced through code; "Mock" = intentional demo data, labelled in UI or comments.

---

## A. High severity

### H1. Gear mileage / play-hours never accumulate (dead feature) — Confirmed
- `lib/features/activity/presentation/pages/activity_pages.dart:935` stores `gearId` on the Activity, but **no code anywhere adds `km` or `hours` to a Gear** (`grep` for `km`/`hours` writes: only `GearCubit.resetKm`/`restrung` zero them, `lib/features/profile/presentation/cubit/gear_cubit.dart:78-82`). `GearCubit` has no `addUsage`.
- Effect: shoe wear bar (`profile_pages.dart:781-818`), "x km" subtitle (`:861`), racket "jam main" (`:833`) stay at whatever was typed when the gear was added. The 85% "Waktunya cari pengganti" warning can never trigger from real use.
- Should: on activity save (GPS/manual with distance), `GearCubit` adds `distanceKm` to the selected/default gear; racket gear adds `duration.inHours`. Manual entries also never get a gear (ManualPage passes no gearId).

### H2. Sign-out / "Hapus profil lokal" restores the demo user, and new accounts inherit Budi's progress — Confirmed (partly intentional demo, but contradicts product rules and UI copy)
- `MeCubit.signOut` (`me_cubit.dart:94-98`) clears prefs then `_repo.load()` → returns `ProfileRepositoryImpl.seed` (`profile_repository_impl.dart:92`): streak 13, XP 2120, 1250 Permata, saldo 35.000, 7 adopted animals with 132 sessions, joined 2 Mar 2026, followers 31.
- Onboarding then does `state.copyWith(...)` on that seed (`me_cubit.dart:115-141`) and `joined` is not overwritten, so the "new" user keeps all of it. Because `joined==2026-03-02 && stamps>=23`, `UserProfile.calendarHistory` (`user_profile.dart:112-149`) also injects Budi's **October legacy calendar** into the new user.
- Violates rule "adding a sport doesn't adopt; first verified session unlocks adoption": new user who picks only Renang already has Otto at 14 sessions (Juara).
- `AccountPage._confirmDelete` copy says streak/Geng "akan hilang permanen" (`profile_pages.dart:1127`) but the next screen shows streak 13 again.
- Also not reset on sign-out: `ActivityRepository` (`activity_repository_impl.dart` – no clear), so the previous user's activities still appear in Stempel calendar, week bars, month split, feed "mine" posts (author renamed to the new user via `feed_repository_impl.dart:171-186`). Gear *is* reset to empty (`profile_helpers.dart:1028`) → inconsistent.
- Should: sign-out/delete creates an empty `UserProfile` (joined = now, streak 0, adopted {}), clears activities/check-in flags/feed mine posts. Keep demo seed only for first-install demo mode, explicitly.

### H3. Streak never decays on read; "streak putus" state is unreachable — Confirmed
- Streak is only recomputed inside `recordActivity` (`me_cubit.dart:143-224`). `StreakRules.nextStreak` never returns 0 (`streak_rules.dart:43-56`). No code checks `lastActive` vs today when displaying.
- Effect: after 5 idle days with 1 Es Batu, Profil (`profile_helpers.dart:113`), top bar (`me_top_stats.dart:17`), league streak bonus (`league_pages.dart:50`, `streakDays: p.streak`) all still show the old streak (e.g. 13). `StreakSavedPage.broken = p.streak == 0 && p.bestStreak > 0` (`streak_calendar_pages.dart:23`) is therefore never true → "STREAK PUTUS / Mulai streak baru" UI is dead. Es Batu are only consumed lazily on the next activity, so the freeze counter also looks unspent.
- Should: a derived `effectiveStreak(today)` (0 if `missed > freezes`), applied on app resume/day change; use it for display and league bonus; consume freezes/mark frozen days at day rollover (or at least compute them for display).

### H4. Wearable / Health workouts never become activities — Confirmed
- `WearableCubit.sync` (`wearable_cubit.dart:173-196`) and watch `WatchWorkout` events (`:119-136`) only set `lastWorkout` for display on Devices page. Nothing saves an `Activity` or calls `recordActivity(source: ActivitySource.wearable)`; `ActivitySource.wearable` is never used.
- DevicesPage banner claims "Aktivitas dari jam & Health dihitung terverifikasi untuk liga klub" (`profile_pages.dart:1576-1578`) – false. Health is only used to enrich HR/cadence of a phone GPS recording (`activity_pages.dart:857-890`) and to mirror the workout back.
- Should: import (with de-dupe by start time) or change the copy. `autoImport` toggle exists but is unused (see M2).

---

## B. Medium severity

### M1. Settings toggles persisted but read by nothing — Confirmed
Written via `MeCubit.setSetting`, no reader anywhere in `lib/`:
| Key | Written at | Notes |
|---|---|---|
| `liveHr` | `profile_pages.dart:1567` | "Detak jantung live · Tampil saat rekam GPS" – recorder never checks it |
| `autoImport` | `profile_pages.dart:1553` | labelled "belum tersedia" (Low on its own) |
| `hideCal` | `profile_helpers.dart:1313` | calories never hidden |
| `beacon`, `beaconContacts` | `profile_helpers.dart:1314,1253` | recorder never offers location sharing |
| `zones`, `zoneArea`, `zoneRadius` | `profile_helpers.dart:1208-1211` | no route trimming (banner admits it) |
| `notif_mabar/chat/kudoz/liga/promo` | `profile_helpers.dart:1165` | feed notification list not filtered; `NotificationService.show` is never called at all |
| `notifications` (onboarding A8) | `setup_pages.dart:866` | no reminder scheduled after onboarding |
| `restringReminder_<id>` | `profile_pages.dart:846` | labelled "belum tersedia" |
- `hideHr` *is* used as the default for new recordings (`activity_pages.dart:812`) – OK. `visibility` used by recorder/manual – OK.

### M2. Streak reminder: shown ON but not scheduled; fires even when streak already safe — Confirmed
- Settings shows `reminder` toggle with `fallback: true` (`profile_helpers.dart:975`) but `scheduleStreakReminder` is only called when the user touches the toggle/time (`:852,979`, `:1168`). Onboarding opt-in (`setup_pages.dart:866`) never schedules. → A user who never opens Settings gets no reminder while UI says ON.
- `recordActivity` never cancels/reschedules, and the reminder repeats daily (`matchDateTimeComponents: time`, `notification_service.dart:52`) → "Streak kamu belum aman!" fires at 20:00 even after the user already trained today.
- `_guessLocation` (`notification_service.dart:62-75`) falls back to UTC for any offset other than +7/+8/+9 → reminder at 20:00 UTC (e.g. 03:00 WIB-traveller, or 21:00 for Europe users). Half-hour zones also break.
- Two toggles (`reminder` in Settings, `notif_streak` in NotifPrefs) control the same notification inconsistently: turning on Settings toggle schedules even if `notif_streak` is off.

### M3. Profile photo path not copied to app storage — Confirmed
- `AvatarPage._pick` saves the `image_picker` temp/cache path directly (`profile_pages.dart:179` → `MeCubit.setPhoto`). Android cache may be purged; iOS tmp/container path changes after update/reinstall → photo silently reverts to mascot (errorBuilder at `:88`). Should copy to `getApplicationDocumentsDirectory()` and store relative path.

### M4. Avatar / photo do not propagate outside Profil — Confirmed
- Feed "mine" posts use `profile.initials` + fixed `AppColors.primary` (`feed_repository_impl.dart:183-185`), not the chosen avatar/photo. Name does propagate (re-read on each feed sync), and club member list uses current name (`club_actions.dart:4`).
- Hardcoded "Budi": session host participant `'Budi (Host)'` (`session_repository_impl.dart:11`), club payout holder (`club_repository_impl.dart:38`), goyang invite text "Budi ngajak main" (`goyang_flow_pages.dart:416,460`), feed comment author. After renaming, these still say Budi. (Mock data, but visible as "me".)

### M5. Seeded demo activity re-dates itself to "today" on every launch until something is saved — Confirmed (mock artifact)
- `ActivityRepositoryImpl._items` seed `start: DateTime.now().copyWith(hour: 6, minute: 12)` (`activity_repository_impl.dart:45`). On a fresh install it puts a Lari stamp on today in Stempel/profile stamp row/week bars, while streak/lastActive (seed: yesterday) says today is not done → calendar and streak disagree. Before 06:12 it's a future activity. Gear seed `restrungAt: now-42d` (`gear_repository_impl.dart:32`) likewise shows "42 hari lalu" forever until gear is mutated (seed not persisted by `GearCubit.load`).

### M6. Recording across midnight splits stamp and streak days — Confirmed
- GPS save: `recordActivity(stampAt: start)` but streak uses `at` = `DateTime.now()` (`activity_pages.dart:951-957`, `me_cubit.dart:152`). Start 23:40, save 00:20 → stamp on day D, streak/lastActive credited to D+1. Calendar shows D+1 empty but streak counted it; D may be counted twice. Should use one canonical date (start) for both, consistent with manual entries.

### M7. Counts disagree across Profil — Confirmed (partly mock)
- "`${p.stamps}` sesi tercatat" (`profile_helpers.dart:228`) = number of recordActivity calls incl. manual (seed 23); Geng shows per-animal verified totals (seed 132); "100 sesi" badge uses `activities.length` from ActivityRepository (`streak_calendar_pages.dart:566`); month split uses saved activities only. Three different "session" numbers on the same tab. Should define one source (ActivityRepository + legacy offset).

---

## C. Low severity

- L1. DST/local-midnight math: `_day(today).difference(_day(lastActive)).inDays` (`streak_rules.dart:50`) and `_WeekBars` (`profile_helpers.dart:395`) use local `DateTime` differences; on a 23-hour DST day `inDays` = 0 → consecutive day treated as same day (streak not incremented). Indonesia has no DST, but devices in DST zones are affected. Use `DateUtils.dateOnly` + UTC dates or day-number arithmetic. Timezone change while travelling can also shift `lastActive` day (stored without offset, `user_profile.dart:297`).
- L2. `R.rating` and `R.gear` standalone routes (`app_router.dart:187-188`) are registered but never pushed (only embedded tabs) – dead routes.
- L3. Rating tab is fully synthetic (hash of sport id, `profile_pages.dart:336-352`) – labelled "contoh"; no averaging exists to verify. Mock.
- L4. Followers/Following lists are 3 hardcoded names (`profile_helpers.dart:241`); `setFollowing` only changes the counter. Mock, labelled.
- L5. `WearableState.copyWith` cannot clear `lastWorkout`/`bpm` (null-coalescing, `wearable_cubit.dart:63-64`) → after a sync returning no workouts, previous workout is still displayed. `sync` takes `list.last` assuming ascending order. `lastSync`, Strava state not persisted across restart.
- L6. `Gear` equality excludes `kind`, `sportId`, `limitKm` (`gear.dart:105-113`); `copyWith` can't change `limitKm`/`sportId` and there is no UI to edit the km limit. Restoring a retired ex-default gear (`gear_cubit.dart:56-58`) doesn't make it default when no default remains for that sport → recorder auto-pick finds nothing.
- L7. `Sports.byId` silently falls back to Badminton for unknown ids (`sport.dart:147`) — a stale/removed sport id in `verifiedSportSessions` or `sports` is attributed to Ciko.
- L8. Feed notification "Es Batu dipakai · Streak 14 hari tetap aman" is hardcoded (`feed_repository_impl.dart:303-311`) while seed streak is 13. Mock.
- L9. Challenges progress values are hardcoded (`streak_calendar_pages.dart:631+`). Mock.
- L10. `MeCubit._set` fires `_repo.save` without awaiting/handling errors (`me_cubit.dart:35-38`) – write failure is silent.
- L11. `StreakRules.apply` evolution uses `Stage.forStreak(sessions)` where 0 sessions maps to Pemula (orElse) – not a bug for thresholds, but the naming "Streak" vs sessions is confusing; thresholds 1/3/7/14/30 are correct (`mascot.dart:220-224`) and family aggregation via `adopted[animal]` is correct.

---

## D. Verified correct
- Evolution thresholds 1/3/7/14/30 and family aggregation: `adopted[animal]` incremented once per verified session for the sport's animal (`me_cubit.dart:190-193`); per-sport breakdown in `verifiedSportSessions`. Manual (`ActivitySource.manual`) does not increment adoption/evolution but does keep streak (`streak_rules.dart:71-80`). Adding a sport only changes `sports` (`me_cubit.dart:61-66`). Matches rules.
- QR check-in uses the scanned session's `sportId` (`activity_pages.dart:196-207`), de-duped via `checkin_<id>` flag.
- Es Batu bridging: `missed <= freezes` keeps streak, consumed count recorded, frozen days written to stampHistory (`me_cubit.dart:176-189`); earn 1 per multiple of 7 capped at `maxFreezes` – logic correct (only lazily applied, see H3).
- Stamp calendar: unique active days per month (map by day, frozen excluded, `streak_calendar_pages.dart:321-336`); month nav handles Jan→Dec year rollover via `DateTime(y, m-1)`; `DateUtils.getDaysInMonth` handles leap years; future months blocked; query `?year&month` validated (`app_router.dart:168-176`).
- Manual backdate: streak date = max(lastActive, chosen time), stamp on chosen day (`activity_result_pages.dart:65-71`); range limited to last 7 days.
- Profile persistence: whole `UserProfile` JSON in SharedPreferences (`profile_repository_impl.dart:143-147`), including settings & stampHistory; gear JSON (`gear_repository_impl.dart:54`); goyang settings separate prefs keys; activities persisted (`activity_repository_impl.dart:31-37`).
- Profile top stats: streak/XP/Es Batu/Permata from MeCubit; stamp row/week bars/month split from ActivityRepository + stampHistory (re-fetched when stamps/xp/lastActive change). No clubs-count/km totals exist on Profil.

## E. Test gaps (test/)
Existing: `test/domain/streak_rules_test.dart`, `stamp_history_recovery_test.dart`, `verified_sport_sessions_test.dart`, `test/widget/geng_flows_test.dart`, `stamp_calendar_flows_test.dart`, `test/cubit/gear_and_reactions_test.dart`.
Missing: DST day / year boundary (Dec 31→Jan 1) / leap day for `nextStreak`; freeze earned at 7/14 and cap at `maxFreezes`; stale-streak display; sign-out → clean profile & activities; gear km accumulation after save; recording across midnight; settings keys actually consumed (liveHr, hideCal, notif_*); reminder scheduling on onboarding and after activity; wearable import; avatar photo persistence.

---

## F. Manual test cases (real device)

1. **Gear mileage** – Profil › Gear: add shoe "Test" for Lari, 0 km, limit 100. Record a GPS run ≥1 km with that gear. Expected: shoe shows ≈1 km. Actual (bug H1): stays 0 km.
2. **Sign-out reset** – Settings › Keluar › confirm, complete onboarding as "Tester" with only Renang. Expected: streak 0, XP 0, 0/18 hewan, empty calendar, joined = this month. Actual (H2): streak 13, 7 animals, Oktober stamps, "Gabung Mar 2026", old activities visible.
3. **Hapus profil lokal** – Settings › Akun › Hapus profil lokal. Expected per copy: streak/Geng gone. Check same as #2.
4. **Stale streak** – note streak N; set device date +3 days (or wait); open app without recording. Expected: streak shows 0 (or N if Es Batu covers) and Streak page shows "STREAK PUTUS". Actual (H3): still N; league "streak N hari" unchanged.
5. **Es Batu bridging** – with 1 Es Batu, skip exactly 1 day, then record. Expected: streak +1, Es Batu −1, skipped day shows 🧊 in Stempel.
6. **Freeze milestone** – reach streak 7 with Es Batu < 2. Expected: +1 Es Batu (cap 2).
7. **Evolution** – new animal: record 1 manual activity in new sport → Geng still "Belum diadopsi". Then 1 QR/GPS verified → adopted Pemula; 3rd verified → Gesit; check sessions across two sports of same family (e.g. Lari + Trail) both count toward Kiki.
8. **QR sport** – set active sport Badminton, scan a Padel session QR. Expected: stamp/evolution go to Padel/Pandu, not Ciko. Scan same QR again → "Sesi ini sudah kamu check-in".
9. **Midnight recording** – start GPS at 23:50, finish 00:10. Expected: stamp and streak on the same day. Check Stempel for both days (M6).
10. **Stamp calendar month** – navigate back to previous year (Jan → Dec); check days count = unique active days (two activities same day count once); Feb in leap year 2028 shows 29 days (change device date if needed).
11. **Reminder** – fresh onboarding with notifications allowed; do not open Settings. Expected: reminder at 20:00. Actual (M2): none. Then enable reminder, record an activity at 19:00 → reminder should not fire at 20:00 (it does).
12. **Privacy toggles** – Privasi: turn ON "Sembunyikan kalori" and "Tawarkan berbagi lokasi", Devices: OFF "Detak jantung live"; record GPS with watch/HR. Expected: no calories, beacon offer shown, no live HR. Actual: no effect (M1).
13. **Avatar photo persistence** – pick gallery photo, Save, force-stop, clear app cache (Android Settings › Storage › Clear cache), reopen. Expected: photo stays. Likely reverts (M3). Also check feed post avatar after change (M4).
14. **Rename** – Akun: change name to "Rina Test". Check Feed own posts author, club member list, mabar participant list where you are host ("Budi (Host)" remains), league table "me" row.
15. **Health** – connect Health Connect, do a workout in Samsung Health/Google Fit, tap SINKRON. Expected per banner: activity appears in Stempel & counts verified. Actual (H4): only "Aktivitas terakhir" text on Devices page.
16. **Persistence** – after #5–#8, force-stop and relaunch: streak, Es Batu, Geng counts, calendar stamps, gear list, settings toggles must be unchanged.
