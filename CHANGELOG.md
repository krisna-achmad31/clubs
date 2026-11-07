# Changelog

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
