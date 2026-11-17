# Daftar Alur Halaman (Page Flows) & Kebutuhan API — Klubby

Dokumen ini memetakan **seluruh rute/halaman** di aplikasi Flutter (`clubs/mobile/lib/core/router/routes.dart`) terhadap **kebutuhan API / Supabase / Edge Functions** beserta status integrasinya saat ini di build Dev (`klubby_dev`).

**Legenda Status:**
- ✅ **Sudah di Dev Build:** Sudah terhubung ke `klubby_dev` (sesuai laporan BE).
- ⏳ **Belum / Dibutuhkan:** Masih memakai data lokal/hardcode atau belum dihubungkan.

**Pembaruan Dev:** Build Flutter Dev sekarang dapat membuat klub dan sesi, membaca/mengirim chat klub lewat REST, mencatat aktivitas manual dan melihatnya di feed, serta menjalankan RSVP berbayar dengan QR statis dan konfirmasi manual host. Status ini merujuk ke build Dev, bukan rute utama Flutter. Migrasi pembayaran, aktivitas, dan registrasi token FCM sudah dipasang di `klubby_dev`. Login SMS membutuhkan konfigurasi provider, dan pengiriman push belum aktif.

---

## 1. Onboarding & Autentikasi (`/splash` → `/signup/ready`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/welcome`, `/signup`, `/signup/otp` | Login/Daftar via No. HP & OTP | `POST /auth/otp/request`, `POST /auth/otp/verify` (Supabase Phone Auth) | ⏳ Form OTP sudah panggil Supabase; provider SMS belum aktif |
| `/signup/about` | Isi nama, username, gender, avatar | `PATCH /me/profile` (cek keunikan `username`) | ✅ |
| `/signup/location` | Set area & radius pencarian | `PATCH /me/profile` (`area`, `lat`, `lng`, `radius_km`) | ✅ |
| `/signup/sports` | Pilih olahraga & skill level | `PUT /me/sports` (`sport_id`, `level`, `positions[]`) | ⏳ |
| `/signup/clubs` | Rekomendasi & gabung klub awal | `GET /clubs?lat=&lng=&radius=`, `POST /clubs/:id/join` | ✅ |
| `/signup/permissions`, `/signup/watch` | Izin lokasi, notif, Health Connect/Watch | Client-side permission + `POST /me/devices` (simpan token FCM & status wearable) | ⏳ |

---

## 2. Tab 1: Feed & Sosial (`/feed`, `/post/:id`, `/notifications`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/feed` | List postingan (Toggle: Publik vs Komunitas Saya) | `GET /feed?scope=public|clubs&cursor=` | ✅ (Dari aktivitas manual) / ⏳ (Layar utama masih alur lama) |
| `/post/:id` | Detail aktivitas, grafik sensor, reaksi & komentar | `GET /feed/:id`, `POST /feed/:id/reactions`, `POST /feed/:id/comments` | ⏳ |
| Edit / Hapus Post | Ubah judul, catatan, privasi | `PATCH /activities/:id`, `DELETE /activities/:id` | ⏳ |
| `/notifications` | Kotak masuk notifikasi | `GET /notifications`, `PATCH /notifications/:id/read` | ✅ (In-app) / ⏳ (Push saat app tertutup) |

---

## 3. Tab 2: Klub, Chat, Kas & Undangan (`/klub`, `/club/:id/*`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/klub`, `/explore` | Daftar klub saya & discovery klub terdekat | `GET /clubs/mine`, `GET /clubs?lat=&lng=&sport_id=` | ✅ |
| `/club-new` | Buat klub baru + upload logo | `POST /clubs`, `POST /storage/club-logos` | ✅ |
| `/club/:id` | Profil klub, daftar anggota, jadwal | `GET /clubs/:id`, `POST /clubs/:id/join`, `POST /clubs/:id/leave` | ✅ |
| `/club/:id/invite`, `/k/:code` | Undang anggota / join via kode link | `POST /clubs/:id/invite`, `POST /clubs/join-by-code` | ⏳ |
| `/club/:id/chat` | Ruang obrolan klub & stiker | `GET /clubs/:id/messages`, `POST /clubs/:id/messages` + **Supabase Realtime** | ✅ (REST) / ⏳ (Realtime) |
| `/club/:id/kas` | Buku kas transparan & tarik dana admin | `GET /clubs/:id/kas`, `POST /clubs/:id/kas/withdraw` (Midtrans/Xendit Disbursement) | ⏳ |
| `/pro` | Upgrade / status Klub Pro | `GET /clubs/:id/subscription`, `POST /clubs/:id/pro/checkout` | ⏳ |

---

## 4. Sesi Mabar, RSVP, QRIS & Host (`/session/:id/*`, `/host/*`, `/m/:id`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/session/:id` | Detail sesi mabar & daftar peserta | `GET /sessions/:id` | ✅ |
| RSVP Gratis | Daftar / batal ikut mabar gratis | `POST /sessions/:id/rsvp`, `DELETE /sessions/:id/rsvp` | ✅ |
| `/session/:id/pay` | Bayar dengan QR statis host, laporkan pembayaran, dan tunggu konfirmasi host | RPC `set_mabar_payment_qr`, `report_mabar_payment` dan `review_mabar_payment` | ✅ Alur Dev Build, uji perangkat ⏳ |
| `/session/:id/ticket`, `/expired` | Tiket QR masuk lapangan / status kedaluwarsa | `GET /sessions/:id/ticket`, Cron expire pembayaran | ⏳ |
| `/session/:id/waitlist`, `/slot` | Antrean otomatis & naik slot | `POST /sessions/:id/waitlist`, Auto-promote saat ada yang batal | ⏳ |
| `/m/:id` (Web-RSVP) | Tamu dari WhatsApp konfirmasi via browser | `GET /public/sessions/:id`, `POST /public/sessions/:id/rsvp` (tanpa login) | ⏳ |
| `/host/new`, `/host/:id/published` | Host buat jadwal mabar baru | `POST /sessions`, `PATCH /sessions/:id` | ✅ |
| `/host/:id/manage`, `/host/:id/qr` | Kelola peserta, no-show, & QR Check-in GOR | `POST /sessions/:id/cancel`, `PATCH /sessions/:id/participants/:uid`, `GET /sessions/:id/checkin-qr` | ⏳ |

