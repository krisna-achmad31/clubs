# Analisis & Daftar Fitur Lengkap Aplikasi Strava

Dokumen ini berisi riset mendalam mengenai seluruh fitur, teknologi, ekosistem kompetisi, dan model monetisasi **Strava**—aplikasi jejaring sosial dan pelacak kebugaran terbesar di dunia untuk pelari, pesepeda, dan pegiat olahraga luar ruang.

---

## 1. Ringkasan Eksekutif & Value Proposition

* **Platform:** Mobile (iOS, Android), Web Portal (`strava.com`), dan integrasi perangkat IoT/Wearable.
* **Model Bisnis:** **Freemium** (Fitur dasar gratis + Strava Subscription berbayar bulanan/tahunan, serta paket *Family Plan* dan *Student Plan*).
* **Posisi Pasar:** *"The Social Network for Athletes"* — Menggabungkan pelacakan data performa GPS tingkat tinggi dengan umpan sosial interaktif (*social feed*).
* **Parit Keunggulan (Moat):** Ekosistem **Segments & Leaderboards**, **Heatmaps**, serta integrasi luas ke hampir seluruh produsen jam tangan pintar dan komputer sepeda di dunia.

---

## 2. Katalog Fitur Lengkap Strava

### A. Pelacakan Aktivitas & Integrasi Perangkat (*Activity Tracking & Sync*)
1. **Dukungan Multi-Olahraga (30+ Sport Types):**
   * *Olahraga Utama:* Run, Trail Run, Ride (Road/Gravel/MTB/E-Bike), Swim, Walk, Hike.
   * *Olahraga Lainnya:* Ski, Snowboard, Kayak, Row, Yoga, Workout, CrossFit, Pickleball, Padel, dll.
2. **Pencatatan GPS Mandiri (In-App Recorder):**
   * Perekaman langsung lewat ponsel dengan indikator jarak, waktu, kecepatan/pace saat ini, elevasi, dan peta live.
   * Audio Cues (panduan suara berkala untuk split kilometer/mil).
3. **Konektivitas Sensor Eksternal:**
   * Mendukung pairing sensor Bluetooth LE (Detak Jantung / Heart Rate Monitor, Speed & Cadence sensor).
4. **Sinkronisasi Otomatis Ekosistem Hardware (Auto-Sync):**
   * Terhubung otomatis via API ke Garmin Connect, Apple Health / Apple Watch, Wahoo, COROS, Suunto, Polar, Whoop, Oura, Fitbit, hingga platform virtual seperti Zwift, Rouvy, dan Peloton.

---

### B. Segments & Sistem Kompetisi (*The Core Moat*)
*Fitur paling ikonik di mana pengguna dapat menandai potongan rute jalan/tanjakan tertentu untuk dikompetisikan secara terbuka.*

1. **KOM / QOM / CR (King/Queen of the Mountain & Course Record):**
   * Gelar mahkota bagi atlet tercepat sepanjang masa di segmen tersebut.
2. **Local Legend:**
   * Lencana karangan bunga (*laurel wreath*) untuk orang yang **paling sering** menyelesaikan segmen tersebut dalam 90 hari terakhir (fokus pada konsistensi, bukan kecepatan).
3. **Papan Peringkat (Leaderboards):**
   * *Free:* Peringkat umum (Top 10) dan riwayat personal di segmen tersebut.
   * *Subscription:* Filter papan peringkat berdasarkan kelompok usia (*age group*), kategori berat badan, filter per klub, atau khusus orang yang diikuti (*Following*).
4. **Live Segments (Subscription):**
   * Umpan balik real-time di layar ponsel atau bike computer (Garmin/Wahoo) saat mendekati dan melintasi segmen, menunjukkan apakah Anda sedang memimpin atau tertinggal dibanding rekor pribadi (PR) atau KOM.
5. **Integritas Leaderboard Berbasis AI / Machine Learning:**
   * Pendeteksian otomatis aktivitas anomali (misalnya pengguna lupa mematikan rekaman saat naik mobil atau motor di segmen lari/sepeda) untuk menjaga keadilan peringkat.

---

