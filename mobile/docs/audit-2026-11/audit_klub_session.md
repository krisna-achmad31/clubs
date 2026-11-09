# Klubby audit: Klub tab + Sessions/Mabar + Hosting

Scope: `lib/features/club/**`, `lib/features/session/**`, plus the touch points they hit (`core/router`, `core/di/injector.dart`, `MeCubit.addSaldo/recordActivity`, `ScanPage._handle`, `VenuePage`, record sheet, feed notifications).
Read-only audit. Line numbers refer to the files as they are now. Today = 2026-11-07, so the seed sessions dated 29 Okt and 1 Nov are already in the past. The 9 Nov session is not.

Legend: **[BUG]** confirmed by reading the code · **[MOCK]** intentional demo/seed behaviour that still affects testing · Severity H/M/L.

---

## 0. Top findings (fix first)

| # | Sev | Finding |
|---|-----|---------|
| 1 | H | **Saldo money loop.** "Paying" never deducts saldo, but cancelling refunds into the persisted `MeCubit.saldo`, and the RSVP can be made again. You can grow saldo without limit and then use "Cairkan saldo". |
| 2 | H | **Clubs, sessions and RSVPs are all in memory.** On restart you lose the clubs you joined in onboarding, clubs you created, created sessions, payments and cancellations. Seed RSVPs come back. Persisted MeCubit data (saldo, check-in flags, pro_plan) then points at state that no longer exists. |
| 3 | H | **"BUAT MABAR" on a club page doesn't pass the club.** `SessionDraft.clubId` defaults to `'smash'`, so a session started from your new club is filed under PB Smash Ceria unless you change the Klub field. |
| 4 | M | **A successful payment doesn't add you to `participants`.** The host's Kelola / Check-in lists, the avatars and the "Hadir x/y" count never include paying users. Your ticket code (a number) can't be entered in the host's guest-code box (expects `G<n>`). |
| 5 | M | **QR check-in is not tied to the RSVP or the session roster.** It works for sessions you never joined or that were cancelled. The rotating nonce and the time/distance checks are never applied. It doesn't mark you present for the host. It records duration 0, so 0 league minutes. |
| 6 | M | **Cancelling with guests leaks slots when a waitlist exists.** `filled` is unchanged but only 1 person is promoted. |
| 7 | M | **The host's REFUND DEMO followed by HAPUS lowers `filled` twice.** `markParticipant` also wipes the `refunded`/`noShow` flags. |
| 8 | M | **Claim page gives a free ticket.** It turns any RSVP status into `joined`, with no payment, no capacity check and no `filled` change. It defaults to the hardcoded `'rabu-malam'`. |
| 9 | M | **Shared links are dead.** `https://klubby.id/k/<code>` and `/m/<id>` are shared everywhere, but there's no https intent-filter and no `/k/:code` route. Only `klubby://` is registered, and nothing handles `klubby://checkin/...` as a route. |
| 10 | M | **Past and cancelled sessions are never filtered** in the Klub tab "Mabar kamu minggu ini", the club Jadwal, Explore Mabar or Venue. You can join and pay for a session that already happened. |

---

## 1. Missing flows / dead ends / hardcoded ids

