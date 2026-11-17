# Aturan Penting Project Klubby (WAJIB DIIKUTI)

1. **Dilarang Membuat UI Khusus Dev:**
   - **Tidak boleh** ada halaman atau aplikasi terpisah khusus Dev (seperti `KlubbyDevApp` / layar putih polos).
   - **UI untuk Dev dan Prod/Live harus selalu sama** (menggunakan desain release `KlubbyApp` di `clubs/mobile/lib/app.dart`).
2. **Pemisahan Environment (`dev` vs `prod`):**
   - Cukup diatur melalui konfigurasi di **`AppData`** (`clubs/mobile/lib/core/app_data.dart`) atau `--dart-define`, **bukan** dengan mengganti entry point `main.dart` atau membuat UI baru.
