# Postman Klubby

1. Impor collection dan kedua file environment melalui **Import** di Postman.
2. Pilih **Klubby Dev**. Publishable key proyek sudah terisi. Isi nilai lokal `email` dan `password` akun uji.
3. Jalankan **Auth → Login email**. Respons sukses menyimpan `access_token`, `refresh_token`, dan `user_id` ke environment aktif. Setelah itu jalankan **Profil → Siapkan profil (Dev saja)**.
4. Coba **Profil saya** atau **Daftar klub**. Untuk request yang perlu ID, salin ID dari respons ke variabel terkait. Buat klub, sesi, aktivitas, dan lobi otomatis menyimpan ID hasilnya. Untuk membuat sesi, isi `starts_at` dan `ends_at` dengan waktu ISO 8601 di masa depan. Untuk QR statik, isi `object_path` dengan path objek yang sudah diunggah, tanpa nama bucket.

Dev dan Live memakai URL dan akun Auth yang sama. Environment memilih schema `klubby_dev` atau `public` serta bucket logo. Gunakan Dev untuk request yang menulis data uji. Pendaftaran akun berlaku untuk Supabase Auth bersama. Beberapa endpoint lanjutan membutuhkan migrasi yang sudah dipasang pada schema aktif.

Request Google memakai token Google yang diperoleh dari alur login aplikasi. Simpan kredensial dan token sebagai nilai lokal Postman. Untuk pengiriman notifikasi oleh backend, lihat kontrak `send_notification` di [README Supabase](../supabase/README.md). Registrasi token FCM menyimpan alamat perangkat untuk pengiriman push.
