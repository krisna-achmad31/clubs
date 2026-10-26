# Catatan pemulihan Klubby — 25 Oktober 2026

## Batas perubahan

Arahan pengguna: pertahankan tampilan, animasi, dan fitur yang sudah ada; perbaiki bagian yang rusak atau belum berfungsi. Perubahan tata letak yang diminta khusus adalah kolom **Olahraga Utama** dan **Area** pada Buat Klub menjadi atas–bawah.

Sesi audit/perbaikan sebelumnya terhenti. Brief historis disimpan di `FIX_RECOVERY_BRIEF.md`. Saat integrasi, pengguna mengonfirmasi ada agen lain yang mengedit proyek, kemudian mengonfirmasi agen tersebut sudah berhenti. Kode terbaru dibaca kembali sebelum melanjutkan; pemulihan parsialnya dipertahankan.

## Perbaikan yang terintegrasi

| Bagian / berkas utama | Perubahan |
| --- | --- |
| `features/onboarding/presentation/` | Validasi formulir/OTP demo, pemilihan foto dan area, preferensi, penanganan lokasi gagal, serta tampilan onboarding yang bisa digulir. |
| `features/profile/presentation/pages/profile_helpers.dart` | Akses Profil → Geng Gemoy, pengaturan dan formulir lokal; lapisan Material untuk FAQ agar ExpansionTile bisa dirender dengan benar. Pemulihan profil dari agen lain dipertahankan. |
| `features/profile/presentation/pages/streak_calendar_pages.dart` | Kalender menggabungkan riwayat stempel persisten dan catatan aktivitas. Riwayat kalender bawaan yang sempat hilang dipulihkan, termasuk Es Batu. Perpindahan bulan, detail hari, tantangan dan animasi dipertahankan. |
| `features/feed/presentation/` | Detail posting, berbagi, profil penulis/komentar, notifikasi, dan reaksi memakai data yang sesuai. |
| `features/activity/` | Pencatatan manual/GPS, persistensi JSON aktivitas, foto, pemilihan gear, serta hasil/story sesuai aktivitas yang tersimpan. Angka streak, durasi, skor dan poin klub pada Story dipulihkan. Titik GPS/sensor dan waktu jeda disimpan untuk grafik rinci pada posting; lihat `ACTIVITY_DETAILS.md`. Animasi hasil dan evolusi dipertahankan. |
| `features/club/presentation/pages/club_pages.dart` | Olahraga dan Area tersusun vertikal dengan lebar penuh. Label area menyertakan kota; callback picker memeriksa `mounted`. Logo dan pilihan privasi tetap memakai animasi yang ada. |
| `features/club/presentation/pages/club_actions.dart` | Pencarian/filter, anggota, kas lokal dan ekspor; jalur yang memerlukan layanan eksternal dijelaskan sebagai demo. |
| `features/session/` | Tenggat pembayaran berdasarkan waktu, pembayaran/pembatalan tidak diproses dua kali, tamu dan antrean, data jadwal host, kehadiran dan pengembalian saldo demo. Pemulihan animasi tiket, slot, publikasi, dan pergantian QR dipertahankan. |
| `features/tournament/` | Penjadwalan dan skor mengikuti format/jumlah peserta/lapangan. Edit skor mengganti kontribusi sebelumnya. Animasi pilihan format, validasi, skor, klasemen dan podium dikembalikan; podium memakai hasil turnamen sebenarnya. |
| `features/goyang/presentation/pages/goyang_flow_pages.dart` | Empat halaman yang tertinggal saat pemulihan dilengkapi. Pulsa status, animasi masuk respons, goyangan maskot, ilustrasi dua HP, confetti dan avatar bertahap dikembalikan. Tombol terhubung ke alur lokal yang sesuai; pencatatan dua HP tetap Kasual. |
| `features/shop/presentation/pages/shop_flow_pages.dart` | Tata letak dua kolom dan kartu Es Batu dipulihkan beserta animasi item, saldo dan Es Batu. Pembelian tetap melalui detail/konfirmasi dan status kepemilikan. |
| `features/league/presentation/pages/league_pages.dart` | Pemilihan/filter menggunakan data yang sesuai. Tampilan akhir musim, maskot masuk dan confetti dipulihkan; perayaan dan status akhir mengikuti kondisi musim. |

