# Klubby untuk Wear OS (Galaxy Watch)

Modul `android/wear` adalah app jam Klubby: rekam olahraga langsung dari jam, tanpa HP. Perilakunya meniru app Strava untuk Wear OS (riset: support.strava.com, "How Do I Use the Strava App on My WearOS Watch?", Nov 2026).

Syarat: Wear OS 3+ (Galaxy Watch4 dan lebih baru, Pixel Watch). Stack: Kotlin, Compose for Wear OS (Material 3), Health Services `ExerciseClient`, Wearable Data Layer.

## Yang direkam

| Data | Sumber | Olahraga |
|---|---|---|
| Waktu bergerak (tanpa jeda & auto-pause) | `activeDurationCheckpoint` | semua |
| Detak jantung live, rata², maks, zona 1–5, sampel per waktu | `HEART_RATE_BPM`, `HEART_RATE_BPM_STATS` | semua |
| Kalori | `CALORIES_TOTAL` | semua |
| Jarak, pace/kecepatan, split per km | `DISTANCE_TOTAL`, `SPEED` | lari, jalan, sepeda, trail, MTB, hiking, renang kolam |
| Rute GPS (polyline) | `LOCATION` | outdoor |
| Elevasi saat ini & elevasi naik | `ABSOLUTE_ELEVATION`, `ELEVATION_GAIN_TOTAL` | outdoor |
| Kadens & langkah | `STEPS_PER_MINUTE`, `STEPS_TOTAL` | lari, jalan, hiking |

Data yang tidak didukung jam tidak diminta. Data yang belum tersedia (mis. GPS belum dapat sinyal) tampil `--`, bukan 0.

## Alur (mengikuti Strava)

1. Pilih olahraga. Olahraga yang paling sering dipakai ada di atas.
2. Izin diminta saat pertama mulai, hanya yang dibutuhkan olahraga itu (lokasi hanya untuk outdoor).
3. Jika app olahraga lain (mis. Samsung Health) sedang merekam, muncul peringatan. Wear OS hanya bisa merekam satu latihan.
4. Hitung mundur 3 detik, ketuk untuk lewati. GPS & sensor detak dipanaskan selama hitung mundur. Tidak ada layar "menunggu GPS".
5. Layar rekam punya 3 halaman (geser): Kontrol ← Statistik → Detak jantung.
6. Jeda/Lanjut. Selesai harus ditahan ±1,2 detik. Jam bergetar saat jeda, lanjut, dan selesai.
7. Auto-pause (lari & sepeda) bisa dinyalakan/dimatikan di beranda. Label "AUTO-PAUSE" tampil saat aktif.
8. Layar mati → mode ambient. Angkat pergelangan untuk kembali ke rekaman. Ikon Ongoing Activity ada di watch face.
9. Ringkasan → **Simpan** atau **Buang** (dengan konfirmasi).
10. Tersimpan di jam lalu dikirim ke HP. Jika HP jauh, muncul di daftar **Belum sinkron** dan dikirim ulang otomatis.

Mode kedua: bila rekaman dimulai di **HP**, jam menampilkan waktu/jarak/pace dari HP, mengirim BPM live, dan punya tombol Jeda/Lanjut/Selesai.

## Sinkron ke HP

Protokol di `SMARTWATCH.md`. Tambahan dari app jam:

- watch → phone `workout` membawa field tambahan `activeSec`, `calories`, `maxHr`, `elevGain`, `avgCadence`, `steps`, `splits`, `polyline`. HP saat ini memakai `sport/start/end/distance/avgHr`.
- phone → watch `workout_ack` `{ "start": <ms> }`: workout dianggap terkirim.
- phone → watch `hello` `{ "account", "name" }`: HP dibuka. Jam menyimpan akun HP lalu mengirim workout yang tertunda.
- watch → phone `whoami`: jam menanyakan akun HP; HP menjawab dengan `hello`.
- `workout` membawa `account`. HP mengabaikan (tanpa ack) workout dari akun lain, jadi workout tetap di jam.

### Akun

Login belum ada, jadi HP memakai akun uji hardcode `TestAccount` (`lib/core/services/test_account.dart`: `budismash` / Budi Santoso). Saat pertama dibuka, jam menampilkan **Hubungkan akun** sampai HP menjawab. Tombol **Rekam dulu** tetap bisa merekam; workout ditahan di jam sampai akun terhubung. Setelah terhubung, nama akun tampil di beranda jam.

Syarat Data Layer: `applicationId` jam = HP (`id.klubby.app`) **dan** ditandatangani kunci yang sama. Build debug di komputer yang sama sudah memenuhi.

## Coba di Galaxy Watch

1. Jam: **Settings → About watch → Software info**, ketuk **Software version** 5× untuk Developer options.
2. **Developer options**: nyalakan **ADB debugging** dan **Wireless debugging**. Jam & PC harus di Wi-Fi yang sama.
3. Di **Wireless debugging → Pair new device**, catat IP:port dan kode.
4. PC:

```bash
adb pair <ip>:<port-pairing>
```

```bash
adb connect <ip>:<port>
```

5. Pasang app jam (dari folder `android`):

```bash
./gradlew :wear:installDebug
```

6. Pasang ulang app HP dari komputer yang sama (agar kunci debug sama):

```bash
flutter run
```

7. Buka **Klubby** di jam, pilih **Lari**, mulai.

## Belum ada

- Phone belum memakai `polyline`, `splits`, dan sampel detak dari jam. Workout jam masuk sebagai aktivitas "wearable" (XP terverifikasi) tanpa peta.
- Glance streak/XP di jam (`pushGlance`) belum dipanggil HP, maka belum ada tile/complication.
- Beacon dan zona detak dari profil (umur) belum ada; zona memakai maks 190 bpm.
