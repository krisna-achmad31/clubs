# Klubby audit: Record flow, Onboarding, Goyang, Shop/misc

Read-only audit. Root: `D:\Bismillah jadi kaya dunia akhirat\clubus\clubs\mobile\lib`. All paths below are relative to `lib/`.
Legend: **[BUG]** = confirmed defect by code reading. **[MOCK]** = intentional demo behavior (labelled in UI/docs), listed only where it breaks a product rule or confuses the data. Severity High / Med / Low.

---

## A. RECORD FLOW

### A1. Navigation / missing flows / dead ends

| # | Finding | Where | What happens | Should | Sev |
|---|---|---|---|---|---|
| A1.1 | [BUG] **Android back on Save page silently discards the finished recording** | `features/activity/presentation/pages/activity_pages.dart:796-1126` (no `PopScope`); stack built by `record_sheet.dart:30` push → `activity_pages.dart:533` pushReplacement → `:607` pushReplacement | Stack is `[tabs, save]`. System back / iOS swipe pops the page, the ShellRoute disposes `RecorderCubit`, and the entire GPS recording is lost without the "Buang aktivitas?" confirmation that the X button shows (`:968`). | Wrap Save page in `PopScope(canPop:false)` and route back to `_discard()`. | **High** |
| A1.2 | [BUG] In-progress recording is memory-only | `recorder_cubit.dart` (no persistence), `app_router.dart:260-268` | If the OS kills the app (low memory, crash, swipe-away), or anything calls `context.go(...)` while recording (e.g. a notification deep link), the recorder shell is disposed and the run is lost. The foreground-service notification text says "Rekaman tetap aman di HP walau layar mati" (`activity_pages.dart:678`). | Checkpoint `RecorderState` (samples, meters, elapsed, startedAt) to prefs/file every N seconds and offer "Lanjutkan rekaman?" on launch. | Med |
| A1.3 | [BUG] Done / Evolve reached with `context.go` have no back stack | `activity_pages.dart:959`, `activity_result_pages.dart:73`, `goyang_flow_pages.dart:561`; Evolve via `pushReplacement` `activity_result_pages.dart:248` | `go(R.done)` replaces the whole stack with `[done]`. Android back from Done/Evolve closes the app instead of returning to Feed. (QR path uses `pushReplacement` so it behaves differently: `[tabs, done]`.) | Use `PopScope` on Done/Evolve that does `go(R.feed)`, or reach Done via `go(R.feed)` + `push(R.done)`. | Med |
| A1.4 | [BUG] "Manual" fallback from GPS page loses the selected distance sport | `activity_pages.dart:490` (CATAT TANPA GPS), `:523-525` (MULAI when gpsDenied) → `activity_result_pages.dart:10` | User picks e.g. Sepeda on GPS Ready, GPS is off, taps MULAI → Manual page opens with `MeCubit.activeSportId` (e.g. Badminton), not Sepeda. Violates "GPS keeps the selected distance sport". | Pass `st.sportId` (query param / extra) to `R.manual` and use it as initial `_sport`. | Med |
| A1.5 | [BUG] MULAI blocks up to ~12 s with no feedback, beacon ON by default | `activity_pages.dart:527-529`, default `beacon = true` in `activity.dart:180`; `location_service.dart:69-73` (12 s timeout) | Tapping MULAI awaits `LocationService.current()` (re-runs permission check + one-shot fix) before `cubit.start()`. No spinner, button stays tappable (double-tap → `start()` twice, two `pushReplacement`). Then a share sheet pops over the recording screen every run. | Start recording immediately; fetch beacon point in background; guard double tap; consider default beacon OFF. | Med |
| A1.6 | [BUG] "GPS kuat" pill never updates live on Ready screen | `recorder_cubit.dart:34-48` | `prepare()` takes ONE `LocationAccuracy.medium` fix and sets `gpsStrong = accuracy < 30`. Medium fixes are often >30 m, so pill stays "Mencari GPS…" until user taps it. No stream runs before MULAI. | Subscribe to `track()` during ready phase (without accumulating) or poll until accuracy is good. | Low |
| A1.7 | [BUG] Voice/split toast re-fires on every pause/resume | `activity_pages.dart:603-613` | `listenWhen` triggers on phase change too; listener branch `value.voice && splits.isNotEmpty` repeats the last km toast when user pauses/resumes. | Only toast when `splits.length` grew. | Low |
| A1.8 | [BUG] QR scanner can freeze permanently | `activity_pages.dart:180-222` | `_busy` is reset only in the `CheckInException` branch. Any other error (e.g. `StateError('Activity could not be saved')` from `activity_repository_impl.dart:36`, or MeCubit throw) leaves `_busy = true`, no toast; scanner silently ignores all further codes. | `try/finally` reset + generic error toast. | Low |
| A1.9 | [MOCK→rule risk] QR check-in has no validation | `activity_repository_impl.dart:77-88`; UI banner `activity_pages.dart:315` | Any QR text `klubby://checkin/<existing-session-id>` = verified activity (+140 XP, +25 pts, evolution +1). `tooFar`/`notOpenYet` errors are never thrown (dead branches `activity_pages.dart:216-217`). No check the user joined the session. Acknowledged in UI. | Server validation (token rotation, geofence, time window, membership). | Med (acknowledged) |
| A1.10 | [BUG] No delete/edit of a saved activity | `ActivityRepository.discard` (`activity_repository_impl.dart:69`) has zero callers | User can't remove a wrong/duplicate activity; and if it were added, MeCubit XP/streak/adopted would not be reverted. | Add delete/edit flow with reward rollback. | Low |
| A1.11 | [BUG] Save catch-all can report failure after a successful save | `activity_pages.dart:960-964` | `catch (_)` wraps repository save AND `me.recordActivity`. If anything after `save()` throws, user sees "belum tersimpan", retries, and a duplicate activity (new `act_<ms>` id) is stored. | Separate try blocks; idempotent id generated once in `initState`. | Low |
| A1.12 | [BUG] Default title uses save time, not start time | `activity_pages.dart:820-831` | Run started 05:50, saved 11:05 → "Lari Siang". | Use `st.startedAt`. | Low |
| A1.13 | Watch "stop" outside recording | `recorder_cubit.dart:67-70, 238-249` | On GPS Ready (phase ready) a watch `stop` sets phase finished with `startedAt == null`; no listener on Ready page so nothing visible; harmless because `start()` resets. | Ignore `stop` unless recording/paused. | Low |