| Sev | Location | What happens | Should happen |
|---|---|---|---|
| H [BUG] | `club_pages.dart:669` → `R.hostNew`; `mabar_session.dart:305` (`clubId = 'smash'`), `host_flow_pages.dart:26-30` | The BUAT MABAR button on any club page opens HostNew with no club. The draft is pre-filled with `smash`. The user is admin of smash in the seed, so `club != null` and publish is enabled right away, filing the session under PB Smash Ceria. Sport (`badminton`) and venue (`GOR Mahakam, Lapangan 2`) are hardcoded the same way. | Pass `?club=<id>` (and default the sport to `club.sportId`). Read it in HostNewPage. |
| M [BUG] | `app_router.dart:134` | `/claim` with no `id` falls back to `'rabu-malam'`. | Show not-found, or require an id. |
| M [BUG] | `session_flow_pages.dart:701-704`, `sessions_cubit.dart:569-573` | `claimTicket` sets `status: joined, ticketNo: r.ticketNo ?? 1` for any status (none/waiting/cancelled). There's no payment, no `filled` update, no `waiting` decrement and no capacity/past check. Every claimed ticket is #1. It also converts the **device user's own** RSVP, not a guest ticket. `Hai ${r.guests.first}` (`:668`) greets the user's own guest name. | Claim a guest/web RSVP record: check capacity, take a slot, assign a unique ticket no. |
| M [BUG] | AndroidManifest `<data android:scheme="klubby"/>` only; shared links at `club_pages.dart:559`, `club_actions.dart:110`, `club_invite.dart:100,344,352`, `host_flow_pages.dart:311`, `session_pages.dart:483` | All invite/RSVP links are `https://klubby.id/k/<code>` or `/m/<id>`. There's no https/App Links intent filter, and no route for `/k/:code` at all (the router has no club-by-code lookup). The manifest comment promises `klubby://checkin/<session>` and `klubby://session/<id>`. Neither is a go_router path: `/checkin/...` doesn't exist, and with a custom scheme the "host" part (`session`) isn't part of `uri.path`, so this likely lands on the not-found page (verify on device). | Add App Links plus a `/k/:code` → club route, and a redirect for `klubby://` hosts. |
| M [BUG] | `session_pages.dart:209` (`context.pop()`), `club_pages.dart:1007` (chat back) | Back calls `pop()` without checking `canPop`. If the page is the first route (deep link `/m/:id`, or after a `go`), it's a dead end. ClubPage (`:548`) does it right (`canPop ? pop : go(R.clubs)`). | Use the same `canPop` fallback. |
| L [BUG] | `session_flow_pages.dart:261-265` | On the ticket, "LIHAT DETAIL MABAR" just pops. From the Klub tab "Mabar kamu" card (`club_pages.dart:146`) or the feed notification it goes back to the Klub tab/feed, not to the session detail. | `pushReplacement(R.session(id))`. |
| L [BUG] | `host_flow_pages.dart:187-194` | "BUAT KLUB" inside the host club picker pushes NewClub. The returned club is ignored and the draft keeps `smash`. | `await push<Club>`, then set `clubId`. |
| L [MOCK] | `feed_repository_impl.dart:271,281` | Notifications hardcode `R.slot('padel-pagi')` and `R.ticket('rabu-malam')`. SlotPage always shows "Kamu dapat slot!" with confetti, even when the user isn't waiting (`promote` is a no-op). The n4 body says Rp35.000, but the seed RSVP amount is Rp72.000 (`sessions_cubit.dart:443`). | Gate the SlotPage copy on `r.status == pendingPayment`. |
| L [BUG] | `club_pages.dart:1720` | The "Klub Pro" banner on **Buat Klub** pushes `/pro` with no club. ProPage then picks the first admin club (`club_actions.dart:624-629`), i.e. PB Smash Ceria, so the user can "activate Pro" for a different club from the create screen. | Hide it, or open info-only mode when there's no `club`. |
| L [BUG] | `shop_flow_pages.dart:370`, `sheets.dart:158` | `Venues.byId(null or unknown)` silently falls back to GOR Senayan. The session detail has no link to the venue page ("PETUNJUK ARAH" opens Google Maps), so the venue page is only reachable from Explore → Venue. | Not-found state, plus a link from the session. |
| L | Routes defined but only reachable indirectly | `R.kas(id)` is only pushed from the non-member gate (`club_actions.dart:522`); members use the embedded tab. `R.claim` / `R.claimLink` are never pushed in-app (deep-link only, and deep links are broken, see above). | OK if intended; otherwise the Claim flow is untestable on a device without adb. |
| L [MOCK] | `club_pages.dart:745-749`, `club_actions.dart:3-27` | The member list is generated ("Anggota contoh"). A non-admin member doesn't see themselves in it (`if (club.admin) me`). | — |
| L [MOCK] | `club_actions.dart:148-153` | Club report is only stored locally. | — |

---

## 2. Disconnected features / sync

