# Detail rekaman aktivitas

Tambahan ini mengikuti detail pada video Strava yang diberikan pengguna, sambil memakai komponen, warna dan animasi Klubby yang sudah ada.

## Alur data

1. `RecorderCubit` mencatat waktu mulai, waktu bergerak, total waktu termasuk jeda, jarak kumulatif, koordinat GPS, akurasi, dan elevasi jika tersedia. Data detak jantung/cadence dari `WatchBridge` disimpan dengan waktu dan jarak saat pembacaan diterima.
2. Pada Simpan Aktivitas, pembacaan Health Connect / Apple Health dalam rentang rekaman dapat melengkapi sensor yang tidak diterima langsung. Rentang berakhir ketika rekaman selesai, sehingga waktu mengedit judul tidak dihitung. Pembacaan langkah hanya menjadi cadence untuk jalan/lari dan hanya untuk interval maksimal satu menit.
3. `Activity.samples` menyimpan titik lengkap ke JSON melalui `ActivityRepository`; ringkasan lama tetap dapat dibaca. Satu titik memuat detik sejak mulai, detik bergerak, jarak meter, dan sensor opsional. Waktu absolut diperoleh dari `start` ditambah detik titik tersebut.
4. `FeedRepository` membentuk posting dari aktivitas tersimpan. Klik posting membuka rekaman yang sama, termasuk setelah restart. Pilihan privasi dan penyembunyian detak jantung tetap diterapkan.
5. `ActivityAnalysis` menghitung ringkasan dan grafik dari rekaman itu. Grafik menggambar sebagian titik bila rekaman panjang; data asli tetap tersimpan seluruhnya.

## Detail yang ditampilkan

| Data | Asal / perhitungan |
| --- | --- |
| Rute dan jarak | Koordinat asli dan jarak kumulatif GPS; rute disesuaikan agar muat dalam peta yang ada. |
| Waktu bergerak / total | Timer bergerak dan selisih waktu mulai–selesai; jeda manual tidak menambah waktu bergerak. |
| Pace rata-rata / termasuk jeda | Waktu bergerak atau total waktu dibagi jarak. |
| Grafik pace | Perubahan jarak dan waktu bergerak antartitik GPS. |
| Split per km / tercepat | Interpolasi saat melewati setiap kilometer; sisa kilometer ditandai terpisah. Split tercepat memakai kilometer penuh. |
| Elevasi dan kenaikan GPS | Altitude GPS dengan akurasi vertikal yang tersedia; perubahan kecil di bawah 3 m disaring saat menghitung kenaikan. Belum memakai koreksi model elevasi medan. |
| Detak jantung rata-rata / maksimum | Pembacaan jam atau health store; ringkasan lama tetap menampilkan rata-rata yang tersimpan. |
| Cadence rata-rata / maksimum | Pembacaan jam atau laju langkah dari health store. Unit spm untuk langkah dan rpm untuk sepeda. |
| Skor, catatan, foto, perangkat | Isian dan sumber yang memang disimpan bersama aktivitas. |

Sentuh/geser grafik untuk memilih nilai dan posisi jarak. Aktivitas tanpa jarak menggunakan sumbu waktu. Kontrol grafik juga menyediakan aksi naik/turun pada Semantics.

## Batas data

- Aktivitas lama yang hanya memiliki ringkasan tidak bisa menghasilkan grafik historis. UI menjelaskan sensor yang belum terekam, tanpa membuat seri contoh.
- Ponsel tidak menghasilkan detak jantung dari GPS. Grafik detak jantung/cadence memerlukan sumber sensor yang terhubung dan izin pengguna. Catatan manual tetap berisi data yang dimasukkan pengguna.
- Companion Wear OS/watchOS belum tersedia di repo. `WatchBridge` sudah menerima protokol sensor, sedangkan jalur health store bergantung data yang sudah disinkronkan aplikasi jam ke ponsel. Ini tidak menambahkan OAuth atau impor Strava.
- Posting dan rekaman tersimpan lokal. Distribusi posting ke pengguna lain masih memerlukan backend yang memang belum terhubung.
- Pengujian otomatis mencakup persistensi, perhitungan, jeda dan interaksi grafik; pengambilan sensor pada HP/jam sungguhan belum diverifikasi untuk versi ini. Tidak ada build/instalasi APK pada langkah ini.