---

## 5. Turnamen & Live Scoring (`/tournament/*`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/tournament/new` | Buat turnamen (Americano, Mexicano, dll) | `POST /sessions/:id/tournaments` (generate bracket/match) | ⏳ |
| `/tournament/live` | Input skor real-time & resolusi konflik | `PATCH /tournaments/:id/matches/:matchId`, `POST /matches/:id/resolve` + **Realtime** | ⏳ |
| `/tournament/podium` | Klasemen akhir & podium | `GET /tournaments/:id/standings` | ⏳ |

---

## 6. Perekaman Aktivitas & Anti-Cheat (`/record/*`, `/activity/:id`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/record/scan` | Scan QR Check-in di lapangan GOR | `POST /sessions/:id/checkin` (validasi token QR → Tier 1 Verified) | ⏳ |
| `/record/gps/save` | Simpan rekaman GPS + Privacy Zone 500m | `POST /activities` (beserta `ActivitySample[]`, `gearId`, `privacy`) | ⏳ |
| `/record/manual` | Catat olahraga manual (Tier 2 Casual) | `POST /activities` (`source: manual` → 0 poin klub, tetap dapat stempel) | ✅ |
| `/activity/:id` | Detail aktivitas, splits, grafik HR/pace | `GET /activities/:id` | ⏳ |
| Wearable / Strava Sync | Impor otomatis Health Connect / Strava | `POST /activities/sync-wearable`, `POST /webhooks/strava` | ⏳ |

---

## 7. Tab 4: Liga & Leaderboard (`/liga`, `/liga/score`, `/liga/season`, `/segment`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/liga` | Peringkat klub Area & Nasional | `GET /league/standings?scope=area|national&sport_id=` | ⏳ |
| `/liga/score` | Rincian kontribusi poin saya ke klub | `GET /league/my-contribution` | ⏳ |
| `/liga/season` | Info divisi, promosi & degradasi bulanan | `GET /league/season` | ⏳ |
| `/segment` | Papan peringkat segmen rute | `GET /segments/:id/leaderboard` | ⏳ |

---

## 8. Tab 5: Profil, Streak, Maskot, Gear & Goyang (`/profil`, `/stamps`, `/geng`, `/shop`, `/settings/*`)
| Halaman / Route | Alur UI | API / Service yang Dibutuhkan | Status |
| :--- | :--- | :--- | :--- |
| `/profil` | Baca & edit profil, statistik, daftar gear | `GET /me/profile`, `PATCH /me/profile`, `GET /me/stats` | ✅ (Profil) / ⏳ (Stats & Gear) |
| Gear Tracker | Tambah, pensiunkan, & restring gear | `GET /me/gears`, `POST /me/gears`, `PATCH /me/gears/:id` | ⏳ |
| `/stamps`, `/streak/saved` | Kalender stempel 2D & pemakaian Es Batu | `GET /me/stamps?month=`, `POST /me/streak/freeze` | ⏳ |
| `/geng`, `/record/evolve` | Daftar 18 maskot & level evolusi | `GET /me/mascots` | ⏳ |
| `/shop` | Beli item (Es Batu, bingkai, stiker) | `GET /shop/items`, `POST /shop/purchase` | ⏳ |
| `/settings/devices` | Kelola smartwatch & Strava OAuth | `GET /me/devices`, `POST /integrations/strava/connect` | ⏳ |
| `/settings/notifications` | Preferensi notifikasi & jam pengingat | `PATCH /me/settings` + `POST /me/fcm-token` | ✅ (Registrasi token FCM) / ⏳ (Pengiriman push aktif) |
| Goyang (Shake Invite) | Kirim & terima ajakan main mendadak | `POST /goyang/invite`, `POST /goyang/:id/respond` + **Push / Realtime** | ⏳ |

---

## Ringkasan Prioritas Lanjutan untuk BE
1. **Akses Auth Dev & Sinkronisasi Layar Utama:** Sediakan akun Auth Dev agar login langsung ke Supabase bisa diuji dan layar utama Flutter bisa mulai melepas data hardcode.
2. **OTP HP & FCM Token:** Hubungkan `Phone Auth` + endpoint `POST /me/fcm-token` untuk push notification saat aplikasi tertutup.
3. **Pembayaran QRIS & Web-RSVP (`/m/:id`):** Prioritas tinggi untuk alur mabar berbayar & konfirmasi tamu WhatsApp.
4. **Aktivitas, Feed & Anti-Cheat 2-Tier:** Endpoint `POST /activities` + `GET /feed` + perhitungan poin `league`.
5. **Realtime:** Chat klub (`/club/:id/chat`) dan Live Scoring turnamen (`/tournament/live`).