| Sev | Location | What happens | Should happen |
|---|---|---|---|
| H [BUG] | `sessions_cubit.dart:486-509` (paid), `:579-615` (cancel), `session_flow_pages.dart:333`, `host_flow_pages.dart:706-709`, `me_cubit.dart:245` | **The payment side never touches saldo or the kas, but the refund side credits `MeCubit.saldo`, which is persisted.** Cancelling before the deadline refunds `fee × people`. Host-cancel refunds `fee × (1+guests)` even after the deadline. `startPayment` allows a new RSVP after `cancelled`. Result: join → simulate pay → cancel → repeat = unlimited saldo, which can then be withdrawn (`me_cubit.dart:88`, "Cairkan saldo" in profile_helpers). It also survives a restart: the seed RSVP (`rabu-malam` joined) comes back and can be cancelled again. | Either deduct saldo or record the payment on pay and only refund what was recorded, or don't credit saldo at all in demo mode. |
| M [BUG] | `sessions_cubit.dart:486-509` | `paid()` updates `filled` and the RSVP only. It never adds a `Participant` (so HostManage, HostQr "Hadir x/y" and the AvatarStack stay on the seed list), never appends to `s.waitlist` names, and posts nothing to the club kas. | Add a participant (name from MeCubit, `via: 'APP'`, `status: lunas`) and a kas entry `iuran`. |
| M [BUG] | `sessions_cubit.dart:521-536` | `joinWaitlist` increments `waiting` but doesn't add the user to `s.waitlist`. HostManage then shows 3 names under ANTREAN while the header says "4 antrean" (`host_flow_pages.dart:394, 484`). | Keep the names list and the count in sync. |
| M [BUG] | `activity_pages.dart:184-207` (ScanPage) + `activity_repository_impl.dart:78-88` | QR check-in only parses `klubby://checkin/<id>`. It doesn't check that the user has a `joined` RSVP, that the session isn't cancelled, the nonce (`host_flow_pages.dart:505, 576` rotates for nothing), or the time window or distance (`CheckInError.notOpenYet`/`tooFar` are never thrown). It doesn't call `SessionsCubit.markParticipant(present)`. `recordActivity(source: qr)` gets no `duration`, so `bump(leagueMinutesKey, 0)` and only attendance counts (`me_cubit.dart:200-202`). | Validate the RSVP, cancellation, nonce window and time. Mark the participant present. Pass the session duration (`scheduledEnd - scheduledStart`). |
| M [BUG] | `session_flow_pages.dart:289-296` vs `host_flow_pages.dart:522-554` | The ticket shows "Kode untuk host: 9" and a QR `klubby://ticket/<id>/<no>`. The host's code entry only accepts `G<n>` (index into `participants`, which doesn't contain the payer). The ScanPage rejects `ticket` URIs (host != `checkin`). So the ticket can't be used for check-in. | Use one code scheme, and give the host a way to scan tickets. |
| M [BUG] | `host_flow_pages.dart:412`, `:540-545` | Guest codes are the list index (`G${i+1}`). After HAPUS removes a participant every later code shifts, so codes already handed out now point at someone else. | Use stable ids. |
| M [BUG] | `club_repository_impl.dart:100-102` | `nearby()` returns only `[smash, padelPagi, futsalFc, hiu]`. Created clubs (`_created`) and `lariGbk` are never discoverable by others. They show in Explore only for the creator, because Explore merges `mine` (`club_actions.dart:207-210`). If the creator leaves their own club (`club_actions.dart:158-174`, allowed even for the sole admin), the club vanishes from every list, but its sessions still show in Explore → Mabar. | Include `_created` in nearby. Block the last admin from leaving. |
| M [BUG] | `injector.dart:59-62`, `me_cubit.dart:94-98` | `signOut` clears only the profile. The singleton `ClubsCubit`/`SessionsCubit` (and the in-memory repos) keep the previous user's joined/created clubs, RSVPs and tickets for the next account in the same app run. | Reset these cubits/repos on sign-out. |
| L [BUG] | `club_pages.dart:47-48, 71-80` vs `record_sheet.dart:14-26` | The record sheet filters `joined && !cancelled && scheduledStart > now`. The Klub tab "MABAR KAMU MINGGU INI" has no date/week filter, so past sessions (29 Okt, 1 Nov) keep showing "LUNAS ✓". | Use the same filter (upcoming, this week). |
| L [BUG] | `club_pages.dart:454-460, 671-678`; `club_actions.dart:218-231`; `shop_flow_pages.dart:376-382` | The club Jadwal tab lists every session for the club, including past and cancelled ones. A cancelled `IKUT` session renders an orange **ANTRE** CTA because `full` returns true when `cancelled` (`mabar_session.dart:163`, `club_pages.dart:841`). Explore → Mabar hides cancelled ones but not past ones. The Venue page shows both. | Filter upcoming, and give cancelled sessions a "DIBATALKAN" label. |
| L [BUG] | `session_pages.dart:165-194` | The Join/Waitlist CTA ignores `scheduledStart`. You can join, pay and get a ticket for "Rabu 29 Okt" today. | Disable it when `scheduledEnd < now`. |
| L [MOCK] | `club_pages.dart:283`, `clubs_cubit.dart:400-407` | Approval clubs: "MINTA" puts the id into `pending` (cubit memory). Nothing ever approves it, it can't be withdrawn, and it's lost on restart. | — |
| L [MOCK] | Profile | The profile has no club count, so there's nothing to sync. The League tab does read `ClubsCubit.mine` (`league_pages.dart:105`), so joining or leaving a club does propagate there. | — |

