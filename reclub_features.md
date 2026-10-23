# Analisis & Daftar Fitur Lengkap Aplikasi Reclub

Dokumen ini berisi dokumentasi lengkap mengenai fitur, arsitektur operasional, dan alur kerja aplikasi **Reclub** (`reclub.co`), platform manajemen komunitas olahraga dan sesi main bareng (*mabar*) yang populer di kalangan olahraga raket (Tenis, Badminton, Pickleball, Padel) serta olahraga rekreasional lainnya.

---

## 1. Ringkasan Eksekutif (Executive Summary)

* **Nama Platform:** Reclub
* **Situs Resmi:** [reclub.co](https://reclub.co)
* **Akses Platform:** Mobile App (iOS / Android) & Web Portal
* **Fokus Utama:** Mengatasi friksi koordinasi komunitas olahraga (menggantikan grup WhatsApp & spreadsheet Excel manual) melalui otomatisasi RSVP, waiting list, pembagian lapangan/tim, turnamen, dan pencatatan pembayaran.
* **Target Pengguna:** 
  * *Organizers / Club Hosts:* Pengelola komunitas, kapten tim, admin mabar, pengelola venue.
  * *Players / Athletes:* Pemain rekreasional hingga kompetitif yang mencari sesi mabar, teman sparring, dan komunitas olahraga lokal.

---

## 2. Struktur Pengguna & Peran (User Roles & Permissions)

| Peran (Role) | Hak Akses & Kemampuan |
|---|---|
| **Club Owner / Super Admin** | Membuat klub, mengatur privasi (publik/privat), mengelola semua admin/host, mengatur metode pembayaran default, broadcast pengumuman. |
| **Event Organizer / Host** | Membuat jadwal kegiatan (*Meets*), menentukan kuota & biaya, mengelola *waiting list*, memverifikasi bukti transfer, mengatur bagan turnamen, memasukkan skor. |
| **Member** | Bergabung ke klub, RSVP ke sesi mabar, mengunggah bukti bayar, input skor mandiri, posting foto/video ke feed sesi, memberi *Kudos*. |
| **Guest (+1 / +2)** | Peserta non-akun yang didaftarkan oleh member aktif. Nama tercatat di daftar kehadiran tanpa wajib memiliki akun Reclub. |

---

## 3. Katalog Fitur Lengkap (Comprehensive Feature List)

### A. Manajemen Komunitas & Klub (*Club Management*)
1. **Digital Locker Room:** Ruang virtual khusus komunitas untuk menampung seluruh anggota, jadwal mabar, dokumentasi, dan papan pengumuman.
2. **Pengaturan Privasi Klub:**
   * *Public Club:* Bisa ditemukan melalui fitur pencarian (*discovery*) dan terbuka untuk siapa saja.
   * *Private / Approval-Only Club:* Membutuhkan persetujuan admin atau link undangan khusus (cocok untuk sirkel tertutup / komunitas kantor).
3. **Pencarian Komunitas (*Location-Based Discovery*):** Rekomendasi klub, lapangan, dan sesi mabar terdekat berbasis lokasi pengguna dan cabang olahraga yang diminati.
4. **Broadcast & Announcement:** Fitur siaran pesan penting dari admin yang langsung memicu notifikasi push ke seluruh anggota.

### B. Penjadwalan & Sesi Main (*Meets & RSVP Logistics*)
1. **Manajemen Kuota Pemain:** Batas jumlah peserta maksimal sesuai ketersediaan lapangan.
2. **Sistem RSVP Real-Time:** Member cukup satu kali klik untuk konfirmasi hadir (*Going*) atau batal (*Out*).
3. **Waiting List Otomatis:** Sistem antrean transparan berbasis waktu (*first-come, first-served*). Jika ada peserta membatalkan slot, peserta nomor 1 di antrean otomatis naik menjadi peserta terkonfirmasi.
4. **Fitur Tambah Tamu (*Guest System*):** Kemampuan mendaftarkan teman (+1, +2) yang tidak memakai aplikasi.
5. **Batas Waktu Pembatalan (*Cancellation Deadline*):** Aturan waktu cut-off agar pemain tidak membatalkan secara mendadak saat sesi mabar sudah dekat.
6. **Presensi & Check-in Kehadiran:** Pelacakan kehadiran di lokasi untuk menandai pemain yang hadir, terlambat, atau tidak datang (*no-show*).

### C. Engine Kompetisi & Format Turnamen (*Competition Generator*)
Reclub memiliki generator turnamen bawaan yang mengeliminasi kebutuhan spreadsheet:
1. **Round Robin:** Format semua peserta/tim saling berhadapan.
2. **Americano (Populer di Padel/Pickleball):** Format di mana setiap babak berganti pasangan (*rotating partner*), dan akumulasi skor kemenangan dihitung secara individu di papan klasemen.
3. **Mexicano:** Variasi dinamis dari Americano; pasangan dan lawan di babak selanjutnya ditentukan berdasarkan posisi klasemen sementara (pemain berpoin tinggi bertemu pemain berpoin tinggi).
4. **King of the Court (Ladder System):** Pasangan pemenang naik ke lapangan utama (*top court*), sedangkan pasangan yang kalah turun lapangan.
5. **Single & Double Elimination Brackets:** Bagan sistem gugur konvensional untuk turnamen resmi.
6. **Rotasi Lapangan Dinamis:** Generator pembagian lapangan otomatis untuk kelompok besar (mendukung hingga banyak lapangan sekaligus).
7. **Live Scoring & Leaderboard:** Input skor instan lewat ponsel peserta/wasit dengan pembaruan klasemen secara langsung.

### D. Modul Finansial & Pembayaran (*Payment Tracking & Receipts*)
1. **Model Bebas Biaya Transaksi (*Zero Platform Fee*):** Reclub tidak memotong komisi transaksi dari penyelenggara.
2. **Informasi Rekening Fleksibel:** Penyelenggara dapat mencantumkan rekening bank manual (BCA, Mandiri, BRI) atau e-wallet (GoPay, OVO, Dana, QRIS statis).
3. **Unggah Bukti Transfer (*Receipt Upload*):** Member mengunggah screenshot bukti pembayaran langsung pada saat/setelah RSVP.
4. **Verifikasi Admin & Status "Paid":** Host mengecek lampiran bukti transfer dan menandai status peserta menjadi *Paid*, mempermudah rekap kas mabar.

### E. Sistem Rating & Level Keterampilan (*Skill Ratings*)
1. **Integrasi Resmi DUPR (Pickleball):** Terkoneksi langsung dengan *Dynamic Universal Pickleball Rating* (DUPR) untuk mengirimkan hasil pertandingan terverifikasi secara otomatis.
2. **Skill-Level Tagging:** Profil pemain memiliki indikator tingkatan (Beginner, Intermediate, Advanced) untuk mempermudah host menyeimbangkan tim atau membatasi sesi mabar khusus level tertentu.
3. **Statistik Personal:** Rekor kemenangan, kekalahan, rasio tanding, dan riwayat pertandingan.

### F. Aspek Sosial, Komunikasi, & Gamifikasi
1. **Album Dokumentasi Sesi (*Meet Photo & Video Feed*):** Tempat berbagi foto dan video setelah sesi mabar berakhir.
2. **Street Cred & Kudos:** Sistem reputasi komunitas di mana pemain dapat saling memberi apresiasi atas sportivitas atau permainan yang impresif.
3. **Chat Terdedikasi:** 
   * Chat per klub (obrolan umum komunitas).
   * Chat per aktivitas/sesi mabar (khusus koordinasi teknis di hari-H).
4. **Stiker Tematik:** Stiker percakapan dengan tema olahraga.

### G. Tier Berlangganan: *Reclub Supporter* (Monetisasi Platform)
Paket langganan berbayar bulanan atau tahunan dengan keuntungan:
* Tampilan bebas iklan (*No banner ads*).
* Akses analitik performa bermain lanjutan (*Stats Analytics*).
* Penyimpanan riwayat pertandingan permanen seumur hidup (*Personal Match History*).
* Akses penuh ke papan peringkat *Street Cred*.
* Lencana khusus *Supporter Badge* di profil pengguna.
* Fasilitas lanjutan pengelolaan metode pembayaran & verifikasi kuitansi.

---

## 4. Alur Kerja Standar (Core User Workflows)

```
[Host Membuat Jadwal Mabar] 
          │
          ▼
[Notifikasi Masuk ke Member] 
          │
          ▼
[Member Melakukan RSVP / Booking Slot]
          │
    ┌─────┴──────────────────┐
    ▼                        ▼
[Slot Masih Tersedia]   [Slot Penuh]
    │                        │
    ▼                        ▼
[Status: Terdaftar]     [Masuk Waiting List]
    │                        │ (Jika ada yang batal)
    │                        └────────► [Auto Naik ke Terdaftar]
    ▼
[Member Transfer & Upload Bukti Bayar]
    │
    ▼
[Host Verifikasi -> Tag "Paid"]
    │
    ▼
[Hari-H: Check-in & Rotasi Lapangan / Game Generator]
    │
    ▼
[Input Skor Pertandingan (Live Leaderboard)]
    │
    ▼
[Selesai: Upload Foto Mabar & Bagi Kudos / Street Cred]
```

---

## 5. Peluang Peningkatan / Diferensiasi (Untuk Pengembangan ReclubV2)

Jika Anda sedang merancang atau membangun platform serupa (**reclubV2**), berikut beberapa celah dan peluang peningkatan yang bisa dioptimalkan:

1. **Integrasi Payment Gateway Otomatis (Lokal Indonesia):**
   * *Celah Reclub:* Saat ini masih berbasis upload manual screenshot bukti transfer, sehingga admin harus cek manual satu per satu.
   * *Solusi V2:* Integrasi otomatis dengan QRIS dinamis / Virtual Account (Midtrans, Xendit, atau Duitku) sehingga status langsung otomatis *Paid* begitu transfer selesai.
2. **Integrasi Booking Lapangan (*Court Booking Integration*):**
   * *Celah Reclub:* Reclub memisahkan antara jadwal mabar dan ketersediaan lapangan (penyelenggara harus booking lapangan di luar aplikasi).
   * *Solusi V2:* Kolaborasi/integrasi langsung dengan software pengelola lapangan olahraga (memesan lapangan + membuat sesi mabar dalam satu platform).
3. **Sistem Denda Pembatalan / Refund Otomatis:**
   * Penanganan deposit atau saldo dompet digital in-app untuk penalti *late-cancellation* atau *no-show*.
4. **Rating Universal Multi-Cabang Olahraga:**
   * Membawa sistem rating seperti DUPR ke cabang badminton dan tenis lokal agar matchmaking semakin akurat.
