# Audit Flow Klubby — Ringkasan (8 Nov 2026)

Sumber: 5 agent audit kode (per tab) + 1 agent tester di HP asli (Infinix X6851 via adb).
Baseline: 161 tes lulus, `flutter analyze` bersih, tidak ada crash/overflow di device.
Detail per area (file:line, severity, test case) ada di file lain di folder ini.

## P0 — Bug data/kalkulasi serius

| # | Masalah | Lokasi | Bukti |
|---|---|---|---|
| 1 | Saldo bisa digandakan: bayar tidak memotong saldo, batal tiket menambah `fee × orang`; join→bayar→batal bisa diulang lalu ditarik | sessions_cubit.dart:486-509, session_flow_pages.dart:333, host_flow_pages.dart:706 | Kode |
| 2 | Lokasi awal dibagikan walau setting "Tawarkan berbagi lokasi" OFF (`beacon` default `true`, tidak baca setting) | activity.dart:180 | **Device** |
| 3 | Klub, sesi, tiket, kas, chat, reaksi & komentar feed hilang setelah restart (repo in-memory) | club/session/feed repository_impl | **Device** (reaksi+komentar) |
| 4 | Daftar/keluar akun → user baru mewarisi data demo Budi (streak 13, XP 2120, 7 hewan teradopsi); aktivitas & klub user lama tetap ada | me_cubit.dart:94-98, profile_repository_impl.dart:32-68 | Kode |
| 5 | Juara turnamen Gugur = total poin terbanyak, bukan pemenang final | tournament_flow_pages.dart:430, tournament_engine.dart:37 | Kode (dicek manual) |
| 6 | Back di halaman Simpan GPS membuang rekaman tanpa konfirmasi | activity_pages.dart ~796 | Kode |
| 7 | GPS diam (0,04 km) tetap "Terverifikasi GPS", +140 XP, menaikkan evolusi | recorder / activity_pages | **Device** |

### Status perbaikan P0 (8 Nov 2026)
1. **Saldo** — refund dibatasi uang iuran yang benar-benar dibayar (tanpa biaya layanan); host batal mengembalikan nominal tiket.
2. **Lokasi** — `beacon` default OFF dan GPS Ready membaca setting `beacon`.
3. **Persistence** — klub (keanggotaan, buatan sendiri, chat, kas, payout, Pro), sesi + tiket/RSVP, dan reaksi/komentar/sembunyikan/bisukan/notifikasi dibaca feed disimpan ke SharedPreferences (`clubs_v1`, `sessions_v1`, `rsvps_v1`, `feed_v1`). Tes: `test/domain/persistence_test.dart`.
4. **Akun baru** — saat daftar: klub/sesi/tiket/feed direset; di ReadyPage aktivitas & gear dihapus dan profil dibuat baru (setting perangkat dipertahankan, liga/check-in/Pro direset).
5. **Gugur** — peringkat berdasarkan babak tersingkir; juara = pemenang final. Tes ditambah.
6. **Back di Simpan GPS** — memunculkan konfirmasi buang.
7. **GPS diam** — terverifikasi hanya jika ≥ 200 m dan ≥ 2 menit; selain itu disimpan sebagai kasual (+ banner).

## P1 — Fitur tidak terhubung / tidak sinkron