---

## 3. Calculation flows

| Sev | Location | What happens | Should happen |
|---|---|---|---|
| M [BUG] | `sessions_cubit.dart:604-611` | Full cancel with `refill = waiting>0 && autoWaitlist`: `filled` is left unchanged and `waiting -= 1`. If the RSVP had guests (`people > 1`), only one waitlister is promoted but all `people` slots stay counted. Example: rabu-malam seed (you + Andi): after cancel it's still 12/12 with 2 antrean, though only 1 seat was refilled. | `filled -= people - min(people, waiting)`; `waiting -= min(people, waiting)`. |
| M [BUG] | `sessions_cubit.dart:669-683` + `host_flow_pages.dart:446-477` | REFUND DEMO calls `removeParticipant(refund: true)`: `filled -= 1` and the participant is **kept** (flag `refunded`). HAPUS is still offered for that row (no `!p.refunded` guard). Tapping it removes the participant and decrements `filled` **again**. Participants count and `filled` drift apart. | Decrement only once. Hide HAPUS for refunded rows, or don't decrement there. |
| M [BUG] | `sessions_cubit.dart:624-650` | `markParticipant` rebuilds `Participant(...)` by hand and drops `refunded`, `noShow` and `waitingLabel`. Tapping a refunded participant on HostQr (`host_flow_pages.dart:611-613` only checks `present`) turns them back into a normal paid attendee. TANDAI TUNAI after "Tutup & no-show" clears `noShow`. | Use `p.copyWith(status:, present:)`. |
| L [BUG] | `sessions_cubit.dart:494-508` | `paid()` for a promoted waitlister uses `wasHolding = s.full && r.queue != null`. If the session became not-full in the meantime (host HAPUS/refund), `filled += people` but `waiting` isn't decremented (the user leaves the queue but is still counted). `ticketNo` for a holder is `s.filled` (e.g. 8), which duplicates the last seat number. | Always decrement `waiting` for a promoted RSVP. Assign the next free ticket number. |
| L [BUG] | `sessions_cubit.dart:460-483` | `startPayment` doesn't reserve the seat (`filled` is unchanged during the 10-minute hold), and `paid()` silently clamps `filled` to `slots`, so oversell is hidden instead of rejected. Single-user demo, but the logic is wrong for real use. | Reserve on hold, release on expire. |
| L [BUG] | `sessions_cubit.dart:589-602` | Guest-only cancel after the deadline: refund 0, but `amount` is still reduced by `fee × guests`, so the ticket shows a "Total demo" lower than what was paid. | Only reduce when refunding. |
| L [design] | `mabar_session.dart:290-294`, `sessions_cubit.dart:613-614` | The service fee Rp2.000 is charged even when the fee is Rp0 (host option `'0'`, `host_flow_pages.dart:214`), so a free mabar costs Rp2.000. The refund excludes the service fee (stated in the UI, `session_flow_pages.dart:360`). `offerToWaitlist` refunds just `s.fee` even if you had guests. `Fmt.rpShort(0)` renders "Rp0rb". | Waive the service fee when fee=0. Refund per seat refilled. |
| L [BUG] | `session_flow_pages.dart:431-437` | Expired → COBA LAGI restarts with `startPayment(id, [])`, which silently drops the guests chosen before. If it returns false, there's no feedback. | Reopen the join sheet. |
| L [BUG] | `mabar_session.dart:133-146`, `session_pages.dart:39-54` | Seed sessions have no year: `scheduledStart` and `_pastDeadline` assume `DateTime.now().year`. Seed dates flip between past and future depending on the device date. `_pastDeadline`'s regex doesn't match the `Fmt.dayDate` format ("Rab, 29 Okt · 19.00"). That's harmless today only because created and rescheduled sessions carry `deadlineAt`. | Store a `DateTime` for every session. |
| L [BUG] | `session_repository_impl.dart:162-165,182` | The session id is a slug of the title. A title with no ASCII letters (e.g. "🏸🔥" or Arabic script) gives id `''`, so `R.hostPublished('')` = `/host//published` and `R.session('')` both hit the not-found page, while the session is stored under key `''`. Recreating the same title after a restart reuses the id, and the persisted `checkin_<id>` flag (`activity_pages.dart:191`) then blocks check-in ("sudah check-in"). | Use a generated id (timestamp/uuid). |
| L [BUG] | `host_flow_pages.dart:648-656`, `sheets.dart:207` | Reschedule allows dates from yesterday and has no "must be in the future" check (unlike `_save` at `:72`). | Validate. |
| L [BUG] | `club_actions.dart:428-435` | TARIK DANA with no payout opens the payout sheet, saves, then `return`s, so the user has to tap again. | Continue to the amount sheet. |
| L [MOCK] | `club_repository_impl.dart:317-356`, `club.dart:244-251` | Every non-created club shows the same seed kas (1.240.000, entries dated Okt) under the current month name. `add()` adds to `monthIn/Out` regardless of month. The weekly arrays are never updated (and unused in KasPage). Session payments, refunds and host refunds never post to the kas. | Feed mabar income into the kas. |
| L [BUG] | `club_repository_impl.dart:230`, `club_pages.dart:197` | The created club code is `initials+'01'`, so it isn't unique (two "Smash Ceria" clubs both get `SC01`). A created club has `schedule=''`, so its Klubku row reads " · 1 anggota". | — |

