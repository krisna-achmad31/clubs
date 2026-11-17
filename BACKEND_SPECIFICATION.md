# Spesifikasi Teknis & Desain Data Backend — Klubby

Dokumen ini disusun berdasarkan seluruh kode aplikasi mobile Flutter (`clubs/mobile/lib/`), `PRD_SPORTS_COMMUNITY_APP.md`, `MASTER_KLUBBY_BLUEPRINT.md`, dan `project-info.json` sebagai acuan lengkap bagi tim **Backend (BE)** untuk merancang **Database Schema (PostgreSQL + PostGIS)**, **REST/Realtime API**, **Sistem Notifikasi**, **Payment Gateway (QRIS)**, dan **Integrasi Eksternal**.

---

## 1. Gambaran Umum & Rekomendasi Stack
* **Nama Produk:** Klubby (Hybrid Sports Community & Habit App: Reclub + Strava + Duolingo)
* **Client:** Mobile App (Flutter Android/iOS) + Web Companion (`klubby.id/m/:id`, `/k/:code`, `/p/:id` untuk Web-RSVP & Deep Link)
* **Rekomendasi Stack BE:** Go / Node.js + **Supabase (PostgreSQL + PostGIS)**, Realtime (WebSocket/Supabase Realtime untuk Chat & Live Scoring), **Midtrans / Xendit** (QRIS Dinamis & Disbursement/Kas), **FCM / APNs** (Push Notification).
* **Status Saat Ini di Mobile:** Seluruh flow UI sudah berjalan dengan data lokal (`SharedPreferences` / JSON) & *in-memory seed*. Belum terhubung ke API produksi, OTP asli, QRIS nyata, maupun verifikasi server.

---

## 2. Alur Utama Aplikasi (End-to-End Flows)

### A. Onboarding & Autentikasi (`/splash` → `/signup/ready`)
1. **Login / Register:** Input nomor HP → Kirim & verifikasi **OTP**.
2. **Setup Profil:** Nama, username unik, email (opsional), gender, avatar (`ProfileAvatar` atau foto), area lokasi (`area`, `radiusKm` untuk discovery).
3. **Pilih Olahraga:** Memilih daftar `UserSport` (`sportId`, `SkillLevel`, `positions`).
4. **Gabung Klub Awal & Izin:** Rekomendasi klub terdekat berdasarkan GPS/area, izin lokasi/notifikasi/kesehatan, serta opsi pairing smartwatch.

### B. Manajemen Klub, Chat & Kas (`/klub`, `/club/:id`)
1. **Discovery & Join:** Cari klub terdekat (`radiusKm`, `sportId`). Jika `ClubPrivacy.publik` langsung masuk; jika `ClubPrivacy.persetujuan` perlu approval admin. Bisa juga join via kode undangan (`/k/:code`) atau tambah anggota dari kontak.
2. **Klub Chat (`/club/:id/chat`):** Ruang obrolan internal klub + pengumuman (*pinned note*) + stiker ekspresif.
3. **Buku Kas Klub (`/club/:id/kas`):** Mencatat pemasukan otomatis dari pembayaran QRIS mabar, pengeluaran (sewa lapangan, shuttlecock/bola), dan fitur **Tarik Dana** (`PayoutAccount` milik admin).
4. **Klub Pro:** Status langganan `pro` (trial/paid) untuk fitur admin lanjutan.

### C. Sesi Mabar, RSVP, Waitlist & Pembayaran QRIS (`/session/:id`)
1. **Host Buat Sesi (`/host/new`):** Tentukan judul, klub, olahraga, tanggal/jam (`startsAt`, `endsAt`), venue, court, biaya (`fee`), kuota (`slots`), `guestMax`, `cancelDeadline` (`deadlineAt`), opsi `recurring`, `qris`, dan `autoWaitlist`.
2. **Share ke WhatsApp (Web-RSVP):** Menghasilkan tautan `https://klubby.id/m/:id`. Peserta dari grup WA bisa konfirmasi hadir (`via = "WEB"`) tanpa harus install aplikasi.
3. **RSVP & Antrean Otomatis:**
   - Jika slot tersedia: peserta masuk `participants` (status awal `menunggu` jika berbayar, atau `lunas` jika gratis).
   - Jika kuota penuh & `autoWaitlist = true`: masuk `waitlist`. Jika ada yang batal sebelum `deadlineAt`, urutan teratas waitlist otomatis naik menjadi peserta dan mendapat notifikasi.
   - Peserta bisa membawa tamu (`guestOf`, maksimal `guestMax`).