Perapian analyzer terbatas pada penambahan kurung blok dan interpolasi teks; tidak mengubah perilaku fitur.

## Pemeriksaan lokasi

Berkas: `core/services/location_service.dart`, `core/widgets/area_picker.dart`, dan `features/onboarding/presentation/cubit/onboarding_cubit.dart`.

- GPS mati, izin ditolak, izin diblokir permanen, dan lokasi tidak tersedia memiliki pesan berbeda.
- Kesalahan platform tidak membiarkan pemilih area terus menampilkan status pencarian.
- Tombol pengaturan membuka pengaturan lokasi atau pengaturan aplikasi sesuai masalahnya.
- Lokasi tersimpan lebih dari lima menit atau akurasi lebih buruk dari 1 km tidak digunakan sebagai posisi sekarang.
- Daftar area lokal belum mencakup seluruh Indonesia. Kandidat harus berada dalam 25 km dari pusat area yang terdaftar; posisi di luar cakupan diarahkan ke pilihan manual.
- Pemilih area menampilkan hasil sebagai **perkiraan area terdekat** dan meminta pengguna memilih “Pakai Area Ini”. Ini belum merupakan pencarian batas kecamatan melalui reverse geocoding.
- Pemeriksaan ADB pada HP Infinix X6851: perangkat terhubung, layanan lokasi aktif, dan akses lokasi Klubby diizinkan saat aplikasi digunakan. Pembacaan koordinat melalui tombol pada APK terbaru belum diuji langsung di HP.

## Pemulihan riwayat dan detail aktivitas

- `UserProfile.stampHistory` menyimpan tanggal, olahraga, dan penggunaan Es Batu. Pencatatan ulang pada hari yang sama tidak menggandakan tanggal; olahraga lain pada hari itu tetap tercatat.
- Migrasi profil demo lama mengembalikan kalender Oktober yang memang ada sebelum pemulihan. Akun baru tidak mendapat riwayat demo. Durasi, skor, sensor dan poin aktivitas lama tidak dikarang dari jumlah stempel.
- Kartu Story tetap memakai tata letak dan pergantian template semula. Sakelar “Sembunyikan angka” menyamarkan nilai; label statistik tetap terlihat.
- Video Strava 18.56.54 menjadi acuan detail elevasi, detak jantung, pace, cadence, waktu bergerak/total, dan split. Grafik bisa disentuh/digeser. Rekaman asli tetap disimpan ketika posting dibuka kembali setelah restart.
- Statistik bar atas tetap mempertahankan pemilih olahraga, counter dan animasi; counter boleh turun baris saat layar sempit atau skala teks besar.

## Verifikasi

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub`: **90 tes lulus**.
- Termasuk validasi jadwal/skor turnamen, tenggat/pembatalan sesi, persistensi aktivitas dan sensor, waktu jeda, split/pace, pemulihan 14 hari kalender, angka Story, navigasi posting serta geser grafik, izin/fallback GPS, pemilihan area, akses Geng Gemoy, serta interaksi Goyang.
- Tes widget memakai ukuran 320 × 720 dan skala teks 1,3 untuk memeriksa kegagalan layout/provider dan interaksi. Font fixture lokal dipakai agar tes offline; hasilnya bukan pembandingan piksel dengan font produksi.

## Batas yang masih berlaku

- OTP, pengiriman ajakan/notifikasi komunitas, pembayaran/QRIS/refund nyata, reservasi venue, sinkronisasi akun dan hadiah sponsor membutuhkan layanan backend. UI menjelaskan operasi demo/lokal yang tersedia.
- Pencocokan dua HP dan verifikasi waktu/lokasi check-in oleh server belum tersedia. Goyang Bareng tidak mengklaim aktivitas terverifikasi.
- Rute Pelangi dan Boost XP belum bisa dibeli sampai efeknya tersedia. Pilihan aksesori dapat disimpan; rendering seluruh aksesori pada maskot belum tersedia.
- Belum ada build atau instalasi APK pada langkah ini. Pengujian visual langsung dan pengambilan GPS pada versi terbaru di HP masih diperlukan.

Catatan ini mendeskripsikan perubahan dan pemeriksaan yang dilakukan; tidak menyatakan semua skenario aplikasi telah diuji secara manual.