### A2. Sync after saving (GPS / manual / QR / Goyang)

| Target | GPS save `activity_pages.dart:840-966` | Manual `activity_result_pages.dart:32-80` | QR `activity_pages.dart:195-209` | Goyang Bareng `goyang_flow_pages.dart:545-566` |
|---|---|---|---|---|
| ActivityRepository (prefs) | yes | yes | yes | yes |
| Feed post | yes — FeedPage listens to MeCubit stamps/xp/lastActive (`feed_pages.dart:42-47`) and `FeedRepositoryImpl._syncActivities` builds posts from published activities | yes | yes (duration 0 → "WAKTU 0:00") | yes |
| MeCubit streak/xp/stamps | yes | yes | yes | yes |
| Evolution (`adopted`) only if verified | yes (`me_cubit.dart:190-193`) | correctly excluded | yes | excluded (manual) |
| League | via MeCubit settings keys (`me_cubit.dart:200-205` → `league_pages.dart:44-51`) | `manualIgnored` +1 | attendance +1 | manualIgnored +1 |
| GearCubit mileage | **NO** | n/a | n/a | n/a |

Findings:

| # | Finding | Where | Sev |
|---|---|---|---|
| A2.1 | [BUG] **Gear mileage never updated.** `gearId` is stored on the activity (`activity_pages.dart:935`) but `GearCubit` has no method to add km/hours and nothing reads `Activity.gearId` (grep: only 4 refs, all in Save page). Gear km stays at seed values (620/1240) forever. | `profile/presentation/cubit/gear_cubit.dart` | **High** (feature disconnected) |
| A2.2 | [BUG] **"+25 POIN KLUB" shown for GPS runs is not what League adds.** `StreakRules.apply` gives `clubPoints = 25` for every verified source (`streak_rules.dart:78`); Done page shows it (`activity_result_pages.dart:353-357`) and Story sums `verified × 25` (`activity_result_pages.dart:637-639`). League only adds `verifiedMinutes ~/ 60 × 10` for GPS (`league.dart:70`) and attendance×25 only for QR (`me_cubit.dart:202`). A 32-min GPS run → Done says +25, League adds **0**. | as listed | **High** (user-visible inconsistency) |
| A2.3 | [BUG] League minutes include pause time. GPS save passes `duration: end.difference(start)` (wall clock incl. pauses, `activity_pages.dart:956`) while the Activity stores moving time `st.elapsed` (`:913`). A run with a 40-min café stop credits 40 extra "verified" minutes. | `activity_pages.dart:951-957` | Med |
| A2.4 | [BUG] Verified with trivial effort. Source = GPS if `route.length >= 2` (`activity_pages.dart:914-916, 952-954`): two accepted fixes ≥3 m apart. A 5-second, 4-metre "run" = verified (+140 XP, +1 evolution session, +25 claimed points). No minimum distance/duration. | same | Med |
| A2.5 | [BUG] Evolve page text/accessory vs shown mascot. Image uses `lastActivityAnimal` (`activity_result_pages.dart:419`) but text says `${p.partner.label} buka …` (`:479`) and `equipAccessory` writes the single profile accessory (applied to partner). If the run's animal ≠ partner, text and reward target the wrong mascot. Pill says `STREAK ${p.streak}` though evolution is per-animal verified sessions (`:436`). | `activity_result_pages.dart:417-548` | Med |
| A2.6 | [BUG] Story card does not match the saved activity. For a GPS activity the card shows DURASI / SKOR("—") / POIN KLUB only — **no distance or pace** (the `details` string at `:647-653` is only rendered in the tournament branch). Mascot is `p.partner/p.stage` (`:703-704`), not the activity's animal used on Done. Story always uses `activities.firstOrNull` (latest saved), never a specific activity id. | `activity_result_pages.dart:595-845` | Med |
| A2.7 | Done ↔ Profil consistency: streak, XP, stamps come from the same `MeCubit` state → consistent. Done subtitle `next.minStreak - adopted[animal]` uses the same `Stage.forStreak(adopted)` as Profil. OK. `stamps` is +1 per activity (`me_cubit.dart:213`) while calendar counts days — two activities same day = stamps 2, calendar 1 day. | `me_cubit.dart:213` | Low |
| A2.8 | Health mirror writes workout for wall-clock window even when source downgraded to manual, and calories always null. | `activity_pages.dart:939-950` | Low |