4. **Pembayaran QRIS (`/session/:id/pay`):** Generate QRIS dinamis (+ biaya admin platform Rp 1.500–2.500). Ada *countdown* pembayaran (`waitingLabel`). Jika lewat batas waktu → `/session/:id/expired`. Jika lunas → status `lunas`, tiket QR terbit (`/session/:id/ticket`).
5. **Check-in di Lapangan (`/host/:id/qr` & `/record/scan`):** Host menampilkan QR sesi, peserta scan QR → `present = true`. Jika tidak hadir tanpa kabar → `noShow = true`.

### D. Engine Turnamen & Live Scoring (`/tournament/new` → `/tournament/podium`)
1. **Format:** `americano`, `mexicano` (butuh kelipatan 4 pemain), `kingOfCourt`, `roundRobin`, `gugur` (single/double elimination).
2. **Live Scoring (`/tournament/live`):** Input skor per `CourtMatch` (`court`, `game`, `teamA`, `teamB`, `scoreA`, `scoreB`).
3. **Conflict Resolution:** Jika 2 pemain menginput skor berbeda untuk match yang sama, sistem mencatat `ScoreConflict` (`by`, `a`, `b`) untuk diselesaikan.
4. **Klasemen:** Akumulasi `PlayerScore` (`name`, `points`) real-time hingga podium.

### E. Perekaman Aktivitas & Anti-Cheat 2-Tier (`/record/*`)
1. **Sumber Aktivitas (`ActivitySource`):**
   - **Tier 1 (Verified — 100% Poin Klub + Stempel + Evolusi Maskot):**
     - Smartwatch / Health Connect / HealthKit / Strava Webhook (ada data HR minimal 30 menit).
     - Scan QR Check-in di lapangan GOR (`present = true`).
     - Rekaman GPS valid di aplikasi (`ActivitySample` dengan koordinat, elevasi, pace, durasi).
   - **Tier 2 (Casual / Manual — 0 Poin Klub, Tidak Menambah Evolusi Maskot, Tetap Dapat Stempel & Streak Harian):**
     - Input manual tanpa bukti sensor/QR.
2. **Post-Workout:** Hitung `ActivityAnalysis` (pace, splits per km, grafik HR/elevasi/cadence), potong ujung rute GPS jika **Privacy Zone (500m)** aktif, update **Gear Tracker** (tambah `km` sepatu/sepeda atau `hours/minutes` raket), lalu publish ke Feed sesuai `Privacy` (`publik`, `pengikut`, `klub`).

### F. Gamifikasi Streak, Stempel 2D & Evolusi Maskot (`/stamps`, `/geng`)
1. **Streak Harian & Es Batu (`freezes`):**
   - 1 aktivitas (Tier 1 atau Tier 2) per hari = 1 `StampEntry` di kalender & menjaga `streak`.
   - Jika absen 1 hari dan punya `freezes > 0`, sistem otomatis memakai 1 Es Batu (`frozen = true`) agar streak tidak putus.
2. **Evolusi Maskot ("Geng Gemoy" — 18 Hewan):**
   - Setiap olahraga (`Sports.all`, 66 olahraga) dipetakan ke 1 dari 18 `Animal` (misal: `badminton` → `ciko`, `lari` → `kiki`, `renang` → `otto`).
   - Sesi **terverifikasi (Tier 1)** pertama pada keluarga olahraga tersebut membuka adopsi hewan (`adopted`).
   - Level evolusi (`Stage`) berdasarkan total sesi terverifikasi keluarga hewan tersebut:
     - `pemula` (1), `gesit` (3), `turbo` (7), `juara` (14), `legend` (30).
   - Sesi manual (Tier 2) **tidak** menambah hitungan adopsi/evolusi.

### G. Leaderboard & Liga Komunitas (`/liga`, `/liga/season`)
1. **Formula Poin Klub:**
   $$\text{Poin Klub} = (\text{Jam Olahraga Verified} \times 10) + (\text{Kehadiran Mabar Resmi} \times 25) + (\text{Bonus Streak Anggota} \times 5)$$
