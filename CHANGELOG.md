# Changelog

## 09 November 2026 (1.2.0+3)
achmad_yukrisna

- Jam tangan (baru): app Klubby untuk Wear OS / Galaxy Watch4 ke atas (modul `mobile/android/wear`), alurnya mengikuti app Strava di jam. Rekam lari, sepeda, jalan, dan olahraga lain langsung dari jam tanpa HP: waktu bergerak, detak jantung live + zona 1–5, kalori, jarak, pace/kecepatan, split per km, rute GPS, elevasi, kadens, dan langkah.
- Jam tangan: hitung mundur 3 detik (ketuk untuk lewati), layar rekam 3 halaman (Kontrol · Statistik · Detak), Jeda/Lanjut, Selesai ditahan, auto-pause untuk lari & sepeda, getar, mode ambient, ikon Ongoing Activity, lalu Simpan atau Buang (dengan konfirmasi). Ada peringatan bila Samsung Health sedang merekam.
- Jam tangan: workout dikirim ke HP dan dikirim ulang sampai HP mengonfirmasi (`workout_ack`); daftar "Belum sinkron" untuk yang tertunda; HP memanggil `hello` saat dibuka. Bila rekaman dimulai di HP, jam menampilkan waktu/jarak/pace, mengirim BPM live, dan bisa jeda/lanjut/selesai. Jam terhubung ke akun yang dilaporkan HP; workout dari akun lain diabaikan.
- Jam tangan: workout dari jam dan Health Connect/HealthKit diimpor sekali (tanpa duplikat, minimal 5 menit) dan masuk streak, poin liga, dan gear.
- Desain: board "Flow Q · Jam Galaxy Watch (Wear OS)" berisi 13 layar jam di `klubby_app.pen`.
- Peta: rute GPS memakai OpenStreetMap (`flutter_map`) di feed, detail post, detail aktivitas, rekam GPS, dan pratinjau simpan. Aktivitas tanpa koordinat menampilkan keadaan kosong.
- Audit flow (lihat `mobile/docs/audit-2026-11/RINGKASAN.md`), perbaikan P0: saldo tidak bisa digandakan lewat batal tiket; berbagi lokasi awal default OFF dan mengikuti setting; klub, sesi, tiket, kas, chat, reaksi & komentar feed tersimpan setelah restart; akun baru tidak mewarisi data demo; juara Gugur = pemenang final; Back di Simpan GPS minta konfirmasi; GPS diam (< 200 m atau < 2 menit) disimpan sebagai kasual.
- Perbaikan P1: gear mencatat km & jam main; poin liga dihitung per menit dari aktivitas terverifikasi; streak putus otomatis dan notifikasi streak/Es Batu memakai angka live; setting (BPM live, zona privasi, kontak darurat, notifikasi, Goyang) benar-benar dipakai; deep link `klubby.id/p|k|m` dan `klubby://` membuka post/klub/tiket; turnamen dikunci saat berjalan dan hasil podium bisa disimpan; sesi lewat/batal tidak bisa diikuti; pembayar & tamu masuk daftar host; BUAT MABAR dari klub membawa klub tersebut.
- Perbaikan P2: pace tidak lagi tampil `5'60"`, renang /100m dan sepeda km/j; menit liga memakai moving time; jumlah anggota klub satu sumber; menu post sendiri punya Edit post dan Hapus dari feed; Bisukan bisa dibatalkan; Mabar Rp0 tanpa biaya layanan; perhitungan kursi saat batal dengan tamu; date/time picker berbahasa Indonesia; Back di Selesai/Evolusi kembali ke Feed; Catat Manual minta konfirmasi sebelum dibuang.
- Turnamen yang sedang berjalan tetap tersimpan saat app ditutup; hasil yang disimpan dihitung 1 kehadiran liga.
- Profil/Geng: evolusi dihitung dari sesi terverifikasi per keluarga olahraga (1/3/7/14/30), streak harian terpisah dari evolusi, stempel terbaru membuka detail hari; PRD F-5.2 diperbarui.
- Test: aturan P1–P3, tabel liga, akun jam, impor workout, peta OSM, kalender stempel (total 184 test).

