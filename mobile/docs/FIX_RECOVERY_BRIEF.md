# Recovered fix briefs

Recovered from the interrupted local Claude session. These are historical task descriptions; verify each finding against the current code before changing it.

## Fix activity league tournament findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these): `lib/features/activity/**`, `lib/features/league/**`, `lib/features/tournament/**` (pages, cubits, data, domain). Line numbers are approximate; re-read the code. Abbreviations: AP = activity_pages.dart, RS = record_sheet.dart, LP = league_pages.dart, TP = tournament_pages.dart, TC = tournament_cubit.dart, RC = recorder_cubit.dart.

REQUIRED API CHANGE: the router calls `StoryPage(extra: s.extra)`. Add `final Object? extra` to StoryPage. Handle these cases:
- null: the user's last activity / `lastReward`.
- `Map` with `'type': 'tournament'` (keys title, champion, rank): tournament template.
- `Map` with `'type': 'stamps'` (keys month, count): stamp calendar template. The streak agent pushes this.
- Anything else: default card.

ACTIVITY
- Save page:
  - AP:517 "Tambah foto" toasts. Use ImagePicker (multi-image or single, repeated), keep `List<XFile>`, show removable thumbnails, and add `photos` (List<String> paths) to the Activity entity.
  - AP:519 PR banner is hardcoded and fake. Show it only when there is a real segment match (km >= the segment length, from league segment data if accessible; otherwise derive it from the recorded distance). Make it tappable → `'${R.segment}?id=<id>'`.
  - AP:523-537 gear card: hardcoded, not tappable, and shown for every sport. Make it a KRow with a chevron that opens a gear picker sheet. Read gear via `sl<GearCubit>()` (features/profile/presentation/cubit/gear_cubit.dart; read-only for you) filtered by sport. Save the choice on the Activity (`gearId`). Hide it when the user has no gear for this sport.
  - AP:475: an empty title saves ''. Fall back to the default title.
  - AP:497/502: header X and "Buang aktivitas" discard with no confirm. Use showConfirmSheet.
- Manual page:
  - AP:611 TANGGAL and AP:616 JAM are dead. Use `showDatePicker` (last 7 days) and `showTimePicker`; build `start` from them (AP:583).
  - AP:598-606 sport chips `take(4)`: add "+ Lainnya" → showSportPicker, and always include the selected sport in the chips.
  - AP:563: `_sport` defaults to 'badminton'. Default to `context.read<MeCubit>().state.activeSportId`.
  - AP:582: add title and notes KInputs (set Activity.note).
  - AP:587: parse "x km" into distanceKm, otherwise store it as score.
  - AP:601: add a `_busy` guard.
- GPS:
  - AP:268-274: text says "…atau MULAI TANPA GPS" but there is no control. Add `KLink('MULAI TANPA GPS')` → `context.push(R.manual)`.
  - AP:226: "GPS mati" pill is dead. When denied, tap re-requests via LocationService, or opens settings (geolocator `Geolocator.openLocationSettings()`).
  - AP:37-42: compact `_WatchCard` disconnected banner is dead → Pressable push R.devices.
  - AP:239-244: GPS sport chips are a plain Row that overflows. Use Wrap.
- Recorder:
  - RC beacon/voice toggles are stored but unused (AP:250-265). Beacon: on start, share a live-location message via SharePlus, and replace the hardcoded "ke Mama via WhatsApp" with honest copy ("Kirim lokasi live ke kontak darurat").
  - Voice: there is no TTS package, so check pubspec. If flutter_tts is absent, use HapticFeedback + a SnackBar/overlay "1 km · 5:32/km" announcement on each km split and relabel the toggle "Notifikasi tiap 1 km" (honest).
- Evolve:
  - AP:788-834 accessory tiles are not tappable, and "PAKAI SEKARANG" equips nothing. Make the tiles selectable; the button calls `sl<MeCubit>().equipAccessory(item)`, then `go(R.feed)`.
  - Colours: `Color(0x33FFFFFF)` → `AppColors.white.withValues(alpha: .2)`; `Color(0xFFB86FEA)` → `AppColors.purple`/`purpleD`.
- Story:
  - AP:893-894 INSTAGRAM/TIKTOK: show a toast on capture failure.
  - AP:856/912/934/943: drive the content from the last activity / `lastReward` / extra. Show the verified pill only when verified. Remove the hardcoded "PB Smash Ceria · Mabar Rabu Malam" and "21–17" unless the data has them.
  - AP:958 `Colors.transparent` → drop the border when not selected.
  - AP:900-945: wrap the fixed-size card in `MediaQuery.withNoTextScaling`.
- Done page:
  - AP:752: the casual StatChip `Hue.white` is invisible. Use `Hue.grey`.
  - AP:698: when lastReward is null, the page invents a verified reward. Fall back to a casual-looking neutral state ("Aktivitas tersimpan") with no confetti, or redirect to the feed.
  - If `lastReward.newAnimal` is true, show "Hewan baru gabung Geng Gemoy!" with a button → R.geng.
- AP:123 `Color(0xFF2B3A42)` → `AppColors.scannerSoft`. AP:161 Scan banner "Check-in = Verified ✓" → `KBanner.ok`. AP:167 hardcoded "GOR Mahakam" → derive it from the scanned session, or generic copy.
- RS:54 "Sesi berikutnya: Rabu 19.00…" is hardcoded. Read the next joined session from SessionsCubit (features/session/presentation/cubit; read-only); tap → R.session(id). Hide it if none.
- RS:33 says "+20 XP"; use the actual `StreakRules.xpVerified` value.

LEAGUE
- LP:83 standings: only the user's club can be tapped. Add `clubId` to Standing and tap → R.club(clubId).
- LP:219-230 TOP KONTRIBUTOR rows → showUserSheet.
- Segment:
  - LP:327 star: add saved state (persist with `sl<MeCubit>().setSetting('savedSegments', ids)`), filled/unfilled icon, toasts "Disimpan"/"Dihapus".
  - LP:341-345 filter chips don't filter efforts. Add club/following flags on SegmentEffort and filter.
  - LP:349-362 effort rows → showUserSheet.