### C. Analitik Pelatihan & AI (*Training Insights & Performance*)
1. **Athlete Intelligence (Generative AI - Subscription):**
   * Analisis teks berbasis AI otomatis di bawah aktivitas yang merangkum tren performa 30 hari terakhir (contoh: mengevaluasi intensitas latihan tempo, tren heart rate, dan beban kumulatif). Tombol *"Say More"* untuk penjelasan lebih mendalam.
2. **Fitness & Freshness (Subscription):**
   * Grafik pemodelan beban latihan (*Impulse-Response Model*):
     * *Fitness:* Skor kebugaran akumulatif jangka panjang.
     * *Fatigue:* Kelelahan jangka pendek.
     * *Form / Freshness:* Kesiapan tubuh sebelum kompetisi/lomba (menghindari *overtraining*).
3. **Relative Effort (Beban Relatif):**
   * Skor intensitas kardiovaskular berdasarkan zona denyut jantung (Heart Rate Zones) untuk mengukur seberapa keras usaha tubuh, terlepas dari kecepatan.
4. **Grade-Adjusted Pace (GAP):**
   * Menghitung pace ekuivalen pada rute datar saat atlet berlari di rute menanjak atau menurun.
5. **Power Curve & Weighted Average Power:**
   * Analisis output watt bagi pesepeda yang menggunakan *power meter*.
6. **Pencatatan Target (Custom Goals):**
   * Mengatur target personal: target mingguan/tahunan (jarak, durasi, elevasi, atau frekuensi latihan).

---

### D. Pemetaan, Rute, & Heatmap (*Mapping & Navigation*)
1. **Global Heatmap:**
   * Visualisasi jalur teramai di dunia yang dihasilkan dari miliaran aktivitas pengguna Strava (sangat berguna untuk mencari rute aman saat berada di kota/negara baru).
2. **Personal Heatmap & Night Heatmap (Subscription):**
   * Peta visual yang menampilkan garis semua rute yang pernah Anda lewati sendiri seumur hidup.
3. **Route Builder & Suggestion (Subscription):**
   * Pembuat rute cerdas yang dapat membuat rute melingkar (*loop*) otomatis berdasarkan jarak yang diinginkan, popularitas jalan, jenis permukaan (aspal vs tanah/gravel), dan elevasi.
4. **Offline Routing:**
   * Menyimpan rute ke memori ponsel agar tetap dapat dinavigasi saat berada di pegunungan tanpa sinyal internet.
5. **3D Maps & Terrain:**
   * Visualisasi topografi 3 dimensi (diperkuat oleh integrasi FATMAP) untuk rute trail run, hiking, dan ski.
6. **Points of Interest (POI):**
   * Menampilkan titik penting di sepanjang rute seperti sumber air minum, toilet umum, dan kafe/rest stop.

---

### E. Fitur Sosial & Komunikasi (*Community & Social Feed*)
1. **Social Feed (Linimasa Aktivitas):**
   * Mirip Instagram untuk olahraga: mengunggah foto, video, peta rute, catatan latihan, dan judul aktivitas yang menarik.
2. **Kudos & Komentar:**
   * Tombol *Kudos* (jempol apresiasi) dan interaksi komentar antaratlet.
3. **Pesan Langsung & Grup (In-App Messaging):**
   * *Direct Message (1-on-1):* Obrolan privat antarpengguna.
   * *Group Chat:* Koordinasi grup olahraga hingga 25 anggota dengan fitur bagikan rute/aktivitas langsung ke ruang obrolan, GIF, dan reaksi emoji.
4. **Clubs (Klub Komunitas):**
   * Wadah komunitas/brand dengan fitur: papan pengumuman (*Club Channels*), leaderboard mingguan internal klub, dan agenda acara/event lari bersama.
5. **Tantangan Global & Grup (*Challenges*):**
   * *Monthly Brand Challenges:* Tantangan bulanan berhadiah diskon perlengkapan atau lencana digital (*trophy case*).
   * *Group Challenges:* Tantangan privat bersama teman (contoh: siapa paling cepat mengumpulkan 50 km bulan ini).

---

### F. Keamanan & Privasi (*Safety & Privacy Controls*)
1. **Beacon (Live Tracking):**
   * Mengirimkan link SMS berisi posisi koordinat GPS langsung (*real-time location*) dan sisa baterai ponsel kepada hingga 3 kontak darurat.
   * *Free:* Bisa digunakan langsung lewat aplikasi smartphone Strava.
   * *Subscription:* Terkoneksi mandiri lewat jam Garmin / Apple Watch LTE tanpa perlu membawa smartphone.
