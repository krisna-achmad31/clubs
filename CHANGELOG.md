# Changelog

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