- LP:40 info icon → "Cara kerja liga" sheet (promotion, relegation, points).
- LP:51 division card opens SeasonEnd while 3 days remain. Point it at the score/standings (R.leagueScore); SeasonEnd only when `daysLeft == 0`.
- LP:250-297 SeasonEnd is hardcoded and contradicts the data. Build it from the division data (rank, points, promoted/stayed/relegated) and the user's partner mascot. Remove the leaked "BERTAHAN / TURUN … varian" design-note card; show only the matching variant.
- LP:214 vs LP:95: use `d.myWeekPoints` on both. LP:176: derive initials from `mine.name`.
- LP:36-37: double top inset; remove the extra `MediaQuery.paddingOf(context).top`.
- Add a red "⬇ ZONA DEGRADASI" divider for the relegation zone.
- LP:260: white text on a yellow pill → `fg: AppColors.ink` or orangeD. LP:50 `Color(0xFFFFE59E)` → `AppColors.yellowM`.
- "Me" highlight uses the blue family (LP:19, 133, 151, 227, 353, 359) → primary/primaryL/primaryD. LP:197 "Jam aktif terverifikasi" → KBanner.ok style. LP:12 silver = faint.
- LP:64: "naik ke Divisi Utama" even on Divisi Nasional. Derive the next division name.

TOURNAMENT
- Rounds and pairings:
  - TC:73-86 / TP:32: setup values are unused. Add `TournamentCubit.start()` that generates rounds and matches from the setup (format, courts, points, players), sets round 1, resets `finished`, and builds the title from the format. Add a tournament name KInput in setup.
  - "PRATINJAU JADWAL": show a preview sheet of round 1 pairings, then MULAI → live.
  - TC:114-120 `nextRound()` only increments the round: generate new pairings per round (rotate partners for Americano, winners advance for Gugur, round-robin schedule).
  - The lazySingleton keeps `finished` true across tournaments: reset it in start().
- Conflicts and scores:
  - TP:228 / TC:85: the global conflict shows on every court. Use a per-court `Map<int, ScoreConflict>`.
  - TP:220: prefill team A with `m.scoreA`.
  - TP:241-243/283: validate scores. No ties; the winner must reach `st.points` (or the loser < points). Disable SIMPAN otherwise.
  - TP:186: highlight the winner only when `m.done` and scores differ.
  - TP:146: done matches can't be edited. Allow editing until the next round starts (reopen the prefilled sheet).
- TP:127-144: round pills are dead. Tap → `cubit.goToRound(r)` and show that round's matches (read-only for past rounds).
- TP:147-171: KLASEMEN shows the top 3 only. Always append the user's row and add `SectionTitle(action: 'Lihat semua')` → full standings sheet.
- TP:389-393: "Hasil masuk Riwayat Tanding" has no route. Remove the line, or make it honest ("Hasil tersimpan di Rating Tanding" → push R.rating).
- Podium:
  - TP:340 "BAGIKAN KE STORY": push R.story with extra `{'type': 'tournament', 'title': ..., 'champion': ..., 'rank': ...}`.
  - TP:326-386: use player data. Compute the record. Award XP: MeCubit has no addXp, so call `recordActivity(source: <a verified source>, sportId: ...)` once when the podium opens, guarded against double calls, or show honest copy. Pick whichever matches ActivitySource semantics.
  - TP:330 silver: AppColors.faint.
- Colours:
  - TP:135 current round → primary.
  - Tournament actions use ONE accent: use primary for actions (INPUT/SIMPAN SKOR, MULAI, LANJUT BABAK) and purple only for the tournament identity header.
  - TP:202 court label → primary.
- Overflow:
  - TP:273 `KMiniButton('PAKAI PUNYA ${by}')` → "PAKAI PUNYANYA".
  - TP:345-372 podium: names maxLines 1 + ellipsis, height ~300.
  - TP:70-76 "Poin per babak" chips: put them in a Wrap on their own line.

When done, run analyze, make sure your files are clean, then give the compact final report.

## Fix club + session + host findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these): `lib/features/club/**` and `lib/features/session/**` (pages, cubits, data repos, domain entities). Line numbers are approximate; re-read the code. The NewClub area picker and Explore header area picker are ALREADY done, so don't redo them.

REQUIRED API CHANGE: the router now calls `ClaimPage(id: ...)`. Add `required this.id` (String) to ClaimPage in session_pages.dart.

CLUB (club_pages.dart)
- Club header ellipsis (~376) goes straight to ProPage. Open a sheet instead:
  - Salin kode (Clipboard + toast)
  - Bagikan (SharePlus)
  - Keluar klub (confirm, then a ClubsCubit leave method; add it in cubit/repo)
  - Laporkan (sheet with reasons, then pop + toast)
  - "Klub Pro" → R.pro, for admins/owners only. Check how ownership/admin is modelled; add an `isAdmin` check if needed.
- `KODE: X` pill (~362) is not tappable: tap copies to clipboard and toasts.
- Members tab (~449-459):
  - The list is hardcoded to 4 people for every club. Generate the list from `club.members` deterministically (seed names). A new club shows only the owner (the current user, from `sl<MeCubit>().state`).
  - Rows tap → showUserSheet.
  - Add "Lihat semua" when there are more than 5.
- Feed tab (~440-448): add a MascotSays empty state.
- Chat and Kas tabs (~417-420) push for non-members. Gate them: non-members get a sheet "Gabung dulu untuk buka Chat/Kas" with a GABUNG button.
- Explore:
  - `'${Sports.all.length} olahraga ▾'` chip (~227) toasts "segera hadir". Use `showSportPicker`, then filter clubs and sessions by that sport, and show the chosen sport as a removable chip.
  - Filters: the Explore area (MeCubit area) should filter or sort clubs and sessions. At least sort by distance and show the area in the empty state.
  - Search hint "olahraga, lokasi" (~217): make `match()` check sport name, venue and area too.
  - Add an empty state (~231/233) when filters return nothing.
  - The Turnamen and Venue segments (~249-260) ignore the search and sport filters: apply them.
  - Venue items tap → `context.push(R.venueOf(venue.id))`, with ids from `Venues.all` in core/widgets/sheets.dart.
- People cards:
  - IKUTI (~268) only toasts. Keep a followed set in state (local StatefulWidget state is fine), toggle the label to "DIIKUTI ✓", and call `sl<MeCubit>().setFollowing(...)`.
  - Cards (~262-270) tap → showUserSheet.
- Chat:
  - Header users icon (~588) pushes a new ClubPage, so the stack loops. Open a members sheet instead.
  - Chat header club name (~584): maxLines 1 + ellipsis.
  - Sticker colour is dropped (~643 + club_repository_impl ~130): pass bg through `send(..., stickerBg:)`.
  - Announcement toggle (~619-628): show it to admins only; reset `announce` after each send (club_chat_cubit ~30-34); show it even when there are no messages yet.
  - Unread badge (~119-129) is never cleared: mark read when ChatPage opens (add a cubit/repo method).
  - Chat colours: send button, own bubbles, focus border and author name use AppColors.blue (~676, 683, 716, 725) → primary family.