2. **Privacy Zones (Zona Privasi Rumah/Kantor):**
   * Menyembunyikan titik awal dan akhir rute dalam radius tertentu di sekitar rumah/kantor pengguna untuk menghindari pelacakan alamat pribadi oleh orang asing.
3. **Pengaturan Visibilitas Metrik:**
   * Pengguna bisa menyembunyikan data sensitif dari publik (misal: menyembunyikan denyut jantung, kalori, kecepatan, atau waktu mulai aktivitas).
4. **Flyby:**
   * Fitur pemutaran ulang visual yang menampilkan siapa saja sesama pengguna Strava yang berpapasan atau berada di rute yang sama dengan Anda pada hari tersebut.

---

### G. Pelacak Perlengkapan (*Gear Tracking*)
1. **Pelacak Usia Sepatu Lari (Shoe Mileage Tracker):**
   * Mencatat akumulasi jarak tempuh sepatu dan memberikan peringatan otomatis jika sepatu sudah mencapai batas pakai (misal: 500–800 km) untuk mencegah cedera.
2. **Komponen Sepeda (Bicycle Maintenance):**
   * Mencatat jarak tempuh rantai, ban, dan servis berkala komponen sepeda.

---

## 3. Matriks Perbandingan: Free vs Subscription

| Fitur | Strava Free | Strava Subscription (Premium) |
|---|:---:|:---:|
| **Perekaman GPS & Auto-Sync Gadget** | ✅ Ya | ✅ Ya |
| **Social Feed, Kudos, & Komentar** | ✅ Ya | ✅ Ya |
| **Direct & Group Messaging** | ✅ Ya | ✅ Ya |
| **Beacon (Live Tracking via HP)** | ✅ Ya | ✅ Ya (+ via Garmin/Apple Watch) |
| **Global Heatmap** | ✅ Ya | ✅ Ya |
| **Segment KOM/QOM & Top 10** | ✅ Ya | ✅ Ya |
| **Segment Filter (Umur/Berat/Teman)** | ❌ Tidak | ✅ Ya |
| **Live Segments (Di Layar/Garmin)** | ❌ Tidak | ✅ Ya |
| **Route Builder & Navigasi Offline** | ❌ Terbatas | ✅ Ya (Penuh) |
| **Personal & Night Heatmap** | ❌ Tidak | ✅ Ya |
| **Fitness & Freshness Analysis** | ❌ Tidak | ✅ Ya |
| **Grade-Adjusted Pace (GAP)** | ❌ Tidak | ✅ Ya |
| **Athlete Intelligence (Generative AI)** | ❌ Tidak | ✅ Ya |
| **Manajemen Target Khusus (Goals)** | ❌ Hanya dasar | ✅ Ya (Kustom) |

---

## 4. Pelajaran Utama untuk Pengembangan Produk Baru (Insights for ReclubV2)

Mengapa Strava sangat sukses dan apa yang bisa diadopsi untuk aplikasi komunitas olahraga seperti **ReclubV2**:

1. **Gamifikasi Kompetitif (Konsep Segments):**
   * Strava berhasil membuat rute publik menjadi ajang persaingan permanen lewat KOM/QOM dan Local Legend.
   * *Aplikasi di Komunitas Raket/Mabar:* Sistem ranking lapangan (*King of the Court*, rekor kemenangan di venue tertentu, atau rating dinamis pemain).
2. **Kekuatan Jaringan (*Network Effect*):**
   * Strava menjadi standar di mana atlet merasa *"If it's not on Strava, it didn't happen"*.
   * Menyediakan feed sosial dan kemudahan berbagi ke media sosial (Instagram Stories card dengan overlay statistik rute) adalah kunci viralitas gratis.
3. **Data Hardware Agnostic:**
   * Strava tidak membatasi merek gadget; mereka merangkul Garmin, Apple, COROS, dan Polar sekaligus.
4. **Monetisasi yang Jelas:**
   * Fitur sosial dasar dibuat gratis agar adopsi massal tercapai, sedangkan fitur analitik data mendalam dan rute navigasi dikunci untuk pengguna berbayar.