### A3. Calculations

| # | Finding | Where | Detail | Sev |
|---|---|---|---|---|
| A3.1 | [BUG] **Pace formatter can print 5'60"** | `core/utils/format.dart:34-40` | `m = secPerKm ~/ 60; s = (secPerKm % 60).round()` → 359.6 s/km → `5'60"`. Used on Recording page (`activity_pages.dart:664`), Save page (`:1029`), voice toast (`:612`), watch tick (`recorder_cubit.dart:123`), **Feed post PACE stat** (`feed_repository_impl.dart:213`). Detail page uses a different, correct formatter `_pace` (`activity_data_sections.dart:10-12`, rounds total seconds first) → Feed "5'60"" vs Detail "6:00 /km". | Med |
| A3.2 | [BUG] Moving time is tick-counted, not timestamp-based | `recorder_cubit.dart:108-126` | `elapsed += 1s` per `Timer.periodic` tick. Timer drift / throttling in background (Android doze, iOS suspension) undercounts moving time → pace too fast. | Accumulate `now - lastTick` while not paused. | Med |
| A3.3 | [BUG] iOS `pauseLocationUpdatesAutomatically: true` | `core/services/location_service.dart:126` | iOS may stop delivering fixes when it thinks user is stationary (e.g. traffic light) and not resume in background → distance gaps, app suspended. Fitness recording should set `false`. | Med |
| A3.4 | [BUG] GPS-loss treated as auto-pause, then distance jump credited | `recorder_cubit.dart:112-116, 139-152` | In a tunnel/under trees >20 s without fixes → `autoPaused`, moving time stops; when fixes return, full straight-line distance from `_last` is added → inflated pace for that split. | Distinguish "no fix" from "stationary" (use `p.speed`), or cap implausible speed. | Med |
| A3.5 | Jitter filter weak vs accepted accuracy | `recorder_cubit.dart:136, 142` | Accepts fixes up to 50 m accuracy but filters only `d < 3 m`; standing still with 10–50 m accuracy adds drift distance (only partially masked by 5 m `distanceFilter`). `p.accuracy > 50` check at :142 is dead (already returned at :136). | Threshold `d < max(3, accuracy)` or speed-based. | Low/Med |
| A3.6 | Recorder splits drift | `recorder_cubit.dart:154-158` | `_splitMark = meters` (not `+1000`) → each split ≥1 km by the overshoot; voice "10 km" fires late. Saved analysis splits are interpolated correctly (`activity_analysis.dart:480-520`), so only the toast/fallback is affected. | Low |
| A3.7 | Division-by-zero guards — OK | `activity_analysis.dart:368-374` (pace null if 0 km/0 s), `:342` `ActivitySplit.pace` only for km≥10 m remainder or 1 km, `Fmt.pace` returns 0'00" below 50 m, chart `span`/`maxX` clamped (`activity_data_sections.dart:331-332`). No NaN/Infinity paths found. | — |
| A3.8 | No speed (km/h) and no calories | whole feature | Cycling shows pace min/km; no km/h anywhere; no calorie estimate (Health write passes `calories: null`). Docs don't require them, so a gap, not a bug. | Low |
| A3.9 | Elevation | `location_service.dart:153`, `activity_analysis.dart:439-451` | Altitude only kept when `altitudeAccuracy ∈ (0,30]`; many Android devices report 0 → no elevation at all. 3 m hysteresis on raw GPS altitude tends to overstate gain. | Low |
| A3.10 | Route projection on Recording | `recorder_cubit.dart:218-224` | Fixed ~1.5 km window clamped to [.05,.95] — any run >~700 m from start gets squashed against the edge in `route` (saved as fallback route). Live screen uses `OsmRouteMap` with real samples, and detail recomputes from samples, so impact limited to legacy/fallback route. | Low |
| A3.11 | Unbounded sample list, O(n²) copies | `recorder_cubit.dart:146, 166, 203-212` | Every GPS fix and every watch HR event copies the whole list (`[...state.samples, x]`) and Equatable deep-compares it. 2-h ride with 1 Hz HR ≈ 10k+ samples → noticeable jank late in long sessions. | Low/Med |