- NewClub:
  - "…Club Pro." banner (~934) → onTap push R.pro.
  - Payout (~773) is prefilled with Budi Santoso's BCA. Default to null so the "Tambah rekening" button shows.
  - Created club (repo create ~92-104) has an empty emoji: `emoji: Sports.byId(sportId).emoji`.
  - Colours: camera tile and buttons with textColor blue (~795, 796, 847-849, 928, 932) → primary. Privacy check (~829) → primary. KChoice "Butuh persetujuan" (~820) → `hue: Hue.purple`.
- Kas:
  - Download icon (~1037) toasts → push R.pro (for a non-Pro club) or share a CSV text via SharePlus.
  - CATAT KELUAR (~1039) only toasts. Add a sheet with amount, category chips and note, then save into the kas list (add to cubit/repo) and show it in the list.
  - TARIK DANA (~1040) is a misleading money toast. Use a confirm sheet with amount input (≤ balance), destination `club.payout.masked` (or "Tambah rekening dulu" if null), and confirm. Then deduct and add a kas entry.
  - "Okt"/"Oktober" (~1056/1064) are hardcoded: use the current month.
  - Overflow: "CATAT KELUAR"/"TARIK DANA" half-width buttons need `small: true` or stacking.
- ProPage:
  - COBA GRATIS (~1138-1141) ignores `_yearly`: include the plan in the action.
  - Hardcoded "PB Smash Ceria yang sudah 48 anggota" (~1158): use the club from a query param or the first owned club. You can't change the router, so read `GoRouterState.of(context).uri.queryParameters['club']` and push `'${R.pro}?club=$id'` from your call sites.
- Hardcoded bits:
  - Banner for `club.id == 'smash'` (~436): make it generic, or drive it from data.
  - "Gratis" (~470): use the session fee.
- Explore club card colour (~287) doesn't match `club.color`. Add a Color→Hue map covering all tokens (local helper) and use it in both places. SessionPage header (~124) should use the club colour too.
- Overflow:
  - Session line (~509): put the fee on its own line, or ellipsize only the venue.
  - KSegmented with 5 items at 13pt (~216): "Turnamen" ellipsizes, so use a horizontally scrollable KTabs/chips.
  - "CARI KLUB"/"BUAT KLUB" (~63-64): use small buttons.

SESSION (session_pages.dart)
- Participant AvatarStack (~189): tap opens a participants sheet, rows → showUserSheet.
- Cancel reason (~582): pass `reason` to `cubit.cancel` (extend the cubit/repo to store it); show a KInput when "Lainnya" is picked.
- Payment rows:
  - "Ditolak bank/e-wallet" (~633): there is no method choice, so reword the action to "COBA LAGI".
  - "QR BARU" row (~631): use `s.full ? null : retry`.
- Hidden long-press waitlist promotion (~696-700): remove it.
- SlotPage:
  - Reachable via a notification (feed). On open, if the rsvp is waiting, call `promote()` if the cubit needs it. Read the code.
  - Countdown (~757-790): listen for expiry and call `releaseSlot`, then go to ExpiredPage.
  - Pass the remaining window to PayPage; don't restart a 10-min timer.
  - "LEPAS SLOT (OPER KE ANTREAN #5)" (~773) is too long: use "LEPAS SLOT" with a caption.
  - Slot breakdown and `promote()` (~793, sessions_cubit ~90) ignore guests: use `Fees.total(s.fee, 1 + r.guests.length)`.
- ClaimPage (~810-849) is fully hardcoded:
  - Use `id` for the session.
  - Take the guest name from the session's rsvp guests if present, otherwise "Tamu".
  - Mask the phone from MeCubit or show generic.
  - Use a real 6-digit OTP KInput (digits, max 6).
  - On verify: create/mark the ticket and go to TicketPage.
  - It currently goes to R.signup (~811), which leaves the flow: keep the user in the claim flow; only offer "Daftar Klubby" as a secondary link to R.welcome.
- Guests:
  - Names are prefilled as ['Andi','Dimas'] (~268), and `names[i]` can throw a RangeError. Use `List.generate(maxGuests, (i) => '')` and require names (placeholder 'Nama tamu ${i+1}').
- Countdown and holds:
  - CountdownCubit restarts on every PayPage visit (~351): store `holdUntil` in Rsvp and derive the remaining time from it.
  - Hardcoded "antrean #5" (~634, ~773): derive the position from the waitlist.
- Waitlist "Kabari via WhatsApp" toggle (~680/736): persist it in Rsvp/cubit.
- Ticket:
  - Court fallback 'Lap 3–4' (~458): omit it when empty.
  - Calendar link (~517-525): add `dates=` from the session start/end (YYYYMMDDTHHMMSS format).
  - Statuses (~476/491): handle each separately. pendingPayment = yellow/orangeD "MENUNGGU BAYAR" with a BAYAR button; cancelled = red/muted.
  - "LIHAT DETAIL MABAR" (~470) → SessionPage → ticket loop: pop if the previous route is the session.
- Colours (blue → primary): LEVEL StatBox (~197), KStepper (~285), PETUNJUK ARAH (~257), Expired actions (~658), ticket header strip and LUNAS pill (~485/491).
- Hue consistency:
  - Waitlist = yellowL/orangeD everywhere. "LIHAT ANTREAN" and "MASUK WAITING LIST" both use `Hue.orange`; the cancel-sheet waitlist banner (~579) and step 1 (~686) change from blue to yellow/orange.
  - Full = red (~184-192) and also in club cards (club ~243, ~512, currently orange → red).
  - Payment countdown: one colour (red, ~433 and ~786).
- Overflow:
  - "BAYAR PAKAI QRIS · Rp107.000" (~324) → "BAYAR · Rp…".
  - "+ KALENDER"/"CHAT SESI" (~467): drop the "+", use small buttons.

HOST (host_pages.dart)
- TANGGAL & JAM KField (~83): `pickDateTime`, saved into the draft.
- LOKASI KField (~85): `showVenuePicker`, saved into the draft.
- `_Opt` rows (~108-141) have no onTap. Add onTap and pickers:
  - Club: list of the user's clubs from ClubsCubit.
  - Deadline: chips H-1 19.00, H-0 12.00, 2 jam sebelum.
  - Guests: Tanpa tamu / Maks +1 / Maks +2.
  - Wrap the value in Flexible + ellipsis.