Checked and OK: `open = (slots-filled).clamp`, the `Fees.total` breakdown (Join sheet = Pay page = Slot page), the join sheet guest max `guestMax.clamp(0, open-1)`, kas `addKas` rejecting a negative balance (UI also guards `amount <= balance`), `join`/`leave` member ±1 with clamp, `addMember` dedupe, the HostQr rotate countdown aligning with the 30 s nonce, and the Fmt.rp/group formatting.

---

## 4. Persistence (what's lost on restart)

`ClubRepositoryImpl` and `SessionRepositoryImpl` are pure in-memory (`injector.dart:53-54`, no SharedPreferences use under `features/club` or `features/session`). `SessionsCubit.load()` re-seeds RSVPs (`sessions_cubit.dart:431-449`).

| Sev | Lost on restart | Consequence |
|---|---|---|
| H | Joined clubs (`_joined` resets to `{smash, padelpagi}`), including the clubs picked in onboarding (`setup_pages.dart:483-505`) | After onboarding is done (persisted in MeCubit) the user reopens the app as a member of 2 seed clubs, and as **admin** of PB Smash Ceria, whatever they chose. |
| H | Created clubs, their logo path, payout, added members, kas, chat | The club the user built is gone. Any session hosted for it is gone too. |
| H | Created sessions, `filled`/`waiting`, participants marks, cancellations, reschedules, all RSVPs/tickets | Paid tickets disappear. Cancelled seed RSVPs come back (feeds the saldo loop in finding 1). |
| M | `club.pro` (in-memory patch) while `pro_plan_<club>` **is** persisted in MeCubit settings (`club_actions.dart:648-652`) | The Pro trial disappears (CSV export locked again) although the setting says it's active. |
| L | Chat messages, unread counts (smash comes back to 5), declined invite (futsal invite reappears), pending approvals | — |
| — | Persisted (via MeCubit): saldo, `checkin_<sessionId>` flags, venue bookings, club report, following | These now point at non-persisted entities (see the slug-id clash and the saldo loop). |

---

## 5. Manual test cases (real device)

