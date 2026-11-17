# Uji Flutter dengan Supabase Dev

## Endpoint yang dipanggil Flutter

Ubah `static AppMode appMode = AppMode.DEV;` menjadi `AppMode.LIVE` di [app_data.dart](../lib/core/app_data.dart), lalu jalankan ulang aplikasi. Kedua mode membuka layar yang terhubung ke Supabase. Repository di layar lama masih lokal.

Kedua mode memakai `https://tausaxdgodekmtztklzx.supabase.co`. `DEV` memilih schema `klubby_dev` dan `LIVE` memilih `public` lewat header REST. Khusus LIVE, aplikasi memakai `PATCH /rest/v1/notifications` untuk menandai notifikasi dibaca. Feed aktivitas dan pembayaran manual tampil di DEV karena migrasinya baru dipasang di sana.

| Alur | Metode dan endpoint |
| --- | --- |
| Login email | `POST /auth/v1/token?grant_type=password` |
| Login SMS | `POST /auth/v1/otp`, `POST /auth/v1/verify` |
| Login Google | Pemilih akun native, lalu `POST /auth/v1/token?grant_type=id_token` untuk memperoleh sesi Supabase |
| Login Apple | Browser ke `GET /auth/v1/authorize`, kembali ke `klubby://auth-callback`, lalu `POST /auth/v1/token?grant_type=pkce` |
| Siapkan profil Dev setelah login | `POST /rest/v1/rpc/provision_dev_profile` |
| Baca dan edit profil | `GET /rest/v1/users`, `PATCH /rest/v1/users` |
| Klub dan keanggotaan | `GET /rest/v1/clubs`, `POST /rest/v1/clubs`, `GET /rest/v1/club_members`, `POST /rest/v1/rpc/join_club` |
| Chat klub | `GET /rest/v1/club_messages`, `POST /rest/v1/club_messages` |
| Mabar dan peserta | `GET /rest/v1/mabar_sessions`, `POST /rest/v1/mabar_sessions`, `GET /rest/v1/session_participants` |
| Daftar dan batal RSVP | `POST /rest/v1/rpc/rsvp_mabar`, `POST /rest/v1/rpc/cancel_mabar_rsvp` |
| QR statis | `POST /rest/v1/rpc/set_mabar_payment_qr`, `POST /storage/v1/object/sign/dev-club-logos/{path}`, lalu `GET` URL bertanda tangan |
| Lapor dan verifikasi pembayaran | `POST /rest/v1/rpc/report_mabar_payment`, `POST /rest/v1/rpc/review_mabar_payment` |
| Aktivitas manual dan feed | `GET /rest/v1/activities`, `POST /rest/v1/activities` |
| Kotak masuk | `GET /rest/v1/notifications`, `POST /rest/v1/rpc/mark_notifications_read` |

[API_CONTRACT_CHECKLIST.md](../../API_CONTRACT_CHECKLIST.md) memetakan kebutuhan seluruh halaman. Tabel di atas hanya mencatat endpoint yang telah dipanggil oleh kode Flutter Dev.

## Menjalankan build Dev

Mode Dev menjalankan profil, klub, mabar, dan kotak masuk melalui REST API di schema `klubby_dev`. Data diambil dari server dan tampilan menyediakan pemuatan ulang jika permintaan gagal.

1. Masuk dengan akun Supabase Auth. Semua akun yang sudah login dapat menggunakan Dev.

2. Dari direktori `mobile`, jalankan aplikasinya. Publishable key ClubUs sudah disetel di `AppData` dan dapat diganti lewat `SUPABASE_PUBLISHABLE_KEY`.

   ```powershell
   flutter run
   ```

   Jangan gunakan secret key atau service role key. Build Dev tidak menerima kunci tersebut. Kata sandi dimasukkan di aplikasi, dan sesi hanya disimpan selama aplikasi berjalan.

3. Masuk, ubah profil, buat atau gabung klub, lalu buka tab Mabar. Sebagai admin klub, buat sesi gratis atau berbayar. Untuk sesi berbayar, unggah gambar QR statis ke `dev-club-logos/<UUID-klub>/qr.png` melalui Storage. Buka **Kelola** dan simpan path `<UUID-klub>/qr.png`. Peserta memesan slot, memindai QR, lalu menekan **Saya sudah bayar**. Host periksa mutasi secara manual dan konfirmasi atau tolak laporan. Peserta menerima hasilnya di kotak masuk.

4. Buka **Feed** dan catat aktivitas manual. Aktivitas privat secara default. Di klub yang sudah diikuti, **Chat** memuat dan mengirim pesan melalui REST. Buka ulang chat untuk memuat pesan baru.

OTP SMS disembunyikan sampai provider tersedia. Registrasi FCM token tersedia di backend melalui `register_fcm_token` dan `unregister_fcm_token`. Flutter dan pengiriman push belum terhubung.

Callback `klubby://auth-callback` sudah terdaftar di Supabase. Untuk mengaktifkan Google atau Apple, masukkan kredensial provider di Supabase Auth dan daftarkan `https://tausaxdgodekmtztklzx.supabase.co/auth/v1/callback` di konfigurasi provider terkait. Google tersedia di Android dan iOS. Apple tersedia di iOS melalui OAuth browser dengan Services ID. [Panduan redirect Supabase](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter)

Pengujian kontrak HTTP ada di `test/dev_api_test.dart`. Tes ini memeriksa header schema, sesi, dan tidak adanya fallback ke Prod.
