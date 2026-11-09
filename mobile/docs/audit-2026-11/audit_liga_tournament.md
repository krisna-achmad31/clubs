# Audit: LIGA tab + Tournament (Klubby mobile)

Scope: `lib/features/league/**`, `lib/features/tournament/**`, plus the cross-feature hooks they depend on
(MeCubit league counters, QR check-in, Done page, Challenges page in `profile/.../streak_calendar_pages.dart`).
Read-only audit; all findings verified by reading code. Paths are relative to
`D:\Bismillah jadi kaya dunia akhirat\clubus\clubs\mobile\`.

Legend: **[BUG]** confirmed defect, **[MOCK]** intentional demo data (labelled in UI) but still a gap, **[GAP]** missing flow/design gap.

---

## How the league score actually flows (as built)

1. `MeCubit.recordActivity` (`lib/features/profile/presentation/cubit/me_cubit.dart:194-205`) bumps per-**sport** counters in `profile.settings`:
   - verified source (qr/gps/wearable/goyang≠manual) → `league_<sport>_minutes += duration.inMinutes`
   - `ActivitySource.qr` → `league_<sport>_attendance += 1`
   - manual → `league_<sport>_manual += 1`
2. `leagueContribution()` (`lib/features/league/presentation/pages/league_pages.dart:44-51`) = authored `Division.myBase` + those counters + `streakDays: p.streak` (current account streak).
3. `LeagueTable` (`lib/features/league/domain/entities/league.dart:172-228`) adds that to the authored `clubBase` and slots the user's club into authored rival lists.
4. Club identity comes from `ClubRepository.myClubs()` (first joined club in the sport with `division != null`) and season data is a const map keyed by club id — only `'smash'` exists (`lib/features/league/data/league_repository_impl.dart:33-34`).

So: score is connected to **MeCubit counters** (persisted in profile settings), **not** to `ActivityRepository`, not to `SessionsCubit`, and only loosely to club membership (by sport, not by club).

---

## 1. Missing flows / dead ends

| # | Sev | Type | Location | What happens | Should happen |
|---|---|---|---|---|---|
| M1 | Med | BUG | `league_repository_impl.dart:31` (`_daysLeft = 3`), `league_pages.dart:795` | Season countdown is a constant 3 days forever. `finished = d.daysLeft == 0` is never true, so the whole "MUSIM SELESAI" outcome (Promosi/Degradasi text, confetti at :918) is unreachable dead code. No season start/end date exists anywhere. | Season needs real start/end dates; daysLeft computed from `DateTime.now()`; end-of-season transition (outcome, reset of counters, new season). |
| M2 | Med | GAP | `me_cubit.dart:194-205` | League counters never reset (no season scoping). Everything recorded since install counts for "musim ini" forever. | Counters keyed by season id (or timestamped) and reset/archived at season end. |
| M3 | Low | MOCK | `league_pages.dart:866-870` | "Klaim hadiah belum tersedia." — prize claim not implemented. | Claim flow, or hide. (Labelled as contoh.) |
| M4 | Low | BUG | `league_pages.dart:790-792` | `SeasonEndPage` with no division renders an empty page with only a header (no message, no CTA). Reachable via deep link `/liga/season` or after leaving the league club. | Show the same "Belum ada liga / CARI KLUB LIGA" empty state as `_NoLeague`. |
| M5 | Med | BUG | `league_repository_impl.dart:277-290` (`segment(String id)`), `app_router.dart` (`R.segment` default `'tanjakan-senayan'`), `league_pages.dart:927` | `segment(id)` ignores `id` and always returns the hardcoded "Tanjakan Senayan". Any feed post `segmentId` (`feed_pages.dart:915`) or `?id=` shows the same segment. | Look up by id; unknown id → "Segmen tidak ditemukan". |
| M6 | Med | MOCK | `league_repository_impl.dart:285-289` | Segment leaderboard always contains `'Kamu' 4:12 (PR)` rank 7, even for a user who never ran it. Crown/Local Legend are static. No GPS→segment matching exists. | User row only from real efforts; hide "Kamu" when no effort. |
| M7 | Low | GAP | `league_pages.dart:978-982` | "MULAI REKAM DI SINI" pushes `R.gps` without passing the segment's sport; GPS page uses active sport (falls back to lari only if active sport isn't a GPS sport — `activity_pages.dart:~379-381`). A cyclist with active sport sepeda records sepeda on a running segment. Recording is never linked back to the segment. | Pass `sportId`/segment id as extra; match efforts on save. |
| M8 | Low | GAP | `league_pages.dart:951-975` | Segment star saves to `settings['savedSegments']` but nothing reads it anywhere (grep: no other usage). Write-only feature. | A "Segmen tersimpan" list (e.g. in Profil) or remove star. |
| M9 | Low | MOCK | `league_pages.dart:1039-1043` | "Klubku"/"Diikuti" filters use static flags (`club`, `following`) on seed efforts, not the user's clubs/follows. | Filter by `ClubsCubit.mine` members and real follow list. |
| M10 | Med | GAP | `league_pages.dart:769-778` | Banner "N aktivitas manualmu tidak dihitung… HUBUNGKAN JAM →" sends to `/devices`, but `ActivitySource.wearable` is never produced anywhere (grep: no caller of `recordActivity` with wearable; WearableCubit does not record). Connecting a watch does not make anything count. | Wearable sync should create verified activities, or change CTA copy. |
| M11 | Low | GAP | `club_actions.dart:358-361` | Club → Turnamen card opens `R.tournamentLive` whenever `matches` is non-empty, including after the tournament finished. Live page has no "Buat turnamen baru" action, so from the club you are stuck on the old tournament (only the "+" record sheet reaches `/tournament/new`). | When `finished`, route to podium or offer "Buat baru". |
| M12 | Low | MOCK | `streak_calendar_pages.dart:631-...` | Challenges progress is a const list (`run` 32/50 km, `club` 64/100 jam…). Labelled "data contoh". Join/leave persists; nothing else. | See S5. |

## 2. Disconnected / sync issues

| # | Sev | Type | Location | What happens | Should happen |
|---|---|---|---|---|---|
| S1 | High | BUG | `streak_rules.dart:78` (`clubPoints: verified ? clubPointsCheckIn : 0`), Done page `activity_result_pages.dart:233,355`, story `activity_result_pages.dart:637-639` | Done page shows **"POIN KLUB +25"** for every verified activity (GPS run, QR). Actual league effect: GPS adds `minutes` → points only via `(total minutes ~/ 60) * 10` (a 30-min run usually adds 0, sometimes +10); QR adds +25 attendance but 0 minutes. Also shown when the user has no league club at all, or for a sport with no league (e.g. lari). Liga contribution therefore does not match what Done/Story told the user. | Compute the reward from the same `ClubScore` delta the league uses (before vs after), and show 0 / hide when the user has no league club in that sport. |
| S2 | Med | BUG | `activity_pages.dart:195-207` | QR check-in (the most "verified" source) saves `duration: Duration.zero` and calls `recordActivity` without duration → contributes 0 verified hours; only attendance ×25. A 2-hour mabar earns no "jam terverifikasi". | Use the session's scheduled/actual duration for QR. |
| S3 | Med | BUG | `me_cubit.dart:200-202` | Attendance is counted for **any** QR check-in in that sport, including sessions hosted by other clubs / public mabar, and is credited to whichever league club you belong to in that sport. Label says "Hadir mabar klub". | Count attendance only for sessions whose `clubId` is the user's league club. |
| S4 | Med | BUG | `me_cubit.dart:194-205` + `league_pages.dart:44-51` | Counters are per sport, not per club and not per membership period. Activities logged before joining the club count; leaving and re-joining (or joining a different badminton club) keeps all points. | Store contribution per (clubId, season) and only from join date. |
| S5 | Med | MOCK | `streak_calendar_pages.dart:637-648, 716, 855` | Challenge progress bars don't use any real data (ActivityRepository km, league hours). "100 jam bareng klub" shows 64/100 while Liga shows the user has ~6 hours. "Papan contoh" always lists Raka=goal, Dinda=¾goal. `done` challenge is marked done statically. | Derive progress from activities (km by sport, verified hours, sessions with friends). |
| S6 | Med | BUG | `league_pages.dart:50` | `streakDays: p.streak` uses the **current** account streak (all sports) as the season streak bonus, and adds it to every sport's league. Breaking a streak retroactively removes up to streak×5 points from the club → club rank can drop on a day you did nothing "wrong" in the season; multi-sport users double-count. | Accumulate "streak days during season" per sport (monotonic). |
| S7 | Low | BUG | `league_pages.dart:54-59` (`liveLeagueRank`) used by `club_pages.dart:196,465` | Club page shows the live rank only when `LeagueCubit.state.area` is currently loaded for that club's sport. If the Liga tab was switched to another sport (or active sport differs), the club page falls back to the static seed `club.rank` (4), which can disagree with the rank the Liga tab showed. | Compute rank from the club's own sport division independently of the tab's selected sport. |
| S8 | Low | BUG | `league_cubit.dart:10` (default `sportId: 'badminton'`), `injector.dart:64` (`..load()`), `league_pages.dart:571-572` | `/liga/score` and `/liga/season` read whatever the cubit last loaded. If opened before the Liga tab ever built (deep link / notification), they show the badminton board even if the active sport is something else; with `clubsKey ''`. | Score/Season pages should call `sync` with the active sport like the tab does. |
| S9 | Low | GAP | `league_cubit.dart:96-105` | `_picked` sport stays in memory: after the user changes active sport in Profil, Liga keeps showing the previously picked sport (until restart). Intentional-ish but surprising. | Clear `_picked` when active sport changes, or persist the choice explicitly. |
| S10 | Low | BUG | `league_pages.dart:461-465` + `league_repository_impl.dart:224-232` | `_NoLeague` picks `clubs.where(sportId).firstOrNull` (any club), while the repo picks the first club **with a division** and **with a season entry**. A user in a club with `division != null` but no `_seasons` entry is told "<club> belum ikut liga" though the club card shows "Divisi N". | Share one selector; distinguish "no season data" from "not in league". |
| S11 | Med | GAP | tournament (all) | Tournament results feed into nothing: no XP, stamps, streak, league points, rating, feed post, or profile history. Only "BAGIKAN KE STORY". Banner admits it (`tournament_flow_pages.dart:541-543`). | At minimum a feed post + activity/stamp for participants; optionally league attendance. |
| S12 | Med | MOCK | `tournament_engine.dart:93-110` | Players are a hardcoded roster (`Kamu, Dinda, Raka…`, then `Pemain 13…`), not club members or session participants. "Kamu" uses the literal name, not the user's name/avatar. Even when launched from a club (`club_actions.dart:360`) or host flow (`host_flow_pages.dart:618`). | Seed roster from club members / session attendees; allow editing names. |

## 3. Calculation flows

### League
| # | Sev | Type | Location | Finding |
|---|---|---|---|---|
| C1 | Med | BUG | `league_pages.dart:369-373`, `league_pages.dart:844-847`, `league.dart:223-227` | `gapToNext` is computed vs the **previous listed row**, but the text says "menyalip #${rank-1}". On NASIONAL the list has gaps (ranks 1,2,3,127,128). If my club is #127, the previous row is #3 → message reads "Butuh 11.xxx poin lagi untuk menyalip #126" with the gap to #3. Repro: NASIONAL with streak ≥ ~25 so you pass PB Elang Medan (7.695). | Use `standings[i-1].rank` in the text, or hide the gap when the row above isn't `rank-1`. |
| C2 | Low | Design | `league.dart:179` | Ties: `r.points >= points` puts my club **below** any rival with equal points (no tiebreaker). `gapToNext` adds +1 consistently. Acceptable, but undocumented; rivals tied among themselves keep authored order. | Document or add tiebreak (e.g., verified hours). |
| C3 | Low | Design | `league.dart:70` | `hours = verifiedMinutes ~/ 60`: only whole hours count (floor of the season total). Users see "jam terverifikasi" rounding down; combined with S1 makes single sessions look like they gave nothing. | Use minutes ×10/60 or show minute precision. |
| C4 | Info | OK | `league.dart:217-220`, `league_pages.dart:204-206` | Promotion/relegation: area 20 clubs, top 3 promote, ranks 18-20 relegate; national top 10 prize, no relegation. Formulas consistent between table, zone dividers and Season page. Zone divider for relegation only appears in expanded view (compact shows caption) — fine. |
| C5 | Info | OK | `streak_rules.dart:102-105` | Points formula hours×10 + attendance×25 + streakDays×5 matches info sheet text (`league_pages.dart:78`). Starting club total = 7.465 (base) + my 60+50 = 7.575 + streak×5 → area rank 4 (between Rajawali 7.880 and Kok Terbang 7.010), matching seed `club.rank: 4`. |
| C6 | Info | OK | `KProgress` (`core/widgets/basics.dart:199`) | Challenge progress clamps 0..1; goals are const non-zero → no divide-by-zero today, but `progress / goal` has no guard if goals become data-driven. |

### Tournament engine (`lib/features/tournament/presentation/cubit/tournament_engine.dart`)
| # | Sev | Type | Location | Finding |
|---|---|---|---|---|
| T1 | **High** | BUG | `tournament_flow_pages.dart:393,419,430` + `tournament_engine.dart:37-41` | **Gugur (elimination) champion is decided by total rally points, not by the bracket.** Podium "Juara" = `ranked.first` (sum of points). A player with a bye plays fewer matches. Repro: Gugur, 6 players, 3 courts. R1: 3 matches; R2: w1 vs w2, w3 gets bye; R3 final w3 vs winner. If w3 wins the final 21-20: w3 = 42 pts, runner-up = 21+21+20 = 62 → **runner-up shown as "Juara"**. Also 2nd/3rd for elimination are arbitrary (no 3rd-place match; semi-losers ranked by points). | For gugur, champion = winner of last match; rank by round reached, then points. |
| T2 | High | BUG | `tournament_engine.dart:111-116`, `tournament_flow_pages.dart:112-141`, entry from record sheet `record_sheet.dart:123` | Tournament config is **mutable while a tournament is running** (same singleton cubit). Opening "Buat Turnamen" mid-tournament and changing courts/points/format alters the live one: (a) `points` changes `validScore` target for remaining matches; (b) `format` changes the `nextRound` branch (e.g., Americano → Gugur mixes planned waves with elimination of "A & B" team strings); (c) `courts` changes wave sizes but `rounds` was precomputed (`:252-257`) → `state.round >= state.rounds` finishes the tournament **before the final**. Repro: Gugur 8 players 3 courts (rounds=4); during R1 open "+ → Turnamen", set courts 1, back; play on → finishes after the 2nd semi, no final. | Freeze config into an immutable "running tournament" object; New page edits a draft; warn "Turnamen sedang berjalan — mulai baru?". |
| T3 | Med | BUG | `tournament_engine.dart:243-249` | King of the Court drops players: `_queue = names.skip(state.courts * 2)` assumes every court got a match. When players are odd and `courts*2 > players`, the leftover player is neither playing nor queued and **never plays**. Repro: KoC, 5 players, 3 courts → "Andi" never appears; 7 players/4 courts → "Ayu" never appears. Validation (`validate_tournament.dart`) doesn't limit courts for KoC. | `_queue = names.skip(2 * firstWave.length)`; validate `courts <= players ~/ 2`. |
| T4 | Med | Design | `tournament_engine.dart:37-41`, `:296-297` | Round Robin and King of the Court rank by total points scored, not wins. In RR a player who wins every match 21-19 can rank below one who lost once but scored more. | RR/KoC: rank by wins, then point difference. (Americano/Mexicano by points is standard.) |
| T5 | Med | Design | `tournament_engine.dart:117-118`, `tournament_flow_pages.dart:345-361` | `validScore` requires `max(a,b) == points` and steppers cap at `points` → no deuce (22-20, 30-29 in badminton; padel "golden point"). Real scores can't be entered. | Allow win-by-2 up to a cap (e.g., 30) as an option. |
| T6 | Low | BUG | `tournament_engine.dart:40` | Tiebreak is alphabetical by name → "Kamu" (K) beats e.g. "Maya" on ties purely by name; ties shown with different ranks. | Tiebreak by head-to-head/point diff, or shared rank. |
| T7 | Low | Design | `tournament_engine.dart:178-182` | Mexicano round 3,6,9… pairs group[0]&group[1] (1st+2nd) vs 3rd&4th — strongest pair together, opposite of Mexicano balancing (1&4 vs 2&3). Rounds 1/2 fine. | Use 1&4 vs 2&3 every round (standard) or 1&3 vs 2&4 alternation. |
| T8 | Low | GAP | `tournament.dart:8`, `tournament_flow_pages.dart:90-91` | Enum description says "Single / double elimination"; only single is implemented (UI subtitle correctly says "gugur tunggal"). |
| T9 | Info | OK | `_circle` `:136-161` | Round-robin circle method with '' bye for odd counts is correct (test covers 5 players → 10 unique pairs). Americano doubles via circle pairing: every player partners every other exactly once (needs multiple of 4, validated). |
| T10 | Info | OK | gugur rounds `:252-257` vs `nextRound` `:333-345` | With fixed config, round count formula matches waves incl. byes (checked 4/5/6/7/8 players with 1-3 courts). Bye player is placed first in next stage's list → plays the first match next stage (fine). |
| T11 | Low | GAP | `submitScore` `:281-282`, `goToRound` | Past rounds are read-only; a wrong score cannot be corrected after "LANJUT BABAK" (no confirmation before advancing). | Confirm before advancing or allow host correction with recompute. |

## 4. Persistence

| Item | Persisted? | Note |
|---|---|---|
| League contribution counters (`league_<sport>_*`) | Yes (profile settings via ProfileRepository) | But never season-reset (M2) and cleared on sign-out. |
| Joined challenges (`settings['challenges']`), saved segments | Yes | Saved segments unused (M8). |
| Liga sport pick (`_picked`), AREA/NASIONAL toggle | No (memory) | Minor; resets on restart. |
| **Tournament (entire state, `_history`, `_planned`, `_queue`)** | **No** — `TournamentCubit()` has no repository (`injector.dart:67`) | App kill / OS memory reclaim mid-tournament loses every score. **Med-High** for a live courtside tool. Podium banner admits "selama sesi aplikasi ini". |
| Season results / history | Not modeled | Nothing to persist. |

## 5. Test coverage gaps
Existing: `test/domain/league_table_test.dart` (5 tests), `test/widget/league_flows_test.dart` (8), `test/cubit/tournament_recovery_test.dart` (6), `test/domain/validate_tournament_test.dart` (5).
Missing:
- Gugur champion = bracket winner (T1) — current test only asserts match count.
- King of the Court roster coverage with odd players / many courts (T3); no KoC test at all.
- Mexicano pairing / standings-based regrouping — no test.
- Config change during a running tournament (T2).
- National gap text vs listed rank (C1).
- Done-page club points vs league delta (S1); QR check-in minutes (S2).
- Season end / countdown (M1 — currently untestable as it's const).
- Segment id routing (M5), SeasonEndPage empty state (M4).
- Tie handling in `LeagueTable` (equal points).

---

## 6. Manual test cases (real device)

1. **Done page vs Liga points (S1)** — Note Liga "Kontribusimu musim ini" value. Record a 20-min GPS badminton/lari activity (or any verified GPS) → Done page shows "POIN KLUB +25". Open Liga. *Expected:* contribution increases by the same amount. *Likely actual:* +0 (or +10), and +25 shown even for lari with no lari league.
2. **QR check-in hours (S2/S3)** — Check in via QR to a badminton session hosted by a club you are NOT in. *Expected:* no attendance for PB Smash Ceria; if own club, hours should increase. *Likely actual:* attendance +1 (+25) credited to your club; hours unchanged.
3. **Streak drop (S6)** — Note club points; let streak break (or use a test profile with a broken streak). *Expected:* season points never decrease. *Actual:* club points drop by streak×5.
4. **Season countdown (M1)** — Open Liga on two different days. *Expected:* "N HARI lagi" decreases; at 0 the Season page shows Promosi/Degradasi. *Actual:* always "3 HARI".
5. **National gap text (C1)** — Liga → NASIONAL, with enough points to be #127/#128. *Expected:* "menyalip #126" uses the gap to #126 or is hidden. *Actual:* gap computed to #3 but labelled #126.
6. **Segment id (M5/M6)** — Open a feed post's segment link, then manually open `/segment?id=anything`. *Expected:* different segment / not-found. *Actual:* always "Tanjakan Senayan" with "Kamu 4:12 (PR)" even with no runs.
7. **Gugur champion (T1)** — "+" → Turnamen → Gugur, 6 pemain, 3 lapangan, 21 poin. R1: all 21-0 (winners Kamu, Raka, Andi). R2: Kamu vs Raka 21-20 (Kamu wins). R3 final Andi vs Kamu: Andi 21-20. *Expected:* Juara Andi. *Actual:* Juara Kamu (62 pts) — runner-up crowned.
8. **Config edit mid-tournament (T2)** — Start Gugur 8 pemain 3 lapangan. During R1, open "+" → Turnamen, change lapangan to 1, go back without starting. Finish rounds. *Expected:* config locked or final still played. *Actual:* tournament ends after round 4 without a final.
9. **King of the Court dropped player (T3)** — KoC, 5 pemain, 3 lapangan. Play several rounds. *Expected:* all 5 play. *Actual:* "Andi" never appears in any match and stays at 0.
10. **Deuce (T5)** — Enter 22-20 at 21 poin. *Expected:* allowed (badminton rules). *Actual:* stepper caps at 21; SIMPAN disabled.
11. **Tournament persistence** — Start a tournament, enter 2 scores, force-kill app, reopen Klub → Turnamen. *Expected:* resumes. *Actual:* "Belum ada turnamen" / "Buat turnamen".
12. **Finished tournament from club (M11)** — Finish a tournament, go Klub → tab Turnamen card. *Expected:* option to start a new one. *Actual:* opens old live page; no "new" action.
13. **Join/leave club league (S4)** — Record verified badminton minutes, leave PB Smash Ceria, rejoin. *Expected:* contribution resets / only post-join activity counts. *Actual:* full prior contribution restored.
14. **Season page empty (M4)** — Leave the league club, open `/liga/season` (or via back stack). *Expected:* empty state with CTA. *Actual:* blank page with header only.
15. **Challenges (S5)** — Run 5 km GPS, open Tantangan "Lari 50 km". *Expected:* progress increases. *Actual:* stays 32/50.