- Draft and repo: extend SessionDraft.copyWith (mabar_session.dart ~160-201) with when, venue, clubId, deadline and guests. session_repository_impl `create` (~114-134) must map every field instead of hardcoding PB Smash Ceria / RAB 29 OKT.
- Sports: only 5 are offered (~16). Add a "+ Lainnya" chip → showSportPicker.
- `_pickNumber` chips (~51) are always unselected: mark the current value.
- `_notify` (~168/233): use it, or remove it. "48 anggota" (~231): use the club's members. "BATAL ≤ 24 JAM" (~207): derive it from the draft deadline.
- Manage page:
  - "+N peserta lainnya" (~296): tap expands the list.
  - Waitlist `take(2)` (~304): add "Lihat semua". The gripVertical handle (~312) implies reordering: remove it.
  - ellipsisVertical on paid participants (~358): sheet with Tandai hadir / Hapus (confirm) / Refund (confirm). Implement them in the cubit.
  - UBAH SESI (~263) + "SIMPAN JADWAL BARU" (~509): add pickDateTime in the reschedule tab and update the session via the cubit.
  - TANDAI HADIR (~458) always marks `absent.first`: open a picker of absent participants; absent avatars (~455) are tappable too.
  - "Tutup & tandai no-show" (~469-471): store no-shows via the cubit.
  - "Hadir x/slots" (~447): use participants.length. "Tutup 19.30" (~449): `s.start + 30 min`.
- Host cancel sheet (~485-514):
  - Pass reason and note to the cubit; refund paid participants (mark them refunded).
  - Own the note controller in a StatefulWidget; don't dispose it in whenComplete.
- Entry points:
  - Add a "KELOLA" button on SessionPage for the host/admin → R.hostManage(id).
  - In the ClubPage Jadwal tab, add "Buat Mabar" for admins → R.hostNew.
- "SCAN TIKET TAMU" (~464) opens the player's own check-in scanner. Use a host-side guest-ticket flow instead: a sheet "Scan / masukkan kode tiket" with a KInput for the ticket code, which marks that participant present. Don't route to R.scan.
- Colours: blue → primary on the QR page background (~409/436/438/464; use primary), UBAH JADWAL segment/chips/button (~491/494/502), TANDAI TUNAI (~357), SALIN (~220), Slot stat (~271), `_Opt` values (~137).
- Unpaid = red in both the stat and the pill (~273/340). MENUNGGU payment = yellowL/orangeD; the antrean stat matches (both yellow is fine).
- Overflow: "SCAN TIKET TAMU"/"MULAI TURNAMEN" (~464-466): small buttons or stacked. "Belum bayar" stat label (~283): "Belum".

When done, run analyze, make sure your files are clean, then give the compact final report.

## Fix feed + streak findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these):
- `lib/features/feed/**`: pages, cubit, data repo, domain entities incl. AppNotification and FeedPost.
- `lib/features/profile/presentation/pages/streak_pages.dart`: StampsPage, ChallengesPage, StreakSavedPage etc.

Line numbers are approximate; re-read the code.

FEED (feed_pages.dart)
- Other people's avatar and name do nothing or only open the post. Wrap them in Pressable and call `showUserSheet(context, name: ..., subtitle: club/sport, sportId: ...)`:
  - feed card (~141, ~145)
  - J2 post detail author (~420, ~424)
  - comment avatars and names (~499-525)
- The `reactedBy` text "Dinda, Budi & 14 lainnya" (~493) looks like a link but does nothing. Open a reactors sheet grouped by emoji: reaction emoji + names. Use whatever reaction data the post has, and derive names reasonably if only counts exist.
- J2 share icon (~386) pushes R.story, which shows YOUR story. Reuse `_showPostMenu`'s SharePlus share for the post instead.
- J2 has no ••• menu. Add a `KIconButton(LucideIcons.ellipsis, onTap: () => _showPostMenu(context, post))`.
- The user's own comment avatar is hardcoded '🐥' on yellowL (~363). Render the user's ProfileAvatar. Find ProfileAvatarView, or how profile_pages renders `me.avatar`, and reuse that widget. If it is private to profile_pages, use the emoji/colour of `me.avatar` from core/entities/mascot.dart ProfileAvatar.
- Segment card (~477) pushes R.segment with no id. Add `segmentId` to FeedPost (seed the segment post with 'tanjakan-senayan') and push `'${R.segment}?id=${post.segmentId}'`.
- Notifications:
  - Targets are hardcoded ('rabu-malam', 'dinda-renang', ~564-572). Add `route` (String) to AppNotification and seed proper routes per notification. Tap marks read, then navigates. For tab routes (R.league, R.feed, R.clubs, R.profile) use `context.go`; for everything else use `push`.
  - Add `FeedCubit.markRead(id)`.
  - Add an empty state using MascotSays when the list is empty.
  - The streak alert card uses `Color(0xFFFFFAEB)` (~578) with a yellow border. Use streak orange: orangeL bg, orange border/icon.
- PostDetail (~372-377): when the post is not in `state.posts`, the FutureBuilder future is recreated every build and updates never show. Cache the future in initState. After a comment or reaction, refresh: e.g. add a FeedCubit method `byId` / keep a detail cache in state so reactions/comments on non-listed posts render.
- Streak banner (~101) always says "amankan hari ke-${streak+1}". When `me.lastActive` is today, show "Streak hari ini aman ✓" instead.
- KIRIM (~416) is enabled while the input is empty and is an outlined grey button. Use `hue: Hue.primary`, with onTap null when the text is empty (listen to the controller).
- Feed streak banner 🔥 (~95) renders dark on orange: `Emo(..., color: AppColors.white)`.
- Comment preview Row (~183): `Text('${c.author}:')` is unconstrained. Merge it into one `Flexible(Text.rich(...))` with maxLines 1/2 + ellipsis.
- feed_pages:545 and :606 use AppColors.blue for actions/links: switch to primary.
- feed_pages:570/:578: `context.push(R.league)` → `context.go(R.league)`.

STREAK PAGES (streak_pages.dart)
- KOLEKSI LANGKA badges (~177-190) cannot be tapped. Tap opens a sheet with name, criteria and progress; locked badges show the unlock criteria.
- Stamp day cells (~148-163) cannot be tapped. Tap opens a day summary sheet: sport emoji, name, "1 sesi tercatat", with a link to the activity if one exists, otherwise just the summary.
- Challenge cards (~243) have no onTap and no detail. Add a challenge detail sheet: description, progress, mini leaderboard of 3-5 names, and a GABUNG/KELUAR toggle.
- Challenge state:
  - `_joined` (~207, ~291) is local. Persist joined challenge ids with `sl<MeCubit>().setSetting('challenges', joinedIds.join(','))` and read them back with `state.text('challenges')`.
  - Joining makes the challenge appear under 'Diikuti'.
  - 'Selesai' tab (~218-221) is always empty, and filtering uses hardcoded indexes. Add `done`/`type` fields to the challenge model (local to this file) and filter by them. Seed 1 completed challenge.