- **Gear**: km/jam sepatu & raket tidak pernah bertambah dari aktivitas (gearId disimpan, tak ada akumulasi). *Device: tetap 620/700 km.*
- **Liga**: "+25 POIN KLUB" di Done/Story tidak sesuai rumus liga (jam terverifikasi ×10 → lari 30 menit = 0). Poin klub & "Kontribusimu" tidak berubah; header 320 vs daftar "Kamu 310". Liga masih "streak 14" saat Profil/Feed 1–2. *Device.*
- **Streak**: hanya dihitung ulang saat menyimpan aktivitas → tidak pernah turun saat bolos; layar "STREAK PUTUS" tak pernah muncul; notifikasi "Streak dalam bahaya"/"Streak 14 aman" statis. *Device.*
- **BUAT MABAR dari halaman klub** tidak membawa clubId → sesi masuk PB Smash Ceria, sport badminton.
- **Peserta yang bayar** tidak masuk daftar peserta host (Kelola 4/16 tapi "Belum ada peserta", check-in 0/0). *Device.*
- **QR check-in**: menerima sesi yang tidak diikuti/dibatalkan, durasi 0 → 0 jam liga, "WAKTU 0:00" di feed, host tak melihat kehadiran.
- **Sesi lampau/dibatalkan** masih bisa di-join & dibayar (Klub, Jadwal, Explore, Venue). *Device: 29 Okt & 1 Nov.*
- **Status tiket beda tempat**: "LUNAS" di daftar Klub vs "ANTRE" di jadwal klub; "LIHAT DETAIL MABAR" kembali ke daftar. *Device.*
- **Wearable/Health** workout tidak pernah jadi aktivitas, padahal banner bilang dihitung untuk liga.
- **Setting tersimpan tapi tidak dipakai**: liveHr, hideCal, kontak darurat, zona privasi, semua `notif_*`; `NotificationService.show` tak pernah dipanggil. Goyang OFF tidak bertahan setelah restart.
- **Ganti nama** tidak memperbarui feed (`FeedPost ==` tidak membandingkan author); banyak teks "Budi" hardcode.
- **Post seed Rian** memakai aktivitas pribadi user (`gbk`) → data user tampil atas nama Rian, PR 4:12. *Device.*
- **Klaim tiket (/m/:id)** memberi tiket gratis tanpa cek kapasitas/bayar; `/claim` default `rabu-malam`.
- **Deep link** `klubby.id/p/`, `/k/`, `/m/` tidak membuka app (hanya `klubby://` terdaftar, rute `/p` & `/k` tidak ada).
- **Season liga** tidak pernah berganti (`_daysLeft = 3` konstan); segment selalu "Tanjakan Senayan".
- **Turnamen**: setting bisa mengubah turnamen yang sedang jalan; King of the Court melewatkan pemain (5 pemain/3 lapangan); tidak tersimpan; hasil tidak ke liga/feed/profil.
- **Klub buatan sendiri** tidak muncul di `nearby()`; admin tunggal bisa keluar dan klub hilang.

### Status perbaikan P1 (8 Nov 2026)
Semua item P1 di atas sudah diperbaiki, plus temuan device: chat klub kini terbuka di pesan terbaru, teks "Bagikan lokasi awal" tidak menabrak toggle, dan baris Pengaturan tidak bisa membuka halaman dua kali (Back dobel di Privasi).
- **Liga**: poin jam dihitung per menit (`hourPoints`), hanya untuk aktivitas terverifikasi; layar Selesai menampilkan "—" jika bukan anggota liga olahraga itu. Musim berakhir di akhir bulan; efforts "Kamu 4:12" palsu dihapus.
- **Streak** putus otomatis saat hari bolong melebihi Es Batu (saat buka app / kembali ke app); notifikasi streak & Es Batu memakai angka live dan mengikuti setting notifikasi.
- **Gear** mencatat km dan jam main dari GPS, manual, QR, jam tangan.
- **Jam tangan**: latihan dari Health Connect/watch diimpor sekali (tanpa duplikat, minimal 5 menit) dan masuk streak/poin.
- **Setting**: Goyang OFF bertahan restart; BPM disembunyikan jika detak jantung live mati; zona privasi memotong ujung rute di post sendiri; kontak darurat ikut di pesan lokasi awal.
- **Feed**: post Rian tidak lagi memakai aktivitas user; undangan "Budi" diganti "Raka".
- **Klub**: klub publik buatan sendiri muncul di sekitar; admin tunggal tidak bisa keluar (muncul toast).
- **Deep link**: `klubby.id/p/…`, `/k/…`, `/m/…` dan `klubby://` diarahkan ke post/klub/tiket.
- **Turnamen**: setting dikunci saat turnamen jalan (lanjutkan / akhiri & buat baru); antrean King of the Court diperbaiki; hasil podium bisa disimpan sebagai aktivitas (streak/feed).
- **Mabar/tiket**: sesi lewat/batal tidak bisa diikuti; klaim tiket web memakai slot dan cek kapasitas; pembayar dan tamu masuk daftar host; BUAT MABAR dari halaman klub memakai klub itu.

Batasan yang tersisa: turnamen yang sedang berjalan belum tersimpan saat app ditutup; hasil turnamen tidak memberi poin liga (dicatat manual); App Links butuh `assetlinks.json` di klubby.id untuk verifikasi otomatis; universal link iOS belum diatur.

Verifikasi: `flutter analyze` bersih, 171 test lulus (termasuk `test/domain/p1_rules_test.dart` baru).

## P2 — Kalkulasi & UX kecil