2. **Skor Kontributor:** `MyContribution` (`verifiedMinutes`, `attendance`, `streakDays`, `manualIgnored`).
3. **Divisi:** Peringkat Area (Kecamatan/Kota) & Nasional dengan siklus promosi-degradasi bulanan.

### H. Fitur "Goyang" (Shake-to-Invite) & Shop (`/shop`)
1. **Goyang (`GoyangInvite`):** Pengguna menggoyangkan HP → broadcast ajakan main mendadak ke `InviteAudience` (`semuaTeman`, `klubku`, `temanDekat`) atau `nearby`, lengkap dengan estimasi patungan lapangan (`courtFee ~/ split`). Menghormati `quietHours` dan `limitIncoming`.
2. **Shop:** Pembelian item kosmetik/utilitas (`esBatu`, `bingkaiEmas`, `stikerHewan`, `pelangi`, `boostPetir`) menggunakan `gems` atau `saldo`.

---

## 3. Desain Data & Tipe Data Lengkap (Mapping dari Entitas Mobile)

Berikut adalah seluruh entitas dan tipe data yang ada di codebase Flutter (`clubs/mobile/lib/`) beserta rekomendasi tipe data PostgreSQL untuk Backend:

### 3.1 `users` (dari `UserProfile` & `UserSport`)
| Field (Dart) | Tipe Dart | Rekomendasi Tipe DB (PostgreSQL) | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | *(belum ada di lokal)* | `UUID PRIMARY KEY` | ID unik user |
| `name` | `String` | `VARCHAR(100) NOT NULL` | Nama lengkap |
| `username` | `String` | `VARCHAR(50) UNIQUE NOT NULL` | Handle unik |
| `phone` | `String` | `VARCHAR(20) UNIQUE NOT NULL` | Nomor HP (untuk OTP) |
| `email` | `String` | `VARCHAR(255)` | Opsional |
| `gender` | `enum Gender` | `VARCHAR(20)` | `lakiLaki`, `perempuan`, `rahasia` |
| `avatar` | `enum ProfileAvatar` | `VARCHAR(30)` | `kapi`, `lolo`, `kodi`, `owi`, `hamu`, `paka`, `madu`, `komo` |
| `photoPath` | `String?` | `TEXT` | URL foto profil di object storage |
| `avatarBg` | `int?` | `BIGINT` | ARGB color int |
| `accessory` | `String?` | `VARCHAR(50)` | ID aksesori maskot yang dipakai |
| `area` | `String` | `VARCHAR(150)` | Nama area (mis. `Kebayoran Baru, Jakarta Selatan`) |
| `location` | *(baru)* | `GEOGRAPHY(Point, 4326)` | Koordinat PostGIS untuk discovery |
| `radiusKm` | `int` | `SMALLINT DEFAULT 10` | Radius pencarian klub/mabar |
| `activeSportId` | `String` | `VARCHAR(30)` | ID olahraga aktif (default `'badminton'`) |
| `streak` | `int` | `INT DEFAULT 0` | Streak harian saat ini |
| `bestStreak` | `int` | `INT DEFAULT 0` | Rekor streak tertinggi |
| `xp` | `int` | `INT DEFAULT 0` | Total XP |
| `freezes` | `int` | `SMALLINT DEFAULT 0` | Jumlah Es Batu (Streak Freeze) |
| `maxFreezes` | `int` | `SMALLINT DEFAULT 2` | Batas maksimal simpanan Es Batu |
| `gems` | `int` | `INT DEFAULT 0` | Mata uang in-app |
| `stamps` | `int` | `INT DEFAULT 0` | Total stempel |
| `saldo` | `int` | `INT DEFAULT 0` | Saldo Rupiah (jika ada dompet/refund) |
| `following` / `followers` | `int` | `INT DEFAULT 0` | Counter (atau tabel relasi `user_follows`) |
| `joined` | `DateTime?` | `TIMESTAMPTZ DEFAULT NOW()` | Tanggal bergabung |
| `lastActive` | `DateTime?` | `TIMESTAMPTZ` | Terakhir mencatat aktivitas |
| `owned` | `Set<String>` | `TEXT[]` / tabel `user_inventory` | Daftar ID item shop yang dimiliki |
| `settings` | `Map<String, Object>` | `JSONB` | Preferensi (jam pengingat, privacy zones, dll) |