- Share / export:
  - Header share and bottom EKSPOR (~122/123) both push R.story. Keep only one. EKSPOR pushes R.story with extra `{'type': 'stamps', 'month': ..., 'count': ...}`. StoryPage is owned by the activity agent and accepts `Object? extra`; it will render unknown or other maps as the default card, so this is safe.
- The "VARIAN: PUTUS" demo card (~66-81) always renders. Show it only when the streak actually broke: `me.streak == 0` and bestStreak > 0. Otherwise hide it.
- Calendar:
  - It starts at hardcoded `DateTime(2026,10)` (~112/119). Use `DateTime.now()` month.
  - Stamp data: keep the seed for the current month. Derive from `me.lastActive` / `me.stamps` where sensible.
  - Disable "next" past the current month (~128).
- Legend (~169) omits 🎾. Build it from `stamps.values.toSet()`, using `Sports` hue per emoji where possible.
- '+5 vs Sep' (~174) is hardcoded. Compute it from data, or drop the comparison if there is no previous-month data.
- Colours:
  - `Color(0xFFBEE9FF)` (~33, ~100) → `AppColors.ice`.
  - streak_pages:21 main CTA "AMANKAN STREAK HARI INI" uses `Hue.blue`. Make it the default primary, or orange (streak).
  - :291 GABUNG `Hue.blue` → primary.
  - :122 blue → primary.
  - Sport colours: Badminton is orange here but primary elsewhere. Use `Sports.byId(id).hue` / `sport.hue` everywhere in this file (stamps, challenges, legend).
- Overflow (~264-268): progress text + `note` across a Spacer. Wrap `note` in Flexible + ellipsis.
- Copy: use "Stempel" consistently, not "Stamp".

When done, run analyze, make sure your files are clean, then give the compact final report.

## Fix profile pages findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these):
- `lib/features/profile/presentation/pages/profile_pages.dart`
- `lib/features/profile/presentation/widgets/me_top_stats.dart`
- `lib/features/profile/domain/entities/gear.dart`
- `lib/features/profile/presentation/cubit/gear_cubit.dart`
- `lib/features/profile/data/gear_repository_impl.dart`
- `lib/features/wearable/**`, only if needed for the DevicesPage.

NOT streak_pages.dart (another agent owns it), and NOT me_cubit/user_profile (core-owned; their new API is in FIX_RULES).

YOU MUST CREATE two public classes in profile_pages.dart that the router already references:
- `HelpPage` (route R.help): FAQ (expandable KCards), "Chat CS via WhatsApp" (url_launcher `https://wa.me/...` with a placeholder number), and a feedback form (KInput multiline + KIRIM disabled when empty; pop + toast after send).
- `NotifPrefsPage` (route R.notifPrefs): per-category KToggles (Mabar, Chat klub, Kudoz & komentar, Liga, Streak, Promo), persisted with `context.read<MeCubit>().setSetting('notif_<key>', v)` and read back via `state.flag('notif_<key>', fallback: true)`.

THE USER ASKED "list hewan ada dimana?" GengPage (R.geng) is unreachable. Fix it:
- ProfilePage: add a prominent "Geng Gemoy" card right after the stat grid, with `onTap: () => context.push(R.geng)`. Show:
  - `MascotHead(animal: p.partner, stage: p.stage, ...)`
  - "Partner: {label} · {stage label}"
  - a `KPill('${p.adopted.length}/${Animal.values.length} hewan')`
  - a chevron
- Also add a "Lihat Geng Gemoy" link at the bottom of the sport switcher sheet in me_top_stats.dart (~37-58). Pop the sheet before pushing.

PROFILE PAGE
- "24 Mengikuti" / "31 Pengikut" (~92/94) are blue but cannot be tapped. Open a followers/following sheet (list of names, each with showUserSheet on tap). Use primary colour. Wrap in `Wrap(spacing: 12)` against overflow.
- "Buku Stempel" circles (~130-143) cannot be tapped: Pressable → R.stamps. Six fixed 50px circles overflow below ~332dp; use Expanded + AspectRatio, or Wrap. Use `Sports` hue for the stamp colours (`Sports.byId(id).hue`), not ad-hoc colours (🏃 is red here but purple elsewhere).
- Weekly bars / "Olahraga bulan ini" (~144-175): add a legend; derive the sport split from `p.sports` with `sport.hue`. Hardcoded 'Divisi 1', '23 sesi' and percentages: derive what you can from `p` (stamps, sports, streak). Keep anything that can't be derived, labelled as clearly as possible.
- Profile KSegmented (~99-114) is used as navigation and the selection never moves. Replace it with 3 KRow/tile links: Stempel → R.stamps, Rating Tanding → R.rating, Gear → R.gear. Also add explicit rows/tiles for Tantangan → R.challenges and Toko → R.shop, with `_Stat('💎', p.gems, 'Permata')` → R.shop.
- Profile stat emojis 🔥⚡🛡🏅 (~195) are untinted. Pass colours: 🔥 orange, ⚡ yellowD, 🛡 blue (Es Batu), 🏅 primary. Stat tiles must navigate where it makes sense: XP → challenges, streak → stamps, Es Batu → shop.
- Avatar:
  - `_bgOverride` (~31, ~264) is a global in-memory notifier, lost on restart. Use `me.setAvatarBg(color.toARGB32())` and `p.avatarBg`.
  - `_avatarBg` (~19-28) and `_bgChoices` (~235) copy token values: use the `AppColors.*L` names.
  - Picked camera/gallery photo (~249-252) is discarded: call `me.setPhoto(file.path)`.
  - ProfileAvatarView: show `Image.file(File(p.photoPath!))` in the circle when photoPath != null, with a "Hapus foto" link that calls setPhoto(null).

