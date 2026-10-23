# PRODUCT REQUIREMENT DOCUMENT (PRD)

| **Project Name (Working Title)** | **Klubby / MabarCute** (Hybrid Sports Community & Habit App) |
|---|---|
| **Document Version** | 2.0.0 (Comprehensive Hybrid Edition) |
| **Status** | Approved & Ready for Technical Architecture |
| **Target Platform** | Mobile (iOS & Android) + Lightweight Web Companion (Web-RSVP) |
| **Core Inspiration** | **Reclub** (Logistik Mabar & Turnamen) + **Strava** (Dashboard, Tracking, Sensor, Gear) + **Duolingo** (Gamifikasi Stempel 2D & Streak) |

---

## 1. Latar Belakang & Visi Produk

### 1.1 Latar Belakang Masalah (Problem Statement)
1. **Strava Terlalu Mengintimidasi & Individualis:** Format Strava terfokus pada performa angka atlet elit (pace, heart rate, watt), membuat atlet kasual/sosial merasa minder. Tidak ada feed privat khusus komunitas, tidak ada stiker interaktif, dan tidak mendukung manajemen mabar olahraga tim/raket.
2. **Reclub Kehilangan "Habit Loop" & Dashboard Personal:** Begitu sesi mabar selesai, interaksi berhenti. Tidak ada linimasa terpadu, tidak ada pelacakan statistik multi-sport personal, dan tidak ada pemicu adiksi harian seperti *streaks*.
3. **Ketiadaan Peringkat Antarkomunitas (Leaderboard Void):** Tidak ada wadah adu gengsi keaktifan dan solidaritas antarkomunitas di tingkat area (Kecamatan/Kota) maupun tingkat Nasional.
4. **Friksi Pindah dari WhatsApp:** Penyelenggara mabar enggan pindah aplikasi jika seluruh anggotanya dipaksa mengunduh aplikasi sejak hari pertama.

### 1.2 Visi & Value Proposition
* **Visi:** Menjadi platform olahraga sosial nomor 1 di Asia Tenggara yang memadukan kehangatan komunitas, logistik mabar bebas pusing, dan pencatatan kebiasaan olahraga harian yang menggemaskan.
* **Value Proposition:** 
  * *Bagi Pengguna:* Dashboard kebugaran lengkap (multi-sport), buku stempel 2D harian, ruang aman feed komunitas, dan stiker chat ekspresif.
  * *Bagi Komunitas:* Sistem mabar otomatis (menggantikan keributan WhatsApp), generator turnamen instan tanpa Excel, dan panggung gengsi di Leaderboard Komunitas Kota/Nasional.

---

## 2. Target Pengguna (User Personas)

1. **Persona 1: "Sisca Si Pemain Kasual" (Casual/Social Athlete - 23 tahun)**
   * *Perilaku:* Main badminton/padel 2x seminggu, jogging santai di akhir pekan.
   * *Pain Point:* Malu posting di Strava karena larinya lambat. Capek berebut slot mabar di WhatsApp.
   * *Goal:* Mengoleksi stempel 2D lucu, memamerkan kartu streak di Instagram Story, dan upload foto mabar ke feed privat klub.
2. **Persona 2: "Budi Si Admin Komunitas" (Club Captain / Host Mabar - 31 tahun)**
   * *Perilaku:* Mengurus jadwal sewa lapangan badminton 50 member setiap Selasa dan Kamis malam.
   * *Pain Point:* Stres merekap mutasi transfer manual, pusing mengatur waiting list, dan repot bikin bagan turnamen di Excel.
   * *Goal:* RSVP otomatis, pembayaran langsung terverifikasi via QRIS dinamis, dan membawa klubnya masuk Top 10 se-Jakarta Selatan.
3. **Persona 3: "Rian Si Pemburu Rank" (Competitive Athlete - 27 tahun)**
   * *Perilaku:* Memakai smartwatch (Garmin/Xiaomi), berolahraga 5-6x seminggu demi mendongkrak poin klubnya di liga nasional.

---