### A4. Persistence

| # | Finding | Where | Sev |
|---|---|---|---|
| A4.1 | [BUG] **One unreadable record wipes history on next save.** `_load` catches decode errors and keeps the seed (`activity_repository_impl.dart:18-27`); the next `save()` `_persist`s seed + new item over the stored key → all previous activities lost. | `activity_repository_impl.dart:14-37` | Med |
| A4.2 | All activities incl. full sample arrays stored in ONE SharedPreferences string | `activity_repository_impl.dart:31-37` | Grows by ~0.5–1 MB per long GPS activity; SharedPreferences rewrites the whole XML/plist each save and loads it all at startup. Move to file/sqlite. | Med |
| A4.3 | [BUG] Photos stored as image_picker cache paths | `activity_pages.dart:934`, `onboarding/.../setup_pages.dart:865` (`me.setPhoto(d.photoPath)`) | No copy into app documents dir (no `getApplicationDocumentsDirectory` anywhere). OS cache cleanup → broken activity photos / avatar after some days (errorBuilder hides it). | Med |
| A4.4 | Demo seed activity "Lari Pagi GBK" dated **today** for every install | `activity_repository_impl.dart:39-54` | Feeds `StampCalendar.days(p, activities)` → new user sees a stamp/activity they never did. [MOCK] | Low |

---

## B. ONBOARDING

Flow: Splash → Intro → Welcome → (ShellRoute with factory `OnboardingCubit`, `app_router.dart:174-188`) Signup → OTP → About → Location → Sports → JoinClubs → Permissions → Watch → Ready → `completeOnboarding` → Feed.