RATING PAGE (~333-384)
- Chips are hardcoded Badminton/Padel/PingPong. Build them from `p.sports`.
- Make data per sport, generated deterministically from the sport id (record, delta, chart values, history, level label = the user's `UserSport.level`).

SETTINGS
- 'Default aktivitas baru' (~776) shows blue 'Pengikut' with no picker. Add an onTap sheet with Publik / Pengikut / Hanya saya, persisted via `setSetting('visibility', ...)`, and show the current value.
- 'Bantuan & Masukan' (~781) → `context.push(R.help)`.
- 'Notifikasi lainnya' (~772) → `context.push(R.notifPrefs)`.
- 'Pengingat streak' (~770): make it tappable and open `showTimePicker`. Persist with `setSetting('reminderHour', h)` / `'reminderMinute'`, and call NotificationService `scheduleStreakReminder(hour: ...)` (read core/services/notification_service.dart for the signature). Use orange (streak) instead of red.
- `_reminder` toggle (~726): persist it with `setSetting('reminder', v)` and read it back.
- Keluar (~788) has no confirmation and no reset. Use showConfirmSheet, then `await me.signOut()`, then `context.go(R.welcome)`. Clear the GearCubit/FeedCubit state if they have reset methods; otherwise leave them.
- CAIRKAN (~754) only toasts. Withdraw sheet: bank/e-wallet chips, amount KInput (digits), quick chips 50rb/100rb/Semua, validation against `p.saldo`, then `me.withdraw(amount)`, pop and toast.

ACCOUNT PAGE
- NOMOR HP KField (~894) only toasts. Open a change-number sheet: new number input, KIRIM OTP, then 6-digit OTP input in the same sheet. On a valid code (any 6 digits except 000000), save via `updateAccount`. updateAccount has no phone param and you cannot edit MeCubit, so store it with `setSetting('pendingPhone', ...)` and note it in your report.
- OTP pill (~893) is green: use primaryL/primaryD.

DEVICES PAGE
- `_autoImport`/`_liveHr` (~923-924) are local: persist via setSetting.
- 'Terhubung' (~984) is green: use primary.

PRIVACY PAGE (~1120-1170)
- Toggles `_hideHr`/`_hideCal`/`_beacon`/`_contacts` (~1123-1126): persist via setSetting.
- 'UBAH' home zone (~1138) toasts "Geser pin". Open a zone-edit sheet:
  - radius chips 200 m / 500 m / 1 km, persisted with `setSetting('zoneRadius', m)`
  - an area picker (`showAreaPicker`) for the zone location, persisted with `setSetting('zoneArea', label)`
- '+ Tambah zona' (~1139) fakes adding. Open the same sheet and add to a persisted list (`setSetting('zones', joined string)`). Show the zones list with remove.
- Beacon contact pills (~1164) cannot be removed: tap opens a remove confirm.
- '+ Kontak' (~1165) adds a fake "Kontak 3": open a name + number sheet and persist the list via setSetting.
- Settings subtitle promises "blokir" but there is no list. Add a "Diblokir & dibisukan" section. If FeedCubit exposes muted authors, list them with BUKA; otherwise show an honest empty state ("Belum ada yang diblokir") and change the subtitle text accordingly.

GENG PAGE (~1175-1270)
- Adopted tiles are not tappable. Mascot detail sheet: sessions count, stage, sport, and "Jadikan partner" → `setActiveSport(sportId)` if the user plays a sport of that animal.
- Un-adopted tiles are not tappable. Sheet: "Main {sport} 1x terverifikasi untuk adopsi", with REKAM → `context.push(R.scan)` or R.gps for distance sports.
- `missing.take(8)` hides animals: show all.
- 'Adopsi Lagi' (~1238) pushes R.sports, the onboarding flow. DESTRUCTIVE: it overwrites the profile. Replace it with `showSportPicker(context, exclude: p.sports ids)`, then a level-choice sheet (SkillLevel chips), then `me.saveSport(UserSport(sport, level: lvl))`, then toast.
- Raw `TextStyle(fontSize:16)` emoji (~1266) → `Emo(..., size: 16)`.
- :1240-1244 blue → primary.

GEAR PAGE (~460-590)
- PENSIUNKAN (~550-580) is only shown in the default case. Pass `trailing: retire` to the sepatu and raket cards too.
- Gear cards (~586) are not tappable. Add an edit sheet: rename, set as default, delete with confirm. For rackets add "Senar baru ditarik hari ini" (reset restrungAt); for shoes add "Reset km". Add GearCubit methods as needed.
- PENGINGAT RESTRING (~575) fires a notification immediately and the state isn't reflected. Schedule it if NotificationService supports scheduling; otherwise persist a 'restringReminder_<id>' flag and toggle the button label (AKTIF ✓ / PENGINGAT RESTRING). Be honest in the toast.
- `Hue.blue` button (~575) → primary.
- Overflow (~560-564): the km text and "Waktunya cari pengganti" sit across a Spacer. Wrap the caption in Flexible + ellipsis.
- `GearKind.lainnya` defaults to sport 'lari' while its hint is "Kacamata renang" (gear.dart:9): fix it to 'renang'.

OTHER COLOURS in profile_pages
- Blue for actions/links → primary: :314-315, :475, :495, :531, :776, :1165.
- Es Batu stays blue. Permata is purple wherever it appears in your files.

When done, run analyze, make sure your files are clean, then give the compact final report.

## Fix goyang + shop + misc findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these):
- `lib/features/goyang/**` (pages, cubit, domain)
- `lib/features/shop/**` (misc_pages.dart: ErrorPage, ShopPage, VenuePage)

Line numbers are approximate; re-read the code. The shake haptic was already moved out of GoyangCubit into the tab shell. Don't re-add it.

REQUIRED API CHANGES
- The router now calls `VenuePage(id: s.uri.queryParameters['id'])`. Add `final String? id` to VenuePage and use `Venues.byId(id)` (core/widgets/sheets.dart) for the name, area and price.
- The router's errorPageBuilder now passes `ErrorPage(variant: 'notFound')`. Handle the 'notFound' variant (title "Halaman nggak ketemu", mascot, KEMBALI KE BERANDA → go(R.feed)).

GOYANG (goyang_pages.dart)
- :113 "UBAH" pushes R.venue, which returns nothing, and `GoyangInvite.copyWith` (goyang.dart:72) has no venue.
  - Add `venue` to copyWith.
  - UBAH → `showVenuePicker(context, current: inv.venue)`, then `cubit.updateInvite(inv.copyWith(venue: v))`.
  - Enlarge the hit area (Padding all 8).
- :116-121 + :147 "AJAK LAGI" stacks a second lobby. Don't push the lobby when already on it: pass a `fromLobby` flag to showGoyangSheet, or check the current location via `GoRouter.of(context).routerDelegate.currentConfiguration.uri.path`. Note showGoyangSheet is also called by the tab shell in core/router/app_router.dart as `showGoyangSheet(context)`, so keep that signature working (optional named params only).
- :141-144: system back doesn't stop the lobby timers. Wrap in `PopScope(onPopInvokedWithResult: (did, _) { if (did) cubit.endLobby(); })`, and call `endLobby()` before pushReplacement in "JADIKAN MABAR" (:146).
- Invite page (:246, :249-252, :279): close and "NANTI" use `context.pop()`. Use `context.canPop() ? context.pop() : context.go(R.feed)`.
- Jadi page:
  - :416-419: the header X does go(R.feed) but system back pops. Add `PopScope(canPop: false, onPopInvokedWithResult: (_, _) => context.go(R.feed))`.
  - "BAYAR BAGIANKU" pushes `R.pay('rabu-malam')`, a different session and amount. Make the payment honest for the goyang invite: open a payment sheet for "Bagianmu Rp30.000" (the amount from the invite/cubit) with a QRIS-style confirm. On success mark it paid in GoyangCubit state and show "LUNAS ✓". Don't route to an unrelated session.
- :449 "RUTE" opens VenuePage for the wrong venue. Open maps with url_launcher (`https://www.google.com/maps/search/?api=1&query=<venue name encoded>`). Enlarge the hit area.
- :352 "SIMPAN & CHECK-IN" goes to R.done without recording. Call `sl<MeCubit>().recordActivity(source: <the appropriate verified/casual ActivitySource>, sportId: <invite sport id>)` first. Read ActivitySource in features/profile/domain/usecases/streak_rules.dart or wherever it is defined.
- GoyangBarengPage (:328) is unreachable. Add entry points:
  - a "GOYANG BARENG" button on the Jadi page ("Goyang bareng di lapangan buat check-in bareng") → R.goyangBareng
  - and/or in GoyangSettingsPage. GoyangSettingsPage is in profile_pages, which is not yours, so put it on the Jadi page and the lobby.
- :398-400: Bareng KRows look tappable but aren't. "Saling ikuti" becomes a real action (toggle + `sl<MeCubit>().setFollowing(true)` + toast). Make the other rows real (tap → showUserSheet for people), or plain non-row text.
- Colours:
  - goyang_cubit.dart:78-83 stores ARGB ints rendered through `_c()` (:129). Store a hue key, or use token Colors directly (AppColors.*), and remove `_c`.
  - :155 lobby MascotHead `bg: AppColors.blueL` inside the orange card → AppColors.white.
  - :176 KBanner with `fg: AppColors.blue` on blueL has low contrast → `KBanner.info(...)`.
  - :91, :95, :540, :546: goyang chips → `hue: Hue.orange` (goyang = orange feature colour).
- Overflow:
  - :94-96 and :545-547: 3-column KSplit chips truncate "Nanti malam", "Semua teman", "Teman dekat". Use Wrap or shorter labels.
  - :198/:212: KPill holding `r.note` → Flexible/ConstrainedBox(maxWidth 120).

SHOP (misc_pages.dart ShopPage)
- :167-187: only the price button works. Card tap → detail/confirm KSheet ("Beli X · 💎N?" with a description), and route the mini-button through the same sheet. After buying, pop and toast. Handle insufficient gems: offer a "Kumpulkan Permata" hint.
- :86: "Boost XP 2x" is under Pelindung and "Rute Pelangi" (:85) under Bingkai. Fix the categories.
- Permata colour: purple (not blueD at :123). Es Batu stays blue.
- Overflow:
  - :123 gem counter Row → Flexible/FittedBox.
  - :156-187 grid name text → maxLines 1 + ellipsis, or a fixed mainAxisExtent.

VENUE (misc_pages.dart VenuePage)
- :214 "PESAN LAPANGAN" only toasts, and the price is fixed. Booking confirm sheet: court, slot, price from `Venues.byId(id).pricePerHour`, then BAYAR. On confirm: `sl<MeCubit>()` has no booking API, so add a simple local booked state (persist booked slots with `sl<MeCubit>().setSetting('booking_<venueId>', '<court>|<slot>')`). Show "DIPESAN ✓", pop and toast.
- :222 back arrow uses `context.pop()`, which throws with no history. Use canPop ? pop : go(R.feed).
- :241: hardcoded "GOR Senayan Badminton" → the venue name.
- :211-222: double top inset (KPage already has SafeArea). Remove the extra `+ top`, or set KPage safeTop off if KPage has such a param (read core/widgets/page.dart; you can't edit it).
- :249-265: slot text → FittedBox(scaleDown).
- Colours: :231 "GS" logo green → primary (and derive the initials from the venue name). :268 IconBox greenL/green → primaryL/primary. :303 `Colors.white` → AppColors.white. The court hero illustrations at :219/:306 may stay green.

ERROR (misc_pages.dart ErrorPage)
- :62: variant buttons only toast. "CARI MABAR" → `context.push(R.explore)`. "KIRIM ULANG" → reuse `_retry`.
- :39 + :24-33: "COBA LAGI" can never succeed. For server/notFound, go(R.feed); for offline, re-check connectivity (simulate with a delay) and pop if possible, otherwise go(R.feed).
- :48-49: hero copy ignores the variant. Key the title, body and mascot on the variant (offline / server / notFound / any others present).
- :57: non-selected cards lose their border → AppColors.line.

When done, run analyze, make sure your files are clean, then give the compact final report.

## Fix onboarding flow findings

You are fixing audit findings in the Klubby Flutter app. FIRST read `C:\Users\achma\AppData\Local\Temp\claude\D--Bismillah-jadi-kaya-dunia-akhirat-clubus\7ab2341b-9f2e-4590-a929-dd772cf429b0\scratchpad\FIX_RULES.md` fully and follow it.

YOUR FILES (only these): `lib/features/onboarding/**` (welcome_pages.dart, signup_pages.dart, setup_pages.dart, cubit/onboarding_cubit.dart and anything else in that folder). Line numbers are approximate; re-read the code.

Findings to fix:

DEAD / WRONG TAPS
- signup_pages LocationPage, about line 320: the KCard with 'UBAH' has no onTap. Make it open `showAreaPicker(context, current: d.area)`, then call `c.setArea`. Read the cubit before awaiting. Remove the KInput that calls setArea on every keystroke past 3 characters; the picker replaces it.
- AboutPage UNGGAH FOTO (~245) only toasts. Use ImagePicker like `AvatarPage._pick` in features/profile/presentation/pages/profile_pages.dart (~249). Store the path in the onboarding draft (add `photoPath` to OnboardingDraft), show the picked photo with `Image.file` in the circle, and pass it to MeCubit on ReadyPage via `sl<MeCubit>().setPhoto(path)` after `completeOnboarding`.
- SignupPage Google/Apple buttons (~60) skip auth straight to R.about. Hide Apple on non-iOS (`Theme.of(context).platform == TargetPlatform.iOS`). Use a proper icon for Google (LucideIcons has no brand icons; use a letter 'G' in a circle, not a globe). Keep the flow, but show a loading state, then continue.
- welcome_pages "SAYA SUDAH PUNYA AKUN" (~278) runs the same signup flow. Add a login mode: push `'${R.signup}?mode=login'`. SignupPage reads `GoRouterState.of(context).uri.queryParameters['mode']` and changes its title to "Masuk". Store `login` in the cubit. After OTP succeeds in login mode, call `sl<ProfileRepository>().setOnboarded(true)` (or the equivalent via MeCubit: `completeOnboarding` with the existing profile values, e.g. `name: sl<MeCubit>().state.name`), then `context.go(R.feed)`.
- The terms/privacy text (~signup 63) is not tappable. Make "Syarat" and "Privasi" tappable with a TapGestureRecognizer, or Pressable spans, each opening a KSheet with a short summary.
- SignupPage KHeader X (~41) does nothing when it can't pop. Use `onLeading: () => context.canPop() ? context.pop() : context.go(R.welcome)`.
- setup_pages SportsPage MINTA OLAHRAGA (~78) only toasts. Open a sheet with a KInput (sport name) and a KIRIM button that is disabled while empty. Pop the sheet, then toast thanks.
- setup_pages synced card "cocokkan ke mabar?" (~449) has no action. Make it real: tap shows a small sheet explaining that the activity will be matched to the next mabar, with OK. Also, the card is hardcoded ('Xiaomi Band 8', '2 mnt lalu'): drive it from `WearableCubit` state (look at features/wearable/presentation/cubit/wearable_cubit.dart: watchPaired, platformHealth, lastSync or similar). Show it only when something is actually connected.
- setup_pages `_ClubJoinCard` (~264) has no onTap. KCard onTap should push `R.club(club.id)`.
- setup_pages JoinClubs BUAT KLUB (~223) pushes R.newClub mid-onboarding. Keep it, but make sure returning from NewClub lands back on JoinClubs. The NewClub page pops itself after creating; check club_pages but don't edit it. If it uses `go`, report that instead.

BROKEN STATE
- Remove the demo phone fallback (signup ~33). LANJUT stays disabled until a valid number (≥9 digits) is entered. Use digits-only input formatters.
- OTP:
  - Add `resetOtp()` to the cubit.
  - Resend resets attempts and clears the field.
  - Clear the field on a wrong code.
  - At 0 attempts, lock input and show "Coba lagi dalam 30 detik" with a countdown.
  - OTP boxes use primary, not blue.
- `useCurrentLocation` sets a hardcoded area. Use `LocationService().current()` (core/services/location_service.dart) and `Areas.nearest(p.lat, p.lng).label`. Handle denial with a message.
- The default area should be '' and the default gender null/unselected. LocationPage LANJUT is disabled until an area is set; AboutPage requires a gender choice or allows 'rahasia' explicitly.
- FlatMap on LocationPage ignores the radius. Pass the radius to it if FlatMap supports a radius param (read core/widgets/flat_map.dart). Otherwise show the radius visually with an overlay circle sized by radius in the page.
- Seeded sports (badminton menengah, padel pemula): start with an empty list.
- JoinClubs list ignores radiusKm. Filter `clubs.nearby` by `c.distanceKm <= d.radiusKm`. Also filter to the user's chosen sports when "Semua" is selected? No: Semua = all within radius. Show an empty state when nothing matches.
- AboutPage:
  - Username field gets formatters `[a-z0-9_.]` and max 20.
  - `setName`'s username argument is a no-op: fix it.
  - LANJUT validates name ≥ 2 chars and username ≥ 3.
- ReadyPage falls back to 'Budi Santoso'/'budirenang', and initials fall back to 'BS'. Remove the fallbacks; validation guarantees the values.
- Permission toggles:
  - Notification and Goyang toggles are not saved. Call `sl<GoyangCubit>().updateSettings(...)` with enabled = d.goyang; check GoyangCubit's API for the right call.
  - Save notifications with `sl<MeCubit>().setSetting('notifications', d.notifications)` after completeOnboarding, or on toggle.
  - Do not call `startListening` during onboarding; the tab shell starts it.
  - The IZINKAN label changes to "LANJUT" when both toggles are off.
- Make progress values evenly spaced across the steps. Steps: signup .1, otp .2, about .3, location .4, sports .5, clubs .6, permissions .7, watch .85, ready done. Use whatever is in the code, kept monotonic and even.

COLOURS
- welcome_pages:127 `Color(0xFFFFD9A8)` → `AppColors.orangeM`.
- Replace `AppColors.blue` / `Hue.blue` used for actions, selection and links with the primary family, at least at:
  - welcome:124 and :278 (textColor)
  - signup:189, :245, :309-312, :320, and the OTP boxes at :135-140
  - setup:75 (the IconBox for MINTA can be primary), :116-121 (sport tile selected icon/text → primary/primaryD), :142-143 (level sheet header → `sport.hue` light/base)
- Notification hue: yellow here, blue in settings. Use yellow (bell = yellow) here and keep it.
- GABUNG (setup ~262) is outlined grey while MINTA is filled purple. GABUNG uses `hue: Hue.primary`.
- "GABUNG ✓" pill (~256) and "TERHUBUNG" pill (~391), plus the connected-watch card (~440-447), use green as success. Switch them to primaryL/primaryD. The Health Connect brand icon can stay green.

OVERFLOW
- ReadyPage (setup ~496-539) and WelcomePage (welcome ~264-280) are non-scrolling Columns with Spacers. Make them scroll-safe: LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight: c.maxHeight) + IntrinsicHeight.
- `_IntroSlide` (welcome ~196-222) can overflow. Same treatment, or Flexible + FittedBox on the mascot.
- Fixed-height sport tiles (setup ~53, ~69, ~109-125): let the height grow (use minHeight via ConstrainedBox, or drop the height). Text maxLines stays.
- Chip strips with `SizedBox(height: 44)` (setup ~56, ~225): use height 48 so the chunky border isn't clipped, or a Wrap.
- `_IntroChip` (welcome ~242-248) has no width limit. Add a ConstrainedBox maxWidth + ellipsis.
- ReadyPage partner strip: leave it as is. Geng is linked from Profile by another agent.

When done, run analyze and make sure your files are clean, then give the compact final report.