## 3. Arsitektur Informasi & Navigasi Aplikasi (The 5-Tab Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ [Tab 1: Feed]   [Tab 2: Clubs]   [Tab 3: (+)]   [Tab 4: Ranks]   [Tab 5: Profile]│
└─────────────────────────────────────────────────────────────────────────────────┘
```

1. **Tab 1: Feed (Beranda Sosial):**
   * *Toggle Atas:* **Publik** (Semua pelari/pemain) vs. **Komunitas Saya** (Feed privat klub yang diikuti).
   * Menampilkan postingan aktivitas lengkap dengan peta rute/durasi, foto mabar, tombol reaksi *Kudoz* lucu, dan kolom komentar berbasis stiker.
2. **Tab 2: Komunitas & Mabar (Clubs & Meets - Ala Reclub):**
   * Direktori klub terdekat berbasis lokasi GPS (*Discovery*).
   * Jadwal sesi main bareng (*Meets*), kuota peserta, dan generator turnamen klub (Americano/Mexicano/Round Robin).
   * Ruang obrolan internal klub & pengumuman penting (*Announcements*).
3. **Tab 3: Aksi Cepat / Record (+ Button):**
   * *Buat Sesi Mabar Baru* (untuk Host).
   * *Scan QR Check-in Lapangan* (verifikasi kehadiran di venue).
   * *Mulai Rekam Olahraga Mandiri* (GPS lari/jalan dengan audio split).
4. **Tab 4: Leaderboard (Peringkat Komunitas Area & Nasional):**
   * *Peringkat Area:* Top komunitas di tingkat Kecamatan/Kota (misal: "Top Badminton Jakarta Selatan").
   * *Peringkat Nasional:* Liga Komunitas Indonesia (Divisi Utama, Divisi 1) dengan siklus promosi-degradasi bulanan.
5. **Tab 5: Profile & Dashboard Personal ("You" - Ala Strava + Duolingo):**
   * *Header:* Foto profil, level karakter 2D, badge komunitas, dan tombol **Settings ⚙️**.
   * *Sub-Tab 1: Athlete Dashboard:* Total jam olahraga, total jarak, kalori, dan diagram porsi cabang olahraga (*Multi-Sport Pie Chart*).
   * *Sub-Tab 2: Buku Stempel 2D & Streak:* Kalender stempel harian, evolusi karakter, dan tombol ekspor kartu Instagram Story.
   * *Sub-Tab 3: Riwayat Pertandingan & Rating:* Rekor menang-kalah mabar, skor pertandingan, level keterampilan (*Skill Level / DUPR*).
   * *Sub-Tab 4: Gear Tracker:* Pelacak jarak tempuh sepatu lari dan usia tarikan senar raket.

---

## 4. Rincian Spesifikasi Kebutuhan Fungsional (Feature Specs)

### Modul 1: Manajemen Sesi Mabar & Integrasi WhatsApp (Pilar Reclub)
* **F-1.1 Pembuat Jadwal Sesi (Host Meeting Creator):** Penentuan tanggal, jam, kuota, venue, biaya, dan batas waktu pembatalan.
* **F-1.2 Sistem RSVP & Waiting List Otomatis:** Urutan pendaftar tercatat transparan. Jika kuota penuh, pendaftar berikutnya otomatis masuk daftar tunggu dan akan naik otomatis saat ada yang batal.
* **F-1.3 Fitur Tamu (+1 / +2 Guest):** Peserta dapat mendaftarkan slot untuk teman non-aplikasi.
* **F-1.4 WhatsApp Web-RSVP Link:** Host menekan *"Share to WhatsApp"*, menghasilkan teks rekap jadwal + tautan webview ringan. Peserta di WhatsApp bisa langsung konfirmasi hadir via browser tanpa harus menginstal aplikasi terlebih dahulu.

### Modul 2: Engine Turnamen & Pertandingan (Pilar Reclub)
* **F-2.1 Format Turnamen Bawaan (No-Excel Needed):**
  * *Round Robin:* Semua peserta/tim saling berhadapan.
  * *Americano & Mexicano:* Format rotasi partner di setiap babak untuk olahraga raket (padel/badminton/tenis) dengan akumulasi skor individu.
  * *King of the Court:* Sistem tangga lapangan (*ladder*); pemenang naik ke top court, yang kalah turun lapangan.
  * *Single & Double Elimination Brackets:* Bagan sistem gugur resmi.
* **F-2.2 Live Scoring & Papan Klasemen Real-Time:** Wasit atau pemain menginput skor pertandingan langsung dari ponsel; klasemen ter-update seketika.

### Modul 3: Athlete Dashboard, Sensor Sync, & Gear Tracker (Pilar Strava)
* **F-3.1 Personal Multi-Sport Dashboard:**
  * Menampilkan ringkasan jam olahraga mingguan/bulanan.
  * Visualisasi porsi olahraga (misal: 60% Badminton, 30% Lari, 10% Tenis).
* **F-3.2 Gear Tracker (Pelacak Perlengkapan Olahraga):**
  * *Sepatu Lari:* Peringatan otomatis jika sol sepatu sudah mencapai batas aman (misal 500–800 km) untuk mencegah cedera.
  * *Raket Badminton/Tenis:* Mencatat tanggal penarikan senar dan jumlah jam pakai untuk mengingatkan jadwal ganti senar.
* **F-3.3 Sinkronisasi Otomatis Smartwatch (Termasuk Brand Terjangkau):**
  * *Google Health Connect (Android):* Menarik data otomatis dari Samsung Galaxy Watch, Amazfit (Zepp), Google Pixel, dan Xiaomi Band (Mi Fitness).
  * *Apple HealthKit (iOS):* Menarik sesi latihan, denyut jantung, dan kalori dari Apple Watch.
  * *Connect with Strava (Shortcut):* Webhook API untuk pengguna Garmin, Coros, Wahoo, dan Suunto.

### Modul 4: Sistem Anti-Kecurangan 2-Tier (Anti-Cheat Engine)
Menjamin integritas Leaderboard Komunitas dengan membagi validitas aktivitas ke dalam 2 tingkatan:

| Parameter | Tier 1: Verified Activity | Tier 2: Casual Activity |
|---|---|---|
| **Kriteria Bukti** | Data Smartwatch (ada Heart Rate min. 30 menit) **ATAU** Scan QR Host di Lapangan **ATAU** Rekaman GPS Valid. | Input manual tanpa bukti sensor/kehadiran. |
| **Stempel 2D Harian** | ✅ Diberikan | ✅ Diberikan |
| **Streak Harian** | ✅ Dihitung | ✅ Dihitung |
| **Poin Leaderboard Komunitas**| **100% Masuk ke Klub** | **0 Poin (Tidak Masuk ke Klub)** |

### Modul 5: Gamifikasi 2D, Kalender Stempel, & Stiker (Pilar Duolingo)
* **F-5.1 Kalender Stempel 2D (Stamp Card):** Selesai 1 sesi olahraga $\rightarrow$ stempel kartun 2D lucu tercap di kalender hari itu.
* **F-5.2 Evolusi Karakter Streak (RPG-Style):**
  * *Day 1–6:* Hewan kecil lucu dengan pita/headband pemula.
  * *Day 7 (1 Minggu):* Karakter bersinar + membuka stiker chat eksklusif.
  * *Day 14 (2 Minggu):* Membuka bingkai profil avatar baru.
  * *Day 30 (1 Bulan):* Karakter berevolusi membawa piala dan jubah juara.
* **F-5.3 Kartu Ekspor Instagram Stories:** Kartu visual estetik resolusi 9:16 yang memamerkan avatar, stempel streak, dan recap olahraga untuk dibagikan ke IG Story/TikTok.
* **F-5.4 Kolom Komentar Berbasis Stiker (Sticker-First Social):** Stiker celoteh olahraga lokal ("Betis Pedes", "Ayo Rematch!", "Napas Habis", "Paha Gemetar").

### Modul 6: Group-Exclusive Feed & Keamanan (Pilar Privasi Strava)
* **F-6.1 Opsi Privasi Postingan:** Pilihan saat simpan aktivitas: *Public*, *Followers*, atau *Hanya untuk Komunitas [Nama Klub]*.
* **F-6.2 Privacy Zones:** Menyembunyikan titik awal dan akhir rute GPS dalam radius 500 meter di sekitar rumah/kantor pengguna.
* **F-6.3 Beacon (Fitur Keamanan Lari):** Berbagi tautan lokasi GPS langsung (*live location link*) ke kontak darurat saat berolahraga di luar ruangan.

### Modul 7: Leaderboard Komunitas Tingkat Area & Nasional
* **F-7.1 Formula Poin Keaktifan Komunitas (*Club Activity Score*):**
  $$\text{Total Poin} = \sum (\text{Jam Olahraga Verified}) \times 10 + (\text{Kehadiran Sesi Mabar}) \times 25 + (\text{Bonus Streak Aktif}) \times 5$$
* **F-7.2 Leaderboard Area:** Peringkat komunitas per Kecamatan/Kota.
* **F-7.3 Liga Komunitas Nasional:** Sistem divisi (Divisi Utama, Divisi 1) dengan siklus promosi dan degradasi setiap akhir bulan.

### Modul 8: Sistem Finansial & Kas Mabar (Pembayaran QRIS)
* **F-8.1 Integrasi QRIS Dinamis Otomatis:** Peserta yang RSVP langsung diarahkan membayar via QRIS. Status otomatis berubah menjadi *Paid* seketika tanpa cek mutasi manual.
* **F-8.2 Buku Kas Mabar Transparan:** Laporan mutasi uang sewa lapangan dan shuttlecock/bola yang dapat dipantau oleh seluruh anggota.

---

## 5. Rencana & Strategi Monetisasi

1. **Fase 1: Transaksi Lapangan & Mikrotransaksi B2C (Day 1 Cash Flow):**
   * *Fee Layanan QRIS:* Biaya admin Rp 1.500 – Rp 2.500 per pembayaran slot mabar.
   * *Kosmetik Stiker & Avatar:* Pembelian bundle stiker ilustrator lokal dan tema stempel musiman seharga Rp 10.000 – Rp 20.000.
2. **Fase 2: Langganan Pengurus Klub (*Club Pro Tier* - B2B):**
   * Paket langganan Rp 49.000 – Rp 99.000/bulan untuk fitur: anggota tak terbatas, upload stiker logo komunitas sendiri, dan broadcast otomatis ke WhatsApp member.
3. **Fase 3: Sponsor Brand & Venue Lapangan (B2B Enterprise):**
   * Brand minuman isotonik/apparel menjadi sponsor resmi *Leaderboard Area* (hadiah jersey dan produk untuk Top 3 klub).
   * Pengelola lapangan GOR mendaftar sebagai *Official Venue Partner* untuk mempromosikan jam lapangan sepi ke komunitas terdekat.

---

## 6. Pedoman Desain Visual & Interaksi (Duolingo-Inspired Design DNA)

Aplikasi ini wajib mengadopsi prinsip desain visual dan interaksi mikro (*micro-interactions*) khas **Duolingo**, yang membuat aktivitas rutin terasa seperti bermain game kasual:

### 6.1 Karakter Maskot & Emosi Adaptif
* **Maskot Utama:** Karakter hewan kartun 2D ekspresif (misal: *Kiko si Kucing Energik*).
* **Animasi Emosi:**
  * *Joy / Celebration:* Melompat kegirangan dengan konfeti saat pengguna menyelesaikan sesi mabar atau memperpanjang streak.
  * *Gentle Nudge:* Pose cemas lucu pada jam 20.00 jika pengguna belum melakukan aktivitas fisik hari itu (*"Streak 14 harimu terancam! Yuk jalan kaki 15 menit!"*).
  * *Cheering Up:* Memberi pelukan hangat saat tim pengguna kalah di sesi mabar (*"Nggak apa-apa, kamu sudah berjuang hebat hari ini!"*).

### 6.2 Gaya Tombol & Komponen "Chunky 3D Tactile"
* **Tombol Membal (Press-Down Effect):** Tombol memiliki bayangan tebal di bawah (`border-b-4`). Saat pengguna menyentuh layar, tombol bergerak turun 3-4 piksel dengan sensasi pegas yang membal.
* **Super Rounded Corners:** Kartu, modal popup, dan badge menggunakan lengkungan sudut tebal (`rounded-2xl` hingga `rounded-full`).
* **Palet Warna Ceria:** Warna dasar putih bersih dengan aksen warna primer yang segar dan berenergi (Hijau Daun, Oranye Jeruk, Kuning Lemon, dan Biru Laut cerah).

### 6.3 Hadiah Sensorik (Haptics, Sound FX, & Confetti)
* **Haptic Feedback:** Setiap kali stempel harian tercap di kalender atau tombol *RSVP Going* ditekan, ponsel bergetar halus (*tactile thump*).
* **Sound Effects (SFX):** Efek suara khas game kasual (suara cap stempel berdebam *"Buk!"*, suara bintang berdenting *"Ting! 🌟"*, dan sorak penonton kecil saat menang mabar).
* **Konfeti Bintang:** Letupan partikel bintang 2D warna-warni saat mencapai milestone streak (hari ke-7, 14, 30).

### 6.4 Mekanisme "Streak Freeze" (Penyelamat Streak)
* Pengguna memiliki kuota item **"Streak Freeze / Es Batu Pelindung"**.
* Jika pengguna sakit, lembur kantor, atau cuaca ekstrem, *Streak Freeze* otomatis aktif untuk menjaga agar angka streak tidak kembali ke nol.

### 6.5 Tipografi Ramah (Rounded Typography)
* Font utama menggunakan tipografi bulat modern (seperti **Nunito Rounded, Fredoka, atau Poppins Rounded**) sehingga angka-angka durasi olahraga tidak terkesan kaku seperti spreadsheet.

---

## 7. Rekomendasi Tech Stack

| Komponen | Pilihan Teknologi | Alasan |
|---|---|---|
| **Mobile App** | **Flutter (Dart)** | Performa animasi 60fps untuk stempel 2D & cross-platform (iOS & Android) dari satu basis kode. |
| **Web Companion** | **Next.js + TailwindCSS** | Halaman Web-RSVP ringan yang cepat dibuka dari link WhatsApp. |
| **Backend & DB** | **Go / Node.js + PostgreSQL (Supabase)** | PostgreSQL unggul untuk kueri spasial lokasi klub & Supabase memiliki real-time database untuk live score. |
| **Integrasi Health** | Health Connect SDK, Apple HealthKit API, Strava Webhook | Mendukung 99% smartwatch dari Apple, Garmin, hingga Xiaomi Band. |
| **Payment Gateway**| **Midtrans / Xendit** | Penyedia QRIS dinamis dan Virtual Account paling stabil di Indonesia. |
| **Cloud Storage** | AWS S3 / Cloudinary | Kompresi otomatis media dokumentasi mabar dan stiker vektor. |

---

## 8. Roadmap Peluncuran (MVP s/d V2.0)

* **Fase 1: MVP (Bulan 1–2):** 
  * Pelacakan aktivitas manual & Strava Sync.
  * Kalender Stempel 2D & Streak 7 hari.
  * Manajemen Sesi Mabar dasar & Web-RSVP WhatsApp link.
  * Tab Profile dengan Multi-Sport Dashboard dasar.
* **Fase 2: Community & Wearable Expansion (Bulan 3–4):**
  * Integrasi Google Health Connect & Apple HealthKit (dukungan penuh Xiaomi/Huawei).
  * Sistem Anti-Kecurangan 2-Tier & QR Check-in lapangan.
  * Peluncuran Leaderboard Area (Tingkat Kota).
  * Pembayaran iuran mabar otomatis via QRIS dinamis.
* **Fase 3: National League & Monetization Scale (Bulan 5–6):**
  * Liga Komunitas Nasional (Promosi/Degradasi bulanan).
  * Engine Turnamen Lengkap (Americano, Mexicano, King of the Court).
  * Portal sponsorship brand untuk hadiah komunitas terbaik.
  * Peluncuran paket langganan *Club Pro*.
