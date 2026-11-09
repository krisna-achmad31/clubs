# Audit alur Profil — 7 November 2026

## Aturan produk

- Olahraga aktif menentukan partner melalui keluarga olahraga. Preview hewan tidak mengubah olahraga aktif.
- Menambahkan olahraga tidak langsung mengadopsi hewan. Sesi terverifikasi pertama membuka adopsi.
- Evolusi dihitung dari total sesi terverifikasi seluruh olahraga keluarga hewan, pada 1/3/7/14/30 sesi.
- Streak harian adalah milik akun, mencakup semua olahraga. Aktivitas manual dapat menjaga streak, tetapi tidak menambah evolusi/adopsi.
- Total historis per hewan dipertahankan. Rincian sesi per olahraga hanya ditampilkan jika benar-benar tersimpan; sisanya dilabeli sebagai sesi lama tanpa rincian.

## Perbaikan alur

- Partner belum diadopsi tetap tampil ketika membuka Geng; tidak digantikan hewan pertama yang dimiliki.
- Preview dapat memilih hewan; tindakan aktivasi olahraga dan rekam terpisah. Untuk keluarga dengan beberapa olahraga, pengguna memilih olahraga sebelum melanjutkan.
- Pemilih olahraga menampilkan tahap masing-masing hewan.
- GPS mempertahankan olahraga jarak yang dipilih, bukan menggantinya menjadi lari.
- Ketukan stempel terbaru membuka detail tanggal dan olahraga dalam bottom sheet, lalu tombol kalender membuka bulan asalnya. Profil tetap ringkas; kalender menampilkan tanggal dan jumlah hari aktif pada bulan terpilih.
- Detail hari membuka posting aktivitas yang telah dipublikasikan. Story tetap memakai bulan yang dipilih.
- Status memuat dan gagal membaca aktivitas tidak lagi ditampilkan sebagai nol aktivitas; kegagalan memiliki tindakan coba lagi.

## Batas data

- Riwayat Oktober bisa berisi stempel sementara November dan minggu berjalan kosong. Ini tidak otomatis berarti data hilang.
- Kalender menghitung hari aktif unik; jumlah sesi bukan jumlah hari. Riwayat stempel lama tidak digunakan untuk mengarang durasi.
- Lencana yang membutuhkan cuaca atau ketinggian tetap memerlukan data pendukung.
- QR mengikuti olahraga sesi yang dipindai; pilihan preview tidak boleh mengubah olahraga pada tiket QR.

## Verifikasi

- Seluruh 135 tes lulus setelah perbaikan alur dan scrollbar; analyzer bersih.
- APK debug dibangun dan dipasang dengan pembaruan tanpa menghapus data pada perangkat Android yang tersambung.
- Sheet olahraga aktif dibuka dan digulir melalui ADB. Screenshot diperiksa sebelum/sesudah swipe: indikator tipis berjarak dari tepi, tanpa track berwarna yang menutupi isi.
- Pengujian perangkat tersebut memverifikasi tampilan sheet/scroll; bukan klaim seluruh fitur telah diuji manual pada perangkat.
