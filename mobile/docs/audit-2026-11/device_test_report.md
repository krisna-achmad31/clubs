# Klubby on-device QA report

- Device: Infinix X6851 (serial 1215125453004629), 1080x2436
- Package: id.klubby.app
- Date: 2026-11-07 23:00 to 2026-11-08 00:15 (device clock crossed midnight during the test)
- Screenshots: `C:\Users\achma\AppData\Local\Temp\claude\e2150559f83ce0f6\e232f6bb-fd30-4375-a3e9-27346e2e3b34\scratchpad\device\NN_*.png`
- Method: adb input, screencap, uiautomator dumps. Flutter dumps are sometimes stale, so every finding was confirmed against a screenshot.
- Logcat: no Flutter exceptions, no FATAL errors, no RenderFlex overflow logged. No red error screens and no crashes were seen.
- Safety rules: no data was cleared and no account action was taken. No real share or payment was completed. One system share sheet appeared without being requested and was cancelled (see C1).

## Summary of FAIL / inconsistency findings (by severity)

### Critical / Major
| # | Area | Finding | Evidence |
|---|------|---------|----------|
| C1 | Privacy, GPS | Pressing MULAI on the GPS recorder opens the system share sheet with the user's **real start coordinates** (maps.google.com link), even though Settings > "Tawarkan berbagi lokasi saat rekam" is OFF. Root cause: the recorder state defaults `beacon = true` (`lib/features/activity/domain/entities/activity.dart:180`) and never reads the setting. The pre-start "Bagikan lokasi awal" toggle is ON by default. | 17_share_sheet_unexpected.png, 135_gps_prestart_beacon.png |
| C2 | Persistence | After force-stop and restart, my 🔥 reaction on Rian's post was lost (🔥6 back to 5, 17 back to 16 reaksi). My comment "Mantap QA test" was also lost. Settings did persist. | 130/131/132_rian_*.png |
| C3 | Streak | The seeded streak of 14 dropped to 1 when the GPS activity was saved. The seed was inconsistent with the stamps (none from 26 Oct to 6 Nov). Liga still shows "streak 14" and a notification says "Es Batu dipakai · Streak 14 hari tetap aman", while Feed and Profil show 1, then 2. | 92b_liga_contrib.png, 124_notif.png |
| C4 | GPS anti-cheat | Phone was stationary: 0.04 km drift in 1:07. Pace shows 0'00"/km everywhere. It was still labeled "Terverifikasi GPS · masuk poin klub" and "Sesi sempurna!" and awarded +140 XP and +25 club points. | (earlier GPS screenshots) |
| C5 | Liga sync | Liga numbers are static. Club points stay 7.640 and "Kontribusimu +320" after the +25 verified activity. The header says 320 but the Top Kontributor list says "Kamu 310". | 93_kontribusi.png, 123_liga_after.png |
| C6 | Data | Rian's "Lari Pagi GBK" also appears as the user's own private 25 Oct activity. Rian's PR banner shows the user's 4:12 time (Rian's is 3:55). | earlier screenshots |
| C7 | Sessions | Past sessions (Rab 29 Okt, Sab 1 Nov) are shown as upcoming and bookable. The cancel deadline has already passed. The "Kamu dapat slot!" notification offers payment for the 1 Nov Padel session. The Klub list says Padel "ANTREAN #4" while the notification says you left the waiting list. | 125_notif_waitlist.png |
| C8 | Ticket | "LIHAT DETAIL MABAR" on the ticket returns to the Klub list instead of the session. Mabar Rabu Malam is "LUNAS ✓" in the Klub list but shows ANTRE in the club Jadwal. | earlier |
| C9 | Kelola Sesi | Mabar Sabtu Pagi shows 4/16 slots, but "Belum ada peserta tercatat" and check-in "Hadir 0/0". | earlier |
| C10 | Gear | Activities never update gear. The shoe stays 620/700 km after a Lari GPS run, and the racket stays "18 jam main" after 30 min of badminton. The source has no code path from activity to gear. | 121_gear_after.png |
| C11 | Buat Klub | Tapping BUAT KLUB appears dead. It silently requires a payout bank account ("Tambahkan rekening pencairan kas dulu"); the field is below the fold and the toast is easy to miss. **Not completed**: I did not enter bank details, so club creation is untested. | 86/87/88_*.png |

### Minor
- Liga lists PB Smash Ceria with **96 anggota**, but the club page says **48 anggota**. The monogram is "PS" on the score page and "SC" elsewhere. (91, 93)
- The Liga season banner (🏆 Divisi) opens "Skor Aktivitas Klub". The source routes it to `R.season` ("Musim liga"), so the season page could not be reached. (98)
- Nasional standings jump from #3 to #128 with no gap marker. It shows "ZONA DEGRADASI" for a national top-10 ranking. (97)
- The Liga card offers "HUBUNGKAN JAM", but Perangkat Terhubung already shows Jam Klubby and Health Connect as connected. (95)
- The notification "Streak kamu dalam bahaya! Belum ada aktivitas hari ini" is still shown after an activity today, and while Pengingat streak was OFF. "Budi ngajak main!" appears although the user is Budi. "kudoz" may be a typo for kudos. (124)
- The menu on your own post offers "Bisukan Budi" and "Laporkan" (mute or report yourself). There is no edit or delete. (128)
- Catat Manual: the date/time picker is in English ("Select date", "Cancel", "OK"). The keyboard reopens after the picker closes, and stray keystrokes then go into the title field. The default date is start = now − 1h, so near midnight the activity lands on the previous day. (109, 115)
- Scan QR page is titled "Rekam Aktivitas"; the camera preview is black. The "Jam pintar terhubung" pill uses the red/error color. (133, 135)
- The feed sport selector and Geng show 🏈 American Football / Bento "Belum diadopsi", although the user plays Lari and Badminton.
- Earlier findings: duplicated subtitle "Lari Pagi GBK · Lari Pagi GBK"; mixed pace formats (6'08" vs 6:08); splits list only Km1–4 for 5.24 km; feed not sorted chronologically; comment icon doesn't scroll to comments; avatars and animals inconsistent across screens; Dinda shows "IKUTI" but is in the Diikuti filter; "GABUNG · RP3..." truncated; Kas header says November over October rows, and the chat FAB overlaps the Kas buttons; OSM attribution clipped; hosted session "Mabar QA Minggu" missing from "Mabar kamu minggu ini", host sees IKUT on their own session, and the session is unsorted in Jadwal; tournament klasemen empty at R1.

## PASS / FAIL table

| Tab | Step | Expected | Actual | Result | Screenshot |
|-----|------|----------|--------|--------|------------|
| Feed | Scroll, open post detail | Opens | Opens | PASS (minor issues) | 01–10 |
| Feed | Reaction 🔥 | Count +1, card and detail agree | 5→6, 16→17, consistent | PASS | earlier |
| Feed | Reaction / comment persist after restart | Kept | Both lost | **FAIL** | 130–132 |
| Feed | Comment post | Appears | Appears (can hide behind composer) | PASS | earlier |
| Feed | Notifications open / mark read | Badge clears | Badge 3 → cleared | PASS | 124, 126 |
| Feed | Notification content consistency | Matches state | Stale streak/waitlist items | **FAIL** | 124, 125 |
| Feed | PUBLIK tab | Public posts | Works | PASS | 127 |
| Feed | Own-post "..." menu | Edit / delete | Mute / report self | **FAIL** | 128 |
| Klub | Club list, explore, tabs | Works | Works; slots consistent across lists | PASS | earlier |
| Klub | Club detail Jadwal | Upcoming only, correct status | Past sessions bookable; LUNAS vs ANTRE | **FAIL** | earlier |
| Klub | Chat send, unread badge | Works | Works | PASS | earlier |
| Klub | Kas | Correct month, no overlap | Wrong month header; FAB overlap | FAIL (minor) | earlier |
| Klub | Invite search | Feedback | Toast for unknown user | PASS | earlier |
| Klub | Join → pay → ticket (new booking) | Ticket | Not tested (demo pay tap blocked); existing ticket viewed | NOT TESTED | earlier |
| Klub | Ticket "Lihat detail mabar" | Opens session | Pops to Klub list | **FAIL** | earlier |
| Klub | Host session → published → Kelola → QR | Works | Works; rotating QR | PASS (minor issues) | earlier |
| Klub | Kelola peserta of existing session | Matches slots | 4/16 vs 0 peserta | **FAIL** | earlier |
| Klub | Create club → in list | New club in Klubku | Blocked by payout-account requirement | NOT TESTED / FAIL (UX) | 86–88 |
| Klub | Tournament new → live → scores | Works | Works, persisted; podium not reached | PARTIAL | earlier |
| Liga | Area table, my rank | Matches Klub (#4 Div 1) | #4 matches | PASS | 90 |
| Liga | Member count | Matches club page | 96 vs 48 | **FAIL** | 90, 91 |
| Liga | My score / contribution | Updates with verified activity; consistent | Static; 320 vs 310; streak 14 vs 1/2 | **FAIL** | 93, 123 |
| Liga | Info sheet | Explains | Works; formula consistent with totals | PASS | 96 |
| Liga | Nasional tab | Works | Works (minor zone label issue) | PASS | 97 |
| Liga | Season page | Opens Musim liga | Opens score page | **FAIL** | 98 |
| Liga | Segment page | Works | Opened earlier (Tanjakan Senayan) | PASS | earlier |
| Profil | Stats after activities | Consistent with Feed | Streak 2, XP 2.340, 2 sesi / 31 m, Permata +4 | PASS | 120 |
| Profil | Stamp calendar | Correct days | 7 Nov 🏃, 8 Nov 🏸, weekday alignment ok | PASS | 122 |
| Profil | Tantangan | Join works | Gowes 200 km joined 0/200 | PASS (demo) | 100–102 |
| Profil | Geng Gemoy / mascot | Preview works | Works | PASS | 103, 104 |
| Profil | Gear mileage sync | Increases | Unchanged | **FAIL** | 121 |
| Profil | Settings persist across restart | Persist | Persisted (then restored) | PASS | earlier, 141 |
| Profil | Settings subpages | Open | All open | PASS | earlier |
| + | Manual 30 min | Saved, synced | Saved; Feed post, streak 2, XP +40, stamp, stats ok | PASS | 113, 118–122 |
| + | Manual future-time validation | Rejected | "Pilih waktu yang sudah berlalu." | PASS | 111 |
| + | Manual → Liga | Casual = 0 club pts | 0 pts shown, Liga unchanged | PASS | 118 |
| + | GPS start/pause/resume/stop/save | Works | Works | PASS | earlier |
| + | GPS plausibility | Realistic pace, no verify on drift | 0'00"/km, verified, +25 pts | **FAIL** | earlier |
| + | GPS location share default | Off per setting | On; share sheet with real coordinates | **FAIL** | 17, 135 |
| + | Scan QR page | Opens camera | Opens; black preview; wrong title | PASS (minor) | 133 |
| Goyang | Sheet + demo lobby | Opens | Works, labeled demo | PASS | 136–138 |
| Goyang | Shake gesture | — | Skipped per instructions | NOT TESTED | — |
| All | Crashes / red screens / overflow | None | None seen; logcat clean | PASS | — |

## Not tested
- Paying for and confirming a new booking. The demo "BAYAR" tap was blocked by the tool's safety classifier.
- Club creation end to end. It requires bank payout details, which I did not enter.
- Tournament podium (the score-entry automation stalled).
- Shake gesture.
- Whether the manual post used the "Hanya Klub" default privacy. The post card shows no privacy label.
- Real QR check-in.