## 07 November 2026 (1.1.0+2)
achmad_yukrisna

- Klub: chip di detail klub jadi Jadwal · Feed · Kas · Anggota dan berganti di dalam halaman (Kas tidak lagi membuka halaman baru); Chat jadi tombol mengambang dengan badge pesan belum dibaca.
- Klub: Feed klub tidak lagi ikut toggle KOMUNITAS/PUBLIK, dan Feed serta Kas klub hanya bisa dilihat anggota.
- Buat Klub: bagian "Anggota awal" untuk memilih pengguna Klubby lewat nomor HP, @username, atau kontak; mereka langsung masuk saat klub dibuat, lalu halaman klub baru terbuka.
- Undang anggota (baru): dari kontak (pengguna Klubby bisa langsung ditambah, lainnya diundang lewat WhatsApp), tambah manual lewat nomor/@username, atau bagikan tautan & kode klub. Bisa dibuka setelah Buat Klub, dari tab Anggota, dan dari menu klub. Pencocokan kontak masih demo.
- Pilih olahraga: daftar urut A–Z dengan kolom pencarian (Buat Klub dan Tambah Gear).
- Rekening pencairan: opsi "Lainnya" untuk bank/e-wallet di luar daftar; pesan validasi kini tampil di dalam sheet sehingga alasan gagal simpan terlihat.
- Geng Gemoy: kartu Perkembangan (streak, tahap 1–5, berapa hari lagi ke tahap berikutnya, jalur 5 tahap evolusi, rekor, Es Batu, aturan putus streak) dan detail per hewan.
- Geng Gemoy: kartu share evolusi 9:16 untuk story (maskot, tahap, streak, target berikutnya) dengan 3 pilihan warna, bisa dibagikan atau disimpan ke galeri.
- Toast kini tampil di atas layar dan di atas sheet, tidak lagi tersembunyi di belakang sheet atau menutupi tombol utama.
- Perbaikan: nama anggota ganda di daftar Anggota; tombol BUAT KLUB tidak lagi macet loading saat gagal simpan.
- Izin baru: membaca kontak (iOS & Android), hanya baca dan tidak diunggah.
- Test: tap-through tab Klub, Undang anggota, dan Geng Gemoy (total 124 test).

## 07 November 2026 (1.0.0+1)
achmad_yukrisna

- Profil: chip Dashboard, Stempel, Tanding, dan Gear kini berfungsi sebagai tab di dalam halaman Profil, tidak lagi membuka halaman baru.
- Bottom sheet: semua sheet dibatasi maksimal setengah tinggi layar; isi yang panjang bisa di-scroll di bawah grabber yang tetap, dan keyboard tidak memotong form.
- Feed: tab KOMUNITAS berisi aktivitasmu, teman yang diikuti, dan anggota klub; tab PUBLIK hanya berisi aktivitas yang dibagikan publik dari semua pemain. Post "Hanya Klub" tidak lagi bocor ke PUBLIK. Ditambah keterangan singkat di bawah toggle dan contoh post publik dari non-teman.
- Feed: aktivitas yang baru disimpan langsung muncul tanpa restart aplikasi, dan feed bisa di-refresh dengan tarik ke bawah.
- Feed: perbaikan toggle PUBLIK yang bisa kembali sendiri ke KOMUNITAS saat feed masih memuat.
- Detail post: menyembunyikan, membisukan, atau melaporkan post dari halaman detail kini otomatis kembali ke Feed.
- Stiker: stiker di komentar feed kini sama besar dan sama gayanya dengan stiker di chat klub (komponen `KSticker` bersama).
- Test: tap-through otomatis seluruh flow tab Feed (filter tab, detail post, notifikasi, reaksi, komentar, stiker, menu post, sheet rekam, header stats, auto-refresh).