**Tabel Relasi `user_sports` (`UserSport`):**
- `user_id` (`UUID FK`), `sport_id` (`VARCHAR(30)`), `level` (`VARCHAR(20)`: `pemula`, `pemulaPlus`, `menengah`, `menengahPlus`, `mahir`, `pro`), `positions` (`TEXT[]`).

**Tabel Relasi `user_mascots` (`adopted` & `verifiedSportSessions`):**
- `user_id` (`UUID FK`), `animal` (`VARCHAR(20)` — 18 hewan `Animal`), `verified_sessions` (`INT DEFAULT 0`).
- `user_sport_sessions`: `user_id`, `sport_id`, `verified_count` (`INT`).

**Tabel `stamp_entries` (`StampEntry`):**
- `id` (`UUID PK`), `user_id` (`UUID FK`), `day` (`DATE NOT NULL`), `sport_ids` (`TEXT[]`), `frozen` (`BOOLEAN DEFAULT FALSE`), `legacy` (`BOOLEAN DEFAULT FALSE`). Unique `(user_id, day)`.

---

### 3.2 `gears` (dari `Gear`)
| Field (Dart) | Tipe Dart | Rekomendasi Tipe DB | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | `String` | `UUID PRIMARY KEY` | ID gear |
| `user_id` | *(relasi)* | `UUID REFERENCES users(id)` | Pemilik gear |
| `name` | `String` | `VARCHAR(100) NOT NULL` | Nama sepatu/raket/sepeda |
| `kind` | `enum GearKind` | `VARCHAR(20) NOT NULL` | `sepatu`, `raket`, `sepeda`, `lainnya` |
| `sportId` | `String` | `VARCHAR(30) NOT NULL` | Olahraga terkait |
| `km` | `double` | `DOUBLE PRECISION DEFAULT 0` | Jarak tempuh (sepatu/sepeda) |
| `limitKm` | `int?` | `INT` | Batas km aman sepatu (mis. 500–800) |
| `hours` | `int` | `INT DEFAULT 0` | Jam pakai raket |
| `minutes` | `int` | `INT DEFAULT 0` | Sisa menit pakai raket |
| `restrungAt` | `DateTime?` | `TIMESTAMPTZ` | Tanggal tarik senar terakhir |
| `retired` | `bool` | `BOOLEAN DEFAULT FALSE` | Status pensiun |
| `isDefault` | `bool` | `BOOLEAN DEFAULT FALSE` | Otomatis terpilih saat rekam |

---

### 3.3 `activities` & `activity_samples` (dari `Activity` & `ActivitySample`)
| Field (Dart) | Tipe Dart | Rekomendasi Tipe DB | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | `String` | `UUID PRIMARY KEY` | ID aktivitas |
| `user_id` | *(relasi)* | `UUID REFERENCES users(id)` | Pemilik aktivitas |
| `sportId` | `String` | `VARCHAR(30) NOT NULL` | ID olahraga |
| `title` | `String` | `VARCHAR(150) NOT NULL` | Judul aktivitas |
| `start` | `DateTime` | `TIMESTAMPTZ NOT NULL` | Waktu mulai |
| `duration` | `Duration` | `INT NOT NULL` | Durasi gerak (detik) |
| `elapsedTime` | `Duration?` | `INT` | Total waktu termasuk jeda (detik) |
| `source` | `enum ActivitySource` | `VARCHAR(30) NOT NULL` | Sumber (menentukan Tier 1 Verified vs Tier 2 Casual) |
| `distanceKm` | `double` | `DOUBLE PRECISION DEFAULT 0` | Jarak (km) |
| `avgHr` | `int?` | `SMALLINT` | Rata-rata heart rate |
| `hideHr` | `bool` | `BOOLEAN DEFAULT FALSE` | Sembunyikan HR di feed |
| `route` | `List<Offset>` | `JSONB` / `GEOGRAPHY(LineString)` | Rute (sudah dipotong Privacy Zone 500m) |
| `splits` | `List<int>` | `INT[]` | Detik per km |
| `privacy` | `enum Privacy` | `VARCHAR(20) DEFAULT 'pengikut'` | `publik`, `pengikut`, `klub` |
| `note` | `String` | `TEXT` | Catatan |
| `feel` | `int?` | `SMALLINT` | Rating perasaan |
| `score` | `String?` | `VARCHAR(50)` | Skor pertandingan (jika olahraga raket/tim) |
| `clubName` / `club_id` | `String?` | `UUID REFERENCES clubs(id)` | Klub terkait |
| `photos` | `List<String>` | `TEXT[]` | URL foto |
| `gearId` | `String?` | `UUID REFERENCES gears(id)` | Gear yang dipakai |
| `device` | `String?` | `VARCHAR(100)` | Nama perangkat/smartwatch |
| `published` | `bool` | `BOOLEAN DEFAULT TRUE` | Tampil di feed atau tidak |

