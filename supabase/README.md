# Klubby Supabase

## Dev dan Prod dalam satu proyek

Proyek ClubUs melayani `public` (Prod) dan `klubby_dev` (Dev) di URL yang sama. Nama tabel di kedua schema sama. Dev memiliki bucket privat `dev-avatars`, `dev-club-logos`, `dev-activity-photos` dan job kedaluwarsa sendiri. Auth, kuota, dan kunci proyek tetap bersama. Schema bukan pengganti isolasi proyek; khususnya, akun uji Auth baru masih memicu pembuatan profil kosong di Prod.

- Untuk REST Dev, kirim `Accept-Profile: klubby_dev` pada pembacaan dan `Content-Profile: klubby_dev` pada mutasi dan RPC POST. Untuk Prod, pilih `public` secara eksplisit. Klien Dev harus gagal jika schema salah atau akses ditolak; jangan ulangi request ke `public`.
- Untuk Realtime Dev, filter schema `klubby_dev`. Gunakan prefix bucket `dev-` hanya pada build Dev.
- Semua akun yang sudah login dapat menggunakan Dev. Setelah login, panggil RPC `provision_dev_profile` dengan schema `klubby_dev`. Gunakan publishable key dari aplikasi agar RLS berlaku.
- Fixture Dev saat ini berisi 5 klub dan 4 sesi dari aplikasi. Profil host fixture tidak mempunyai akun login dan tidak ditambahkan ke Prod atau Auth.
- Untuk instalasi awal yang setara, jalankan `node supabase/scripts/build-shared-dev.mjs shared-dev.sql` dari root repositori. Bundel ini membuat schema baru dalam transaksi; jangan jalankan ulang pada schema yang sudah terpasang. Setelah itu, tambahkan `klubby_dev` ke **Data API → Settings → Exposed schemas**, dengan mempertahankan schema yang sudah aktif.

## API notifikasi

RPC baru saat ini dipasang di Dev. Endpoint berikut menggunakan `/rest/v1` dengan header schema di atas:

| Metode | Endpoint | Akses dan perilaku |
| --- | --- | --- |
| GET | `/notifications?select=id,kind,payload,created_at,read_at&order=created_at.desc,id.desc&limit=50` | JWT pengguna; RLS membatasi kotak masuk miliknya. |
| POST | `/rpc/mark_notifications_read` | JWT pengguna; payload `{"p_ids":["<uuid>"]}`; mengembalikan jumlah yang baru dibaca. |
| POST | `/rpc/send_notification` | Server saja; kirim `p_user_id`, `p_kind`, `p_title`, `p_body`, `p_delivery_key`, dan `p_payload` opsional. Retry dengan kunci dan isi sama mengembalikan ID yang sama. |

Event persetujuan klub, promosi waitlist, kedaluwarsa reservasi, dan pembatalan sesi menulis ke kotak masuk. Langganan Realtime mendukung pembaruan saat aplikasi aktif. Push saat aplikasi tertutup masih memerlukan integrasi FCM/APNs, registrasi token perangkat per lingkungan, dan pengujian pada perangkat sungguhan.

## Pemasangan inti Prod

Backend inti ini diterapkan ke proyek ClubUs (`tausaxdgodekmtztklzx`) lewat SQL Editor. Ketiga migrasi dan smoke test dijalankan dalam satu transaksi. Data uji dibatalkan sebelum commit.

- Auth membuat profil otomatis; nomor HP dan email tetap dikelola oleh Supabase Auth.
- Klub: buat klub, cari berdasarkan radius, gabung, persetujuan admin, chat, dan logo.
- Mabar: host membuat sesi, RSVP pengguna yang sudah login, kuota dan waitlist, pembatalan, notifikasi dalam aplikasi, dan cron kedaluwarsa reservasi QRIS. Status bayar hanya dapat diubah di sisi server.
- Storage: `avatars` dan `club-logos` dapat dibaca publik. `activity-photos` privat dan hanya dapat diakses pemilik untuk saat ini.
- Realtime: chat, sesi, peserta, dan notifikasi dengan pembatasan akses per baris.

Uji di proyek tersebut mencakup pembuatan profil, isolasi profil dan data peserta, kuota satu slot, pembatalan, promosi waitlist, dan notifikasi. Verifikasi terpisah menunjukkan 8 tabel dengan RLS, 3 bucket, 4 tabel Realtime, 1 cron aktif, dan 0 pengguna Auth setelah uji.

## Migrasi selanjutnya

Untuk database lokal baru, jalankan `supabase start` lalu `supabase db reset`. Untuk mengulang smoke test, jalankan isi `tests/core_smoke.sql` dalam transaksi dan akhiri dengan `rollback`.

SQL Editor tidak menulis riwayat migrasi CLI. Sebelum memakai `supabase db push` pada proyek ClubUs, tautkan proyek, cocokkan tabel, fungsi, kebijakan, dan job dengan tiga file migrasi, lalu catat versi 20261116000100, 20261116000200, dan 20261116000300 sebagai applied dengan `supabase migration repair`. Tinjau `db push --dry-run` sebelum mengirim migrasi baru. Versi `20261116000400` belum diterapkan ke `public`.

## Lanjutan spesifikasi

Phone OTP nyata memerlukan penyedia SMS/WhatsApp. QRIS, refund, dan kas memerlukan penyedia pembayaran dan webhook terverifikasi. Belum ada Web-RSVP tanpa login, tamu, QR check-in, push, integrasi wearable/Strava, aktivitas/feed/gear, turnamen, liga, gamifikasi, Goyang, Shop, atau integrasi Flutter ke backend.