| # | Finding | Where | Sev |
|---|---|---|---|
| B1 | Splash skips onboarding for returning users — **works**: `isOnboarded()` reads prefs bool (`profile_repository_impl.dart:159-162`), `SplashPage._route` → `go(onboarded ? R.feed : R.intro)` (`welcome_pages.dart:31-35`). Always waits 1.9 s even for returning users. | — | OK / Low |
| B2 | [BUG/MOCK] **New sign-up inherits the demo user's progress.** `MeCubit` starts from `ProfileRepositoryImpl.seed` (Budi: streak 13, XP 2120, gems 1250, saldo Rp35.000, stamps 23, 7 adopted mascots up to 48 sessions, followers 31, joined 2026-03-02) (`profile_repository_impl.dart:32-68`). `completeOnboarding` (`me_cubit.dart:115-141`) only overrides name/username/phone/email/gender/area/radius/sports. After sign-out, `signOut` reloads the same seed. A brand-new user lands with a 13-day streak and evolved mascots. | as listed | **High** (if testing as a new user; intentional for demo) |
| B3 | [BUG] **Clubs joined during onboarding are not persisted.** `ClubRepositoryImpl` is in-memory (`club/data/club_repository_impl.dart:10`, `_joined = {'smash','padelpagi'}`, no SharedPreferences; DI `injector.dart:53` `ClubRepositoryImpl.new`). After restart the user is back to the 2 seed clubs. "MINTA" (approval) only adds to `ClubsCubit.state.pending` (`clubs_cubit.dart:66-68`) — never resolved and also lost on restart. | as listed | **High** |
| B4 | [BUG] Sign-out doesn't clear activities/clubs/sessions | `profile_pages.dart:1140-1142`, `profile_helpers.dart:1027-1029` | Only profile + gear reset. Next account sees previous user's activities in Feed/Profil/Stamp calendar. | Med |
| B5 | Name, username, phone, email, gender, area, radius, sports, photo, notifications/goyang toggles → saved at ReadyPage (`setup_pages.dart:849-871`). Area/sports used by MeCubit (`activeSportId = sports.first`). OK. | — | OK |
| B6 | [BUG] Social sign-up stores no phone; social **login** on fresh install just marks onboarded with the seed user (`signup_pages.dart:87-95`); OTP accepts any 6 digits except 000000 (`onboarding_cubit.dart:162-173`). [MOCK, labelled in UI] | — | Low |
| B7 | [BUG] Notification/goyang toggles saved as "on" even if OS denied | `setup_pages.dart:568-579, 866-869` | `perms.request` result ignored; `notifications=true` stored regardless. | Low |
| B8 | Two sources of truth for Goyang enabled | `setup_pages.dart:867` writes `MeCubit` setting `goyangEnabled` (never read anywhere — grep) and `GoyangCubit.updateSettings` (prefs `goyang_enabled`). Dead setting. | Low |
| B9 | Draft not persisted mid-onboarding | `OnboardingCubit` is `registerFactory` (`injector.dart:70`) | Killing the app on step 6 restarts at Intro with all answers lost. | Low |
| B10 | Join-clubs radius filter is cosmetic [MOCK] | `setup_pages.dart:394-402` | Filters by static seed `distanceKm`, unrelated to chosen area. | Low |

---

## C. GOYANG + SHOP / MISC

| # | Finding | Where | Sev |
|---|---|---|---|
| C1 | [BUG] **Goyang "disabled" can still trigger on cold start.** `GoyangCubit()` restores settings async (`goyang_cubit.dart:68-103`), default `enabled = true` (`goyang.dart:25`). `_TabShell.initState` calls `startListening()` immediately (`app_router.dart:341-346`) using defaults; when `_restore` later emits `enabled:false` (or a different sensitivity) nothing stops/restarts the listener. Shake opens the sheet until the app is backgrounded/resumed. | as listed | Med |
| C2 | [MOCK] Lobby responses are scripted (Raka, Dinda, Sisca, Andi) on 1.4 s timers; countdown hard-coded 28:45; host initials hard-coded `'BS'` (`goyang_cubit.dart:153-205`). No real notification sent. Labelled "BUKA LOBI DEMO". | — | Low |
| C3 | Goyang Bareng saves a casual activity with `ActivitySource.manual`, duration 0 (`goyang_flow_pages.dart:545-566`) — consistent with casual rule; `ActivitySource.goyang` exists but unused (it would be counted as verified). | — | Info |
| C4 | Lobby timers keep running if left via certain paths: lobby uses `PopScope(onPopInvoked → endLobby)` (OK) but `pushReplacement(R.goyangJadi)` path calls `endLobby` first (OK). No leak found. | — | OK |
| C5 | Error page variants `server`, `deleted`, `sync` unreachable — `R.error` is never pushed (only `errorPageBuilder` → `notFound`). | `app_router.dart:207, 215` | Low |
| C6 | Shop: purchase flow guarded (owned/full/enough), unavailable items disabled. Venue booking is a labelled demo; allows booking slots already past today. | `shop_flow_pages.dart:125-176, 356-420` | Low |