**Tabel `activity_samples` (`ActivitySample`):**
- `activity_id` (`UUID FK`), `elapsed_seconds` (`DOUBLE PRECISION`), `moving_seconds` (`DOUBLE PRECISION`), `distance_meters` (`DOUBLE PRECISION`), `latitude` (`DOUBLE PRECISION`), `longitude` (`DOUBLE PRECISION`), `elevation_meters` (`DOUBLE PRECISION`), `heart_rate` (`DOUBLE PRECISION`), `cadence` (`DOUBLE PRECISION`), `accuracy` (`DOUBLE PRECISION`).

---

### 3.4 `clubs` (dari `Club`)
| Field (Dart) | Tipe Dart | Rekomendasi Tipe DB | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | `String` | `UUID PRIMARY KEY` | ID klub |
| `name` | `String` | `VARCHAR(100) NOT NULL` | Nama klub |
| `initials` | `String` | `VARCHAR(10)` | Inisial logo |
| `sportId` | `String` | `VARCHAR(30) NOT NULL` | Cabang olahraga utama |
| `members` | `int` | `INT DEFAULT 1` | Jumlah anggota |
| `color` | `Color` | `BIGINT` | Warna tema klub |
| `emoji` | `String` | `VARCHAR(10)` | Emoji klub |
| `area` | `String` | `VARCHAR(150)` | Lokasi area |
| `location` | *(baru)* | `GEOGRAPHY(Point, 4326)` | Untuk hitung `distanceKm` |
| `division` | `int?` | `SMALLINT` | Divisi liga |
| `rank` | `int?` | `INT` | Peringkat saat ini |
| `schedule` | `String` | `VARCHAR(150)` | Jadwal rutin |
| `privacy` | `enum ClubPrivacy` | `VARCHAR(20) DEFAULT 'publik'` | `publik`, `persetujuan` |
| `code` | `String` | `VARCHAR(20) UNIQUE` | Kode undangan (`/k/:code`) |
| `sessionsPerWeek` | `int` | `SMALLINT DEFAULT 0` | Frekuensi mabar/minggu |
| `note` | `String` | `VARCHAR(255)` | Status singkat di discovery |
| `logoPath` | `String?` | `TEXT` | URL logo klub |
| `payout` | `PayoutAccount?` | `JSONB` | Rekening/e-wallet tujuan tarik dana |
| `pro` | `bool` | `BOOLEAN DEFAULT FALSE` | Status Klub Pro |
| `pinnedNote` | `String` | `TEXT` | Pengumuman admin |

---

