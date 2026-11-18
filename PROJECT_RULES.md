# Aturan Penting Project Klubby (WAJIB DIIKUTI)

1. **Dilarang Membuat UI Khusus Dev:**
   - **Tidak boleh** ada halaman atau aplikasi terpisah khusus Dev (seperti `KlubbyDevApp` / layar putih polos).
   - **UI untuk Dev dan Prod/Live harus selalu sama** (menggunakan desain release `KlubbyApp` di `clubs/mobile/lib/app.dart`).
2. **Pemisahan Environment (`dev` vs `prod`):**
   - Cukup diatur melalui konfigurasi di **`AppData`** (`clubs/mobile/lib/core/app_data.dart`) atau `--dart-define`, **bukan** dengan mengganti entry point `main.dart` atau membuat UI baru.
3. **Verifikasi fitur ujung ke ujung:**
   - Untuk fitur yang memakai backend, terapkan dan uji migrasi, constraint, serta akses data di environment target.
   - Uji endpoint dengan sesi yang sesuai. Cocokkan payload, status HTTP, dan bentuk respons dengan model Flutter.
   - Jalankan alur dari layar aplikasi dan periksa bahwa perubahan tersimpan serta tampil kembali setelah dimuat ulang.
   - Laporkan hasil tiap lapisan dalam penyerahan fitur yang sama. Sebutkan environment dan bagian yang masih terblokir.
   - Untuk tindakan yang dipicu pengguna, tampilkan hasil berhasil, gagal, atau berhasil sebagian lewat toast. Pakai pesan API yang memang ditujukan untuk pengguna dan pesan cadangan yang jelas untuk error jaringan atau teknis.
