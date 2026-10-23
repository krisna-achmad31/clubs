# MASTER BLUEPRINT: KLUBBY / MABARCUTE
### Dokumentasi Lengkap Konsep Produk, Seluruh Fitur, Solusi Celah, Desain Karakter 2D, & Implementasi pen.dev

> **Versi Dokumen:** 3.0.0 (Master Comprehensive Edition)  
> **Status:** Final & Siap Eksekusi Teknis  
> **Platform Target:** Mobile App (Flutter / React Native - iOS & Android) + Web Companion (Next.js Web-RSVP)  
> **Inspirasi Utama:** **Reclub** (Logistik Mabar & Turnamen) + **Strava** (Tracking, Dashboard, Gear) + **Duolingo** (Gamifikasi 2D, Karakter & Streak)

---

## DAFTAR ISI
1. [Ringkasan Eksekutif & Value Proposition](#1-ringkasan-eksekutif--value-proposition)
2. [Katalog Seluruh Fitur Lengkap (10 Modul)](#2-katalog-seluruh-fitur-lengkap-10-modul)
3. [Daftar Celah, Risiko, dan Solusi Tuntas](#3-daftar-celah-risiko-dan-solusi-tuntas)
4. [Dukungan Smartwatch & Perangkat Murah](#4-dukungan-smartwatch--perangkat-murah)
5. [Desain Karakter Kartun Duolingo & Animasi Perenang](#5-desain-karakter-kartun-duolingo--animasi-perenang)
6. [Arsitektur Layar Mobile & Implementasi Canvas pen.dev](#6-arsitektur-layar-mobile--implementasi-canvas-pendev)
7. [Rekomendasi Tech Stack & Infrastruktur](#7-rekomendasi-tech-stack--infrastruktur)
8. [Strategi Monetisasi Berjenjang](#8-strategi-monetisasi-berjenjang)
9. [Daftar File & Aset Proyek](#9-daftar-file--aset-proyek)

---

## 1. Ringkasan Eksekutif & Value Proposition

### 1.1 Latar Belakang Masalah
* **Strava Terlalu Kaku & Mengintimidasi:** Terlalu fokus pada angka performa atletik (pace, detak jantung, watt). Atlet santai merasa minder, tidak bisa posting khusus grup privat, dan tidak ada interaksi stiker lucu.
* **Reclub Kehilangan Habit Loop Pasca-Mabar:** Selesai main bersama, interaksi mati. Tidak ada dorongan psikologis harian untuk kembali berolahraga dan tidak ada leaderboard antarkomunitas se-kota/se-Indonesia.
* **Tingginya Hambatan Pindah dari WhatsApp:** Pengurus komunitas enggan pindah aplikasi jika seluruh anggotanya dipaksa mengunduh aplikasi sejak hari pertama.

### 1.2 Solusi & Visi Produk ("Klubby")
Menggabungkan utilitas logistik komunitas **Reclub**, dashboard analitik multi-sport **Strava**, dengan kehangatan psikologi gamifikasi **Duolingo** (stempel 2D lucu, maskot emosional, dan sistem peringkat komunitas tingkat kota/nasional).

---

## 2. Katalog Seluruh Fitur Lengkap (10 Modul)

### Modul 1: Logistik Sesi Mabar (Pilar Reclub)
1. **Pembuat Jadwal Sesi (Host Meet Creator):** Penentuan tanggal, jam, kuota lapangan, biaya iuran, dan batas waktu pembatalan (*cancellation deadline*).
2. **Sistem RSVP & Waiting List Otomatis:** Sistem antrean transparan berbasis waktu (*first-come, first-served*). Jika kuota penuh (misal 12/12), pendaftar berikutnya masuk daftar tunggu dan otomatis naik jika ada yang batal.
3. **Fitur Tambah Tamu (+1 / +2 Guest):** Member dapat memesankan slot untuk teman yang belum memiliki aplikasi.
4. **WhatsApp Web-RSVP Link (Solusi Anti-Ribet):** Host menekan tombol *"Share to WhatsApp"*, menghasilkan teks rekap jadwal + tautan web ringan. Peserta di grup WhatsApp bisa langsung klik dan konfirmasi hadir lewat browser tanpa wajib instal aplikasi terlebih dahulu.

### Modul 2: Engine Turnamen & Pertandingan Bawaan (No-Excel Needed)
1. **Americano & Mexicano:** Format rotasi pasangan di setiap babak untuk olahraga raket (Padel, Badminton, Tenis) dengan akumulasi skor individu. Mexicano memasangkan pemain berdasarkan peringkat poin sementara.
2. **King of the Court:** Format tangga lapangan (*ladder*); pemenang naik ke lapangan utama (*top court*), yang kalah turun lapangan.
3. **Round Robin & Brackets:** Format setengah kompetisi atau bagan sistem gugur (*single/double elimination*).
4. **Live Scoring:** Wasit atau pemain memasukkan skor langsung dari ponsel, papan klasemen ter-update secara *real-time*.

### Modul 3: Activity Tracking & Wearable Sync Engine
1. **Google Health Connect (Android):** Sinkronisasi otomatis data olahraga, denyut jantung, dan kalori dari Samsung Galaxy Watch, Amazfit (Zepp), Google Pixel, dan Xiaomi Band (Mi Fitness).
2. **Apple HealthKit (iOS):** Membaca sesi latihan (*Workouts*), GPS rute, heart rate, dan kalori dari Apple Watch.
3. **Connect with Strava (Shortcut Universal):** Menangkap webhook selesai aktivitas dari Garmin, Wahoo, Coros, dan Suunto.

### Modul 4: Sistem Validasi Anti-Kecurangan 2-Tier
Mencegah "olahraga fiktif / ghost workout" demi menjaga keadilan kompetisi:
* **Tier 1 (Verified Activity):** Didukung sensor smartwatch (heart rate min. 30 menit) **ATAU** Scan QR Host di Lapangan GOR **ATAU** GPS Tracking valid. $\rightarrow$ **Dapat Stempel 2D + 100% Poin Masuk Leaderboard Klub**.
* **Tier 2 (Casual Manual Input):** Pengguna input manual tanpa bukti sensor/kehadiran. $\rightarrow$ **Dapat Stempel 2D Personal + 0 Poin ke Leaderboard Klub** (menjaga kepuasan pengguna santai tanpa merusak peringkat liga).

### Modul 5: Gamifikasi 2D, Kalender Stempel, & RPG Streak (Pilar Duolingo)
1. **Buku Stempel 2D (Stamp Card):** Setiap menyelesaikan 1 sesi olahraga, kalender hari itu mendapatkan cap stempel 2D kartun lucu.
2. **Evolusi Karakter Streak (RPG Leveling):**
   * *Day 1 (Baby Paddle):* Karakter pemula dengan pelampung bebek.
   * *Day 3 (Crawl Speed):* Karakter gesit dengan kacamata renang.
   * *Day 7 (Mode Kincir Angin Turbo):* Tangan berputar 360° cepat seperti baling-baling kincir dengan semburan ombak speedboat!
   * *Day 14 (Champion Phase):* Membuka jubah juara dan kacamata hitam keren.
   * *Day 30 (Golden Legend):* Membuka sayap emas dan mahkota juara bertabur permata.
3. **Item "Streak Freeze" (Es Batu Pelindung):** Penyelamat streak agar rekor tidak hangus jika pengguna sakit, lembur kerja, atau cuaca buruk.
4. **Generator Kartu Instagram Stories:** Konversi 1-klik rekapan olahraga ke rasio 9:16 yang estetik untuk dipamerkan ke IG Story/TikTok.

### Modul 6: Group-Exclusive Feed & Interaksi Stiker
1. **Opsi Privasi Postingan:** Pilihan saat simpan aktivitas: *Publik*, *Followers*, atau *Hanya untuk Komunitas [Nama Klub]*.
2. **Komentar Berbasis Stiker (*Sticker-First Social*):** Stiker celoteh lokal khas olahraga ("Betis Pedes 🦵🌶️", "Ayo Rematch! 🏸🔥", "Napas Habis 😮‍💨", "Traktir Es 🧋").
3. **Kudoz Reaksi Imut:** Tombol reaksi ekspresif: 🏸, 🎾, 🏃, 🧃, 🔥, 👑.

### Modul 7: Leaderboard Komunitas Tingkat Area & Nasional
1. **Formula Poin Keaktifan Komunitas (*Club Activity Score*):**
   $$\text{Poin Klub} = \sum (\text{Jam Olahraga Verified} \times 10) + (\text{Kehadiran Mabar Resmi} \times 25) + (\text{Bonus Streak Anggota} \times 5)$$
2. **Leaderboard Area (Kecamatan/Kota):** Persaingan klub teraktif di Jakarta Selatan, Surabaya, Denpasar, dll.
3. **Liga Komunitas Nasional:** Sistem divisi (Divisi Utama, Divisi 1) dengan siklus promosi dan degradasi setiap akhir bulan.

### Modul 8: Sistem Finansial & Kas Mabar (QRIS Dinamis)
1. **Pembayaran Otomatis QRIS:** Peserta yang RSVP langsung diarahkan membayar via QRIS. Status seketika berubah menjadi *Confirmed/Paid* tanpa admin perlu cek mutasi rekening.
2. **Buku Kas Mabar Transparan:** Laporan otomatis dana sewa lapangan dan shuttlecock/bola yang dapat dipantau bersama oleh seluruh anggota.

### Modul 9: Athlete Dashboard & Gear Tracker (Pilar Strava)
1. **Multi-Sport Breakdown:** Diagram visual porsi cabang olahraga yang ditekuni (misal: 50% Badminton, 26% Renang, 24% Lari).
2. **Gear Tracker (Pelacak Perlengkapan):**
   * *Sepatu Lari:* Peringatan otomatis jika sol sepatu sudah mencapai batas aman (misal 500–800 km) untuk mencegah cedera.
   * *Raket Badminton/Tenis:* Mencatat tanggal penarikan senar dan jam pemakaian untuk pengingat servis.

### Modul 10: Keamanan & Privasi Atlet
1. **Privacy Zones:** Menyamarkan titik awal dan akhir rute GPS dalam radius 500 meter di sekitar rumah/kantor pengguna.
2. **Beacon:** Berbagi tautan pelacakan lokasi GPS langsung (*live location link*) ke kontak darurat saat olahraga luar ruang.

---

## 3. Daftar Celah, Risiko, dan Solusi Tuntas

| Celah / Risiko | Dampak Potensial | Solusi Tuntas & Mitigasi |
|---|---|---|
| **1. Olahraga Palsu / Ghost Workout** | Pengguna klik manual demi streak atau menaikkan ranking klub secara curang. | **Sistem Validasi 2-Tier:** Poin Leaderboard Klub **hanya dihitung** dari aktivitas yang terverifikasi smartwatch (Heart Rate) atau Scan QR di GOR. Input manual hanya dapat stempel pribadi. |
| **2. Hambatan Pindah dari WhatsApp** | Anggota klub malas mengunduh aplikasi baru hanya untuk mendaftar mabar. | **Jembatan Web-RSVP Link:** Host membuat jadwal di aplikasi, lalu klik "Share ke WhatsApp". Anggota di WA bisa langsung RSVP lewat browser tanpa wajib install aplikasi di hari pertama. |
| **3. Benturan "Lucu" vs "Gengsi Peringkat"** | Pemain kompetitif merasa aplikasi terlalu kekanak-kanakan. | **Konsep Evolusi RPG (Shonen Style):** Karakter imut berevolusi menjadi gagah dan prestisius (membawa mahkota emas, aura petir, dan jubah juara) saat level streak bertambah. |
| **4. Beban Biaya Desain Stempel** | Biaya ilustrator mahal untuk memproduksi ratusan variasi stempel dan stiker. | **Pipeline Hybrid AI + UGC Market:** Base aset diproduksi cepat dengan prompt AI vector, disempurnakan oleh 1 desainer, lalu membuka pasar stiker kreator lokal (skema bagi hasil 70/30 ala LINE). |
| **5. Jebakan Monetisasi Awal** | Brand besar belum mau mensponsori sebelum pengguna mencapai puluhan ribu. | **Monetisasi Transaksi Lapangan (Day-1 Cash Flow):** Mengambil biaya admin layanan QRIS sebesar Rp 1.500 – Rp 2.500 per pembayaran slot mabar. |

---

## 4. Dukungan Smartwatch & Perangkat Murah

Pengguna tidak diwajibkan membeli jam mahal (seperti Garmin atau Apple Watch) untuk mendapatkan status aktivitas terverifikasi (*verified*):

* **Xiaomi Smart Band & Redmi Watch (Rp 200rb - Rp 400rb):** Menggunakan aplikasi *Mi Fitness* $\rightarrow$ Profile $\rightarrow$ Third-Party Data $\rightarrow$ Hubungkan ke **Strava / Google Health Connect**.
* **Amazfit Bip / Band (Rp 300 ribuan):** Menggunakan aplikasi *Zepp* $\rightarrow$ Profile $\rightarrow$ Add Accounts $\rightarrow$ Hubungkan langsung ke **Strava / Google Health Connect**.
* **Huawei Band 7/8/9 (Rp 400 ribuan):** Menggunakan aplikasi *Huawei Health* $\rightarrow$ Me $\rightarrow$ Privacy Management $\rightarrow$ Data Sharing $\rightarrow$ **Strava**.
* **Bagi Pengguna Tanpa Smartwatch Sama Sekali:** Cukup melakukan **Scan QR Check-in di Lapangan GOR** yang dibuka oleh Host saat sesi mabar berlangsung.

---

## 5. Desain Karakter Kartun Duolingo & Animasi Perenang

Mengadopsi referensi visual karakter **Eddy dari Duolingo** (tubuh bulat membal, rambut pirang ceria, hoodie atletik merah, dan ekspresi tertawa ngakak lepas):

```
[HARI 1: PEMULA]             [HARI 3: GESIT]              [STREAK 7+ HARI: TURBO]
Pelampung Bebek Kuning       Baju Renang Sporty           Mode Kincir Angin 360°
Gaya Kepik Santai            Gaya Bebas Ritmis            Pusaran Ombak Speedboat
Pace: 0.8 km/h               Pace: 2.4 km/h               Pace: 9.8 km/h (MOTORBOAT!)
(Senyum Bangga)              (Fokus Semangat)             (Ngakak Lepas ala Eddy)
```

### Aset yang Telah Diproduksi:
1. **Simulasi Animasi Interaktif HTML:** File `swimmer_evolution.html` (dapat dicoba interaktif dengan tombol Hari 1, Hari 3, dan Streak 7+ Mode Kincir).
2. **File Animasi Lottie `.json`:** File `swimmer_streak_animation.json` dengan marker timeline siap pakai untuk Flutter / React Native.
3. **Ilustrasi 2D Hasil Render AI:** Diterapkan langsung pada canvas pen.dev sebagai aset ilustrasi karakter resolusi tinggi.

---

## 6. Arsitektur Layar Mobile & Implementasi Canvas pen.dev

Canvas **pen.dev** saat ini telah memuat 2 Board Galeri Aset dan 5 Layar Mobile Lengkap (ukuran 390 x 844 px):

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [Board 1: 2D Cute Assets & Items (2150x600)]    [Board 2: Swimmer Streak Evolution (950x680)]    │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [Screen 1: Feed]  [Screen 2: Clubs]  [Screen 3: Record]  [Screen 4: Leaderboard]  [Screen 5: You] │
│ (390 x 844 px)    (390 x 844 px)     (390 x 844 px)      (390 x 844 px)           (390 x 844 px)  │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Screen 1 (Home Feed):** Segment toggle (Komunitas vs Publik), kartu aktivitas mabar dengan rute/durasi, stempel harian tercap, reaction Kudoz, dan komentar stiker lucu.
2. **Screen 2 (Clubs & Mabar):** Header klub Smash & Chill SCBD, slot 12/12 penuh, waiting list 3 orang, tombol share WhatsApp, dan live widget turnamen Americano.
3. **Screen 3 (Record & Check-in):** Stopwatch live, detak jantung 152 bpm, status *Xiaomi Band 8 Connected*, scanner QR lapangan, dan tombol membal 3D.
4. **Screen 4 (Community Leaderboards):** Header Liga Jakarta Selatan vs Nasional, podium 1, 2, 3 klub teraktif, countdown akhir musim, dan poin kontribusi member.
5. **Screen 5 (Profile & Buku Stempel):** Avatar level 14 perenang turbo, menu settings ⚙️, kalender stempel bulanan, status *Streak Freeze*, diagram porsi olahraga (*multi-sport pie chart*), pelacak masa pakai sepatu (*Gear Tracker*), dan tombol *Share to IG Story*.

---

## 7. Rekomendasi Tech Stack & Infrastruktur

| Layer | Rekomendasi Teknologi | Alasan Pemilihan |
|---|---|---|
| **Mobile Frontend** | **Flutter (Dart)** | Animasi 60fps untuk gamifikasi 2D, satu codebase untuk iOS dan Android. |
| **Web Companion** | **Next.js + TailwindCSS** | Web-RSVP ringan yang cepat terbuka di in-app browser WhatsApp. |
| **Backend & Realtime** | **Go / Node.js + Supabase (PostgreSQL)** | Kueri spasial lokasi lapangan klub + database real-time untuk skor mabar dan leaderboard. |
| **Integrasi Wearable** | Google Health Connect, Apple HealthKit, Strava API | Kompatibel dengan Apple Watch, Garmin, hingga smartband Xiaomi dan Huawei. |
| **Payment Gateway** | **Midtrans / Xendit** | Penerbitan QRIS dinamis instan dan verifikasi pembayaran kas otomatis. |
| **Animasi & Grafis** | Lottie (.json) + Vector SVG | Ringan, tajam di semua resolusi layar, dan hemat baterai. |

---

## 8. Strategi Monetisasi Berjenjang

1. **Fase 1: Transaksi Lapangan & Mikrotransaksi (Bulan 1–3):**
   * *Fee Layanan QRIS:* Biaya admin Rp 1.500 – Rp 2.500 per pembayaran slot mabar.
   * *In-App Purchases (Mikrotransaksi):* Pembelian stiker eksklusif lokal dan kostum avatar 2D seharga Rp 10.000 – Rp 20.000.
2. **Fase 2: Langganan Pengurus Komunitas (Bulan 4–6):**
   * Paket langganan *Club Pro* Rp 49.000 – Rp 99.000/bulan untuk kuota anggota tak terbatas, analitik keuangan kas mendalam, dan upload stiker logo komunitas sendiri.
3. **Fase 3: Sponsor Brand & Venue Lapangan (Bulan 7+):**
   * Brand minuman isotonik/apparel menjadi sponsor resmi *Leaderboard Area* (hadiah jersey dan produk untuk Top 3 klub).
   * Pengelola lapangan GOR mendaftar sebagai *Official Venue Partner* untuk mempromosikan jam lapangan sepi ke komunitas terdekat.

---

## 9. Daftar File & Aset Proyek

Seluruh file spesifikasi, dokumentasi riset, animasi, dan desain telah tersimpan rapi di dalam workspace:

| Nama File | Lokasi File | Deskripsi |
|---|---|---|
| **Master Blueprint (Dokumen Ini)** | [MASTER_KLUBBY_BLUEPRINT.md](file:///Users/macbookair/Documents/reclubV2/MASTER_KLUBBY_BLUEPRINT.md) | Dokumen master lengkap 1 pintu untuk seluruh konsep, fitur, celah, dan desain. |
| **Product Requirement Document (PRD)** | [PRD_SPORTS_COMMUNITY_APP.md](file:///Users/macbookair/Documents/reclubV2/PRD_SPORTS_COMMUNITY_APP.md) | Spesifikasi kebutuhan produk formal untuk engineering dan UI/UX. |
| **Animasi Lottie (.json)** | [swimmer_streak_animation.json](file:///Users/macbookair/Documents/reclubV2/swimmer_streak_animation.json) | File animasi vector Lottie untuk perenang lambat s/d mode kincir angin. |
| **Simulasi Animasi Interaktif HTML** | [swimmer_evolution.html](file:///Users/macbookair/.gemini/antigravity/brain/0d64fe5a-c631-4912-a7fa-15e099243bbf/swimmer_evolution.html) | Widget simulasi interaktif yang bisa diklik untuk melihat gerak perenang. |
| **Desain Canvas pen.dev** | `/Users/macbookair/.pencil/documents/3f5d21ad-461b-4de6-9a4a-dd4f173f5249/untitled.pen` | File canvas aktif pen.dev berisi 2 Board Aset & 5 Layar Mobile. |
| **Riset Fitur Reclub** | [reclub_features.md](file:///Users/macbookair/Documents/reclubV2/reclub_features.md) | Hasil riset mendalam fitur Reclub. |
| **Riset Fitur Strava** | [strava_features.md](file:///Users/macbookair/Documents/reclubV2/strava_features.md) | Hasil riset mendalam fitur Strava (Free vs Subscription). |