### 3.5 `mabar_sessions` & `session_participants` (dari `MabarSession` & `Participant`)
| Field (Dart) | Tipe Dart | Rekomendasi Tipe DB | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | `String` | `UUID PRIMARY KEY` | ID sesi (dipakai di `/m/:id`) |
| `title` | `String` | `VARCHAR(150) NOT NULL` | Judul sesi mabar |
| `clubId` | `String` | `UUID REFERENCES clubs(id)` | Klub penyelenggara |
| `sportId` | `String` | `VARCHAR(30) NOT NULL` | Olahraga |
| `startsAt` / `endsAt` | `DateTime?` | `TIMESTAMPTZ NOT NULL` | Waktu mulai & selesai |
| `deadlineAt` | `DateTime?` | `TIMESTAMPTZ` | Batas waktu pembatalan |
| `venue` | `String` | `VARCHAR(150) NOT NULL` | Nama GOR / lapangan |
| `court` | `String` | `VARCHAR(50)` | Nomor/nama lapangan |
| `fee` | `int` | `INT DEFAULT 0` | Biaya per orang (Rupiah) |
| `slots` | `int` | `SMALLINT NOT NULL` | Kuota maksimal |
| `level` | `String` | `VARCHAR(50)` | Level pemain |
| `shuttle` | `String` | `VARCHAR(50)` | Info shuttlecock/bola |
| `guestMax` | `int` | `SMALLINT DEFAULT 2` | Maksimal tamu per user |
| `recurring` | `bool` | `BOOLEAN DEFAULT FALSE` | Jadwal berulang |
| `qris` | `bool` | `BOOLEAN DEFAULT TRUE` | Pembayaran via QRIS |
| `autoWaitlist` | `bool` | `BOOLEAN DEFAULT TRUE` | Otomatis naik dari waitlist |
| `cancelled` | `bool` | `BOOLEAN DEFAULT FALSE` | Status batal |
| `cancellationReason` | `String` | `TEXT` | Alasan batal |

**Tabel `session_participants` (`Participant`):**
- `id` (`UUID PK`), `session_id` (`UUID FK`), `user_id` (`UUID FK nullable` untuk tamu/Web-RSVP), `name` (`VARCHAR(100)`), `status` (`PayStatus`: `lunas`, `menunggu`, `belumBayar`), `host` (`BOOLEAN`), `via` (`VARCHAR(10)`: `APP` / `WEB`), `guest_of` (`UUID/VARCHAR`), `payment_expires_at` (`TIMESTAMPTZ`), `present` (`BOOLEAN`), `refunded` (`BOOLEAN`), `no_show` (`BOOLEAN`), `is_waitlist` (`BOOLEAN`), `created_at` (`TIMESTAMPTZ`).

---

### 3.6 `tournaments` & `court_matches` (dari `TournamentFormat`, `CourtMatch`, `ScoreConflict`)
- `tournaments`: `id` (`UUID PK`), `session_id` (`UUID FK`), `format` (`americano`, `mexicano`, `kingOfCourt`, `roundRobin`, `gugur`), `status` (`draft`, `live`, `finished`).
- `court_matches`: `id` (`UUID PK`), `tournament_id` (`UUID FK`), `court` (`SMALLINT`), `game` (`SMALLINT`), `team_a` (`TEXT`), `team_b` (`TEXT`), `score_a` (`SMALLINT`), `score_b` (`SMALLINT`), `done` (`BOOLEAN`).
- `score_conflicts`: `match_id` (`UUID FK`), `reported_by` (`UUID FK`), `score_a` (`SMALLINT`), `score_b` (`SMALLINT`), `resolved` (`BOOLEAN`).

---

### 3.7 `feed_posts`, `post_reactions`, `post_comments` (dari `FeedPost`, `Reaction`, `Comment`)
- `feed_posts`: `id` (`UUID PK`), `activity_id` (`UUID FK`), `user_id` (`UUID FK`), `club_id` (`UUID FK nullable`), `title`, `sport_id`, `stats` (`JSONB`), `has_route` (`BOOLEAN`), `splits` (`INT[]`), `segment_id` (`VARCHAR`), `created_at` (`TIMESTAMPTZ`).
- `post_reactions`: `post_id` (`UUID FK`), `user_id` (`UUID FK`), `emoji` (`VARCHAR(10)`). Unique `(post_id, user_id, emoji)`.
- `post_comments`: `id` (`UUID PK`), `post_id` (`UUID FK`), `user_id` (`UUID FK`), `text` (`TEXT`), `sticker` (`BOOLEAN`), `sticker_bg` (`BIGINT`), `sticker_fg` (`BIGINT`), `created_at` (`TIMESTAMPTZ`).

---