- `Fmt.pace` bisa menampilkan `5'60"` (format.dart:34-40) — dipakai di rekam, simpan, feed, suara, jam.
- Pace selalu min/km (renang/sepeda harus /100m & km/j).
- Menit liga memakai waktu dinding termasuk jeda, bukan moving time.
- Kolom anggota beda: 96 (Liga) vs 48 (halaman klub). *Device.*
- Banner musim Liga membuka halaman skor, bukan "Musim liga". *Device.*
- Menu post sendiri: "Bisukan/Laporkan diri sendiri", tanpa edit/hapus; mute tak bisa dibatalkan. *Device.*
- Hitung ulang filled saat batal dengan tamu + waitlist meleset; refund+hapus mengurangi dua kali.
- Mabar Rp0 tetap kena biaya layanan Rp2.000; retry pembayaran kedaluwarsa menghilangkan tamu.
- Done/Evolve dicapai lewat `go` → back menutup app; manual fallback lupa olahraga dari GPS.
- Date/time picker manual berbahasa Inggris; halaman Scan berjudul "Rekam Aktivitas". *Device.*
- Tombol "Buat Klub" terlihat mati karena field rekening wajib ada di bawah lipatan. *Device.*
- Tiga angka "jumlah sesi" berbeda di Profil (23 / 132 / badge 100).

### Status perbaikan P2 (8 Nov 2026)
- **Pace** dibulatkan ke detik dulu (tidak ada lagi `5'60"`); renang memakai pace /100m, sepeda km/j (rekam, simpan, feed, jam, suara).
- **Menit liga** memakai moving time, jeda tidak dihitung.
- **Anggota klub** di Liga dan halaman klub sudah satu sumber (`club.members`); monogram "PS" tidak ada lagi di kode. Banner musim membuka "Musim liga".
- **Menu post sendiri**: "Hapus dari feed" (aktivitas tetap di profil), tanpa Bisukan/Laporkan diri sendiri. Bisukan bisa dibatalkan di Pengaturan → Akun dibisukan. Edit post belum ada.
- **Mabar**: batal dengan tamu memindahkan kursi sebanyak orang yang batal ke antrean; HAPUS setelah refund tidak mengurangi kursi dua kali; batal tamu lewat batas waktu tidak mengubah total; mabar Rp0 tanpa biaya layanan ("Gratis"); COBA LAGI setelah waktu habis tetap membawa tamu.
- **Done/Evolve**: Back kembali ke Feed, tidak menutup app. CATAT TANPA GPS membawa olahraga yang dipilih.
- **Bahasa**: date/time picker berbahasa Indonesia; halaman Scan berjudul "Check-in QR".
- **Buat Klub**: tanpa rekening, sheet rekening langsung terbuka.
- **Jumlah sesi**: lencana "100 sesi" memakai angka yang sama dengan "sesi tercatat"; angka Geng diberi label "sesi evolusi" (hanya sesi terverifikasi).
- **Notifikasi**: grup lama berjudul "SEBELUMNYA"; umur Es Batu dari tanggal sebenarnya; notifikasi liga tanpa angka poin basi.

Verifikasi: `flutter analyze` bersih, 177 test lulus (termasuk `test/domain/p2_rules_test.dart`).

### Status lanjutan (8 Nov 2026)
- **Turnamen tersimpan**: turnamen yang berjalan bertahan saat app ditutup (dicek di HP: force-stop → "Americano Cup masih berjalan (babak 1/11)").
- **Turnamen → liga**: SIMPAN HASIL KE PROFIL dihitung 1 kehadiran liga (+25 poin); jam main tetap tidak terverifikasi. Teruji lewat test, belum dicek di HP (butuh turnamen sampai selesai).
- **Edit post**: menu post sendiri punya "Edit post" (judul, catatan, siapa yang bisa melihat); urutan feed tetap. Dicek di HP lalu judul dikembalikan.
- **Catat Manual**: Back dengan isian belum disimpan memunculkan "Buang catatan ini?" (tombol header dan Back sistem). Dicek di HP.
- Masih terbuka: `assetlinks.json` di klubby.id dan universal link iOS; angka Geng vs jumlah sesi.

## Yang sudah benar
Ambang evolusi 1/3/7/14/30 per keluarga hewan; manual menjaga streak tapi tidak menambah evolusi; QR mengikuti sport sesi; Es Batu; kalender hari aktif unik (pergantian tahun/kabisat); onboarding di-skip untuk user lama; manual entry → Feed/streak/XP/stamp sinkron (*device*); pause/resume/stop GPS; setting bertahan restart (*device*); chat klub, host sampai QR, turnamen sampai live (*device*).

## Belum teruji di device
Pembayaran booking baru, membuat klub (butuh data rekening), podium turnamen, gestur goyang fisik, QR check-in nyata.

## Catatan data uji
Tester meninggalkan data di HP: aktivitas uji (GPS + manual), satu sesi host, satu turnamen, satu tantangan yang diikuti. Setting yang diubah sudah dikembalikan.