---

## D. Manual test cases (real device)

1. **Back on Save discards run** — Start GPS run, walk 200 m, SELESAI → Simpan page appears → press Android back. Expected: confirmation "Buang aktivitas?". Actual (bug A1.1): page closes, run lost, nothing in Profil.
2. **Pace format** — Run until Feed post shows pace near a whole minute (or seed a 1 km/359–360 s activity). Expected `6'00"`. Watch for `5'60"` on Feed/Recording/Save vs `6:00 /km` on detail.
3. **Pause correctness** — Start run, walk 500 m, JEDA 2 min (stay still), LANJUT, walk 500 m, finish. Expected: Waktu bergerak ≈ walking time only; Total waktu = wall clock; distance ≈ 1.0 km; no straight-line jump; split toast not repeated on pause (A1.7).
4. **Auto-pause / tunnel** — Stand still 30 s during a run → "auto-jeda" pill, timer stops; walk → resumes. Then cover phone / go underground 60 s while walking → check distance jump and pace for that km (A3.4).
5. **Screen off / background** — Record 15 min with screen locked (Android + iPhone). Expected: route continuous, moving time ≈ wall clock minus stops. On iOS stop 2 min at a light and check updates resume (A3.3).
6. **App kill** — During recording, swipe app away. Expected (ideal): resume prompt. Actual: run lost (A1.2).
7. **Verified vs casual** — (a) GPS run 1 km → Done "Sesi sempurna!", +140 XP, mascot sessions +1 in Geng. (b) Catat Manual → "Tercatat!", +40 XP, streak +1 if new day, mascot sessions unchanged, Liga shows "manual diabaikan" +1. (c) GPS run 5 s / 4 m → check whether counted verified (A2.4).
8. **League points** — Note Liga "kontribusi saya" points, do 30-min GPS run, Done shows "+25 POIN KLUB", reopen Liga. Expected +25; actual +0 (A2.2). Repeat with QR check-in: +25.
9. **Gear mileage** — Profil → Gear note km of default shoes, record a 2 km run with that gear, reopen Gear. Expected +2 km; actual unchanged (A2.1).
10. **Sport kept when GPS off** — Turn device location off, open REKAM AKTIVITAS, choose Sepeda, tap MULAI → Manual page. Expected Sepeda preselected; actual active sport (A1.4).
11. **MULAI latency** — With "Bagikan lokasi awal" ON indoors, tap MULAI; time until recording screen (up to 12 s), and share sheet appears (A1.5). Double-tap MULAI quickly.
12. **QR** — Scan a non-Klubby QR → toast "QR tidak dikenali", then scan valid host QR → Done. Re-scan same → "sudah check-in". Scan with airplane/full storage to provoke save error → scanner should still react (A1.8).
13. **Story** — After a GPS run tap BAGIKAN KE STORY. Expected: distance, pace, run's mascot. Actual: duration/skor/poin only, partner mascot (A2.6). Toggle "Sembunyikan angka", export & save to gallery.
14. **Evolution** — Use an animal one session below threshold (Geng page), record verified activity in a sport of a *different* animal than partner → KLAIM HADIAH → check Evolve text/name matches the mascot shown and accessory goes to that mascot (A2.5). Press Android back on Done/Evolve → app should not close (A1.3).
15. **Onboarding fresh install** — Install, complete sign-up as new user with 2 sports, join 2 clubs. Expected: streak 0, XP 0, only chosen clubs. Actual: streak 13 / XP 2120 seed (B2). Kill & relaunch → splash goes straight to Feed (B1 OK) but joined clubs reverted to seed (B3).
16. **Onboarding permissions** — Deny notifications on Permissions page → Settings should show notifications off (B7).
17. **Goyang disabled** — Settings → Goyang off, force-close, relaunch, shake phone on Feed. Expected nothing; actual sheet may open (C1).
18. **Restart persistence** — Save GPS + manual + QR activities, add photo, force-close, relaunch: activities, detail charts, feed posts, streak present. Re-check photos after clearing app cache (A4.3).
19. **Sign-out** — Sign out, sign up as another user: Feed/Profil must not show previous user's activities (B4).