### 3.8 `goyang_invites` (dari `GoyangInvite` & `GoyangSettings`)
- `goyang_invites`: `id` (`UUID PK`), `sender_id` (`UUID FK`), `sport_id` (`VARCHAR(30)`), `when_type` (`SMALLINT`: `0` Sekarang, `1` 1 jam lagi, `2` Nanti malam), `audience` (`semuaTeman`, `klubku`, `temanDekat`), `nearby` (`BOOLEAN`), `venue` (`VARCHAR(150)`), `court_fee` (`INT`), `split` (`SMALLINT`), `created_at` (`TIMESTAMPTZ`).

---

## 4. Kebutuhan Sistem Notifikasi (Push & In-App)

Berdasarkan `NotificationService` (`clubs/mobile/lib/core/services/notification_service.dart`) dan flow aplikasi, berikut daftar notifikasi yang harus didukung Backend (via **FCM/APNs** + tabel `notifications` untuk halaman `/notifications`):

| Kategori | Event Trigger | Target Penerima | Contoh Pesan |
| :--- | :--- | :--- | :--- |
| **Streak & Habit** | Cron harian (default jam 20.00 lokal user) jika belum ada aktivitas hari itu | User | *"Streak kamu belum aman! 🔥 Rekam aktivitas 10 menit biar maskotmu tetap semangat."* |
| **Streak Freeze** | Saat Es Batu otomatis terpakai | User | *"Streak kamu diselamatkan oleh Es Batu! 🧊"* |
| **Mabar & Waitlist** | Ada peserta batal & slot waitlist naik otomatis | User teratas di `waitlist` | *"Slot mabar terbuka! Kamu naik dari daftar tunggu, segera selesaikan pembayaran."* |
| **Pembayaran QRIS** | Webhook Midtrans/Xendit `settlement` | Peserta & Host | *"Pembayaran QRIS lunas! Tiket mabar kamu sudah terbit."* |
| **Pembayaran Expired** | Batas waktu `payment_expires_at` habis | Peserta | *"Waktu pembayaran habis, slot kamu dilepas kembali."* |
| **Sesi Dibatalkan** | Host membatalkan sesi mabar | Semua `participants` | *"Sesi mabar [Judul] dibatalkan oleh Host."* |
| **Goyang (Shake)** | User mengirim `GoyangInvite` | Teman / Anggota Klub / Nearby (sesuai `quietHours` & `limitIncoming`) | *"[Nama] ngajak main [Olahraga] di [Venue]! Patungan Rp [Share]."* |
| **Sosial & Klub** | Ada komentar/stiker, reaksi Kudoz, pengumuman klub, atau approval join klub | Pemilik post / Member klub | *"[Nama] mengomentari aktivitasmu"* / *"Permintaan gabung klub disetujui"* |
| **Gear Tracker** | Jarak sepatu >= `limitKm` atau raket perlu restring | Pemilik Gear | *"Sepatu [Nama] sudah mencapai batas aman, waktunya cek kondisi sol!"* |

---

## 5. Kebutuhan API & Integrasi Eksternal
1. **Auth & OTP:** Request OTP (WhatsApp/SMS) & Verify OTP → JWT Token.
2. **Payment Gateway (QRIS):** Generate QRIS dinamis per RSVP, webhook callback status pembayaran, dan *disbursement* tarik dana kas klub.
3. **Web-RSVP (`klubby.id/m/:id`):** Endpoint publik ringan untuk melihat detail sesi dan submit RSVP tamu tanpa login aplikasi.
4. **Wearable & Strava:** Endpoint sinkronisasi data dari Google Health Connect / Apple HealthKit, serta **Strava Webhook** untuk menerima aktivitas otomatis.
5. **Validasi Anti-Cheat (Server-Side):** Verifikasi bahwa poin Leaderboard Klub hanya bertambah jika `ActivitySource` adalah Tier 1 (Smartwatch HR >= 30 menit, Scan QR Host yang valid, atau GPS valid).
6. **Privasi:** Pemotongan koordinat awal/akhir rute GPS (radius 500m) sebelum disimpan/ditampilkan ke publik.

---

## 6. Panduan Setup Supabase (Untuk Tim Backend)

Jika menggunakan **Supabase** sebagai BaaS/Database utama, berikut konfigurasi yang perlu disiapkan:

### 6.1 Extensions (Database → Extensions)
Aktifkan extension berikut di SQL Editor atau Dashboard Supabase:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";   -- Untuk query radius lokasi klub, mabar & goyang nearby
CREATE EXTENSION IF NOT EXISTS "pg_cron";   -- Untuk cron job reminder streak & expire pembayaran QRIS
CREATE EXTENSION IF NOT EXISTS "pg_net";    -- Untuk memanggil Edge Functions / webhook dari trigger DB
```

### 6.2 Authentication (Phone OTP)
1. Masuk ke **Authentication → Providers → Phone**.
2. Aktifkan **Phone Auth** dan hubungkan dengan provider SMS/WhatsApp (seperti Twilio, MessageBird, atau custom SMS/WA gateway Indonesia via Edge Function `send-sms` hook).
3. Pastikan setiap user baru yang terverifikasi OTP otomatis dibuatkan row di tabel `public.users` menggunakan **Database Trigger** pada `auth.users`:
   ```sql
   CREATE OR REPLACE FUNCTION public.handle_new_user()
   RETURNS TRIGGER AS $$
   BEGIN
     INSERT INTO public.users (id, phone, name, username)
     VALUES (NEW.id, NEW.phone, '', 'user_' || substr(NEW.id::text, 1, 8));
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql SECURITY DEFINER;

   CREATE TRIGGER on_auth_user_created
     AFTER INSERT ON auth.users
     FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
   ```

### 6.3 Storage Buckets (Storage)
Buat 3 bucket berikut dengan aturan akses:
1. `avatars` (Public read, authenticated user hanya bisa upload/update folder `uid/*`).
2. `club-logos` (Public read, hanya admin klub yang bisa upload).
3. `activity-photos` (Private/Signed URL atau sesuai `Privacy` post: `publik`, `pengikut`, `klub`).

### 6.4 Realtime (Database → Replication)
Aktifkan **Supabase Realtime** untuk tabel-tabel berikut agar UI mobile ter-update seketika tanpa polling:
* `club_messages` (Chat klub real-time).
* `court_matches` & `score_conflicts` (Live scoring turnamen).
* `mabar_sessions` & `session_participants` (Perubahan kuota slot & status waitlist).
* `goyang_invites` (Notifikasi ajakan main mendadak).

### 6.5 Row Level Security (RLS)
Aktifkan RLS (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`) di semua tabel `public`:
* **`users` / `gears` / `stamp_entries`:** User hanya boleh `UPDATE`/`DELETE` miliknya sendiri (`auth.uid() = user_id`).
* **`activities` & `feed_posts`:** `SELECT` mengikuti kolom `privacy` (`publik`, `pengikut` via tabel relasi follow, atau `klub` via keanggotaan klub).
* **`clubs` & `mabar_sessions`:** Semua user bisa `SELECT` klub/sesi publik; hanya `admin` klub atau `host` sesi yang boleh `UPDATE`/`DELETE`.
* **`club_kas` / `payout`:** Hanya anggota klub yang bisa `SELECT` buku kas; hanya `admin` yang bisa melakukan mutasi/tarik dana.

### 6.6 Supabase Edge Functions (Deno/TypeScript)
Buat Edge Functions berikut untuk logika server-side & integrasi eksternal:
1. `qris-create` & `qris-webhook`: Generate QRIS Midtrans/Xendit + verifikasi signature webhook untuk mengubah status `session_participants.status` menjadi `lunas` & mencatat pemasukan kas klub.
2. `web-rsvp`: Endpoint publik (tanpa JWT user) untuk melayani halaman `klubby.id/m/:id` agar peserta dari WhatsApp bisa RSVP sebagai tamu.
3. `strava-webhook`: Menerima event aktivitas dari Strava API dan menyimpannya sebagai aktivitas **Tier 1 (Verified)**.
4. `push-notify`: Mengirim Push Notification ke **FCM (Android)** dan **APNs (iOS)** berdasarkan event DB (waitlist naik, chat, komentar, goyang invite).
5. `cron-jobs` (dijadwalkan via `pg_cron`):
   * Cek pembayaran QRIS yang melewati `payment_expires_at` → ubah status/lepas slot & naikkan antrean `waitlist`.
   * Kirim pengingat streak harian jam 20.00 WIB/WITA/WIT bagi user yang belum berolahraga hari itu.
   * Hitung ulang klasemen & promosi/degradasi **Liga Komunitas** setiap akhir bulan.