Preconditions: fresh install, finish onboarding. Note the device date. Seed sessions: Rabu Malam (29 Okt, full 12/12, 3 waiting, you joined + guest Andi), Sabtu Pagi (1 Nov, 4/16), Americano (Min 9 Nov 15.00, 8/16, deadline Sab 8 Nov 15.00), Padel Pagi (full 8/8, you are queue #4).

1. **Onboarding joins persist.** Onboarding → Gabung klub: join only "Klub Hiu Jakarta". Finish, then check the Klub tab. Kill the app and reopen.
   *Expected:* Klubku shows Hiu after the restart. *Current:* shows PB Smash Ceria + Padel Pagi; Hiu is gone.
2. **Saldo loop.** Note Profil saldo. Klub → PB Smash Ceria → Americano → GABUNG → agree → BAYAR → SIMULASIKAN BERHASIL → Batalkan ikut → reason "Sakit" → BATALKAN. Check saldo. Repeat 3×.
   *Expected:* saldo goes back to the starting value (payment and refund cancel out). *Current:* +Rp50.000 every cycle.
3. **Host from club page.** Klub → + → create club "Tes Tenis" (sport Tenis, add payout) → NANTI SAJA → Jadwal → BUAT MABAR. Check the "Klub" and "Olahraga" rows. Enter a title → TERBITKAN.
   *Expected:* Klub = Tes Tenis, sport Tenis; the session appears under Tes Tenis → Jadwal. *Current:* PB Smash Ceria / Bulu Tangkis; the session shows up under PB Smash Ceria.
4. **Payment → host roster.** As admin of PB Smash Ceria, join Americano and pay. Open the session → KELOLA SESI, then BUKA CHECK-IN.
   *Expected:* you appear in PESERTA, slot shows 9/16, "Hadir 0/9". *Current:* 9/16 but PESERTA empty, "Hadir 0/0".
5. **Ticket code at check-in.** On the Americano ticket note "Kode untuk host: N". On HostQr → MASUKKAN KODE TAMU, enter N (and G-N).
   *Expected:* you're marked present. *Current:* "N" can't be submitted, and "G-N" doesn't exist.
6. **QR check-in without RSVP.** Host a new session (no one joined). On a 2nd device, or after a screenshot, scan the HostQr with + → Scan.
   *Expected:* rejected ("kamu belum terdaftar"), or only allowed in the check-in window. *Current:* accepted, a verified stamp + league attendance is added, and the host's "Hadir" count doesn't change. Also try a screenshot of the QR more than 30 s old: it's still accepted.
7. **Cancel with guest + waitlist.** Rabu Malam (joined + Andi, 3 antrean): ticket → Batalkan ikut → BATALKAN IKUT. Reopen the session.
   *Expected:* 11/12 with 2 antrean, or 12/12 with 1 antrean (2 promoted). *Current:* 12/12 and 2 antrean.
8. **Refund then delete.** As host of Rabu Malam → KELOLA SESI → Sisca → REFUND DEMO (12→11). Then HAPUS on Sisca.
   *Expected:* stays at 11. *Current:* 10/12. Also: REFUND DEMO on Eko, then BUKA CHECK-IN → tap Eko: Eko loses the "Refund demo" label.
9. **Claim free ticket.** `adb shell am start -a android.intent.action.VIEW -d "klubby:///m/sabtu-pagi"` (or navigate in debug) → enter 123456 → KLAIM.
   *Expected:* a guest ticket with a seat taken, or rejected without payment. *Current:* you get "Tiket #1" (LUNAS) with no payment and the session still shows 4/16.
10. **Shared links.** Share a club (header share) and a session to WhatsApp, then tap the link on the same phone.
   *Expected:* opens the club / session in the app. *Current:* opens the browser (klubby.id). There's no in-app route for `/k/<code>`.
11. **Past sessions.** Klub tab → "MABAR KAMU MINGGU INI" and PB Smash Ceria → Jadwal.
   *Expected:* Rabu Malam 29 Okt / Sabtu Pagi 1 Nov are hidden, or marked "Selesai", and can't be joined. *Current:* they're listed, and Sabtu Pagi can be joined and paid.
12. **Cancelled session label.** Host-cancel one of your sessions (KELOLA → Batalkan sesi). Look at the club Jadwal card.
   *Expected:* "DIBATALKAN". *Current:* an orange "ANTRE" button with "0/N · 0 antrean" in red.
13. **Leave own club.** Create a club → menu ⋯ → Keluar klub → open Explore.
   *Expected:* blocked ("kamu admin terakhir"), or the club is still findable. *Current:* the club disappears everywhere. Its sessions remain under Explore → Mabar.
14. **Sign out bleed.** Join Americano → Pengaturan → sign out → sign up as a new user → Klub tab.
   *Expected:* no tickets, default clubs. *Current:* the previous user's Americano ticket and clubs are still there.
15. **Kas.** PB Smash Ceria → Kas → CATAT KELUAR Rp100.000 (Sewa GOR) → balance 1.140.000, "Keluar" +100.000. TARIK DANA Rp40.000: balance drops, Masuk/Keluar unchanged. Then pay for a mabar.
   *Expected (product):* an "iuran" entry appears in the kas. *Current:* none. Restart: all mutations are lost.
16. **Waitlist flow.** Padel Pagi → LIHAT ANTREAN #4 → COBA SLOT TERSEDIA → wait 30 min, or LEPAS SLOT.
   *Expected:* LEPAS → back to the session, antrean 3, CTA "MASUK WAITING LIST". Paying from the slot page → ticket, 8/8, antrean 3. Check KELOLA SESI (if admin): the names list should match the count (currently it doesn't).
17. **Emoji-only session title.** HostNew with title "🏸🔥" → TERBITKAN.
   *Expected:* the published page. *Current:* the not-found page.
