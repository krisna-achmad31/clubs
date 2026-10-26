# Integrasi Smartwatch

Klubby menerima data jam tangan lewat dua jalur. Keduanya dipakai bersamaan.

| Jalur | Android | iOS | Dipakai untuk |
|---|---|---|---|
| **Health store** (`HealthService`, paket `health`) | Health Connect | HealthKit | Workout selesai, detak jantung, jarak, kalori dari jam apa pun (Wear OS, Galaxy Watch, Garmin, Apple Watch). Sumber `ActivitySource.wearable` → XP terverifikasi. |
| **Live link** (`WatchBridge`, paket `watch_connectivity`) | Wearable Data Layer | WatchConnectivity | Kontrol rekaman dari jam (pause/resume/stop), BPM live di I3, glance streak/maskot di watch face. Butuh app companion Klubby di jam. |

`WearableCubit` menggabungkan keduanya. Halaman yang memakainya: A9 (hubungkan jam), I1/I5 (kartu jam), I3 (BPM live), M4 (Perangkat Terhubung).

## Protokol phone ⇄ watch

Pesan berupa map biasa, jadi companion Kotlin/Swift tidak perlu kode bersama.

Phone → watch:

```jsonc
{ "type": "session_start", "sport": "lari", "at": 1761300000000 }
{ "type": "tick", "elapsed": 754, "distance": 2.41, "pace": "5:12" }
{ "type": "session_stop" }
// applicationContext (state terakhir, dikirim walau jam tidak reachable)
{ "streak": 13, "xp": 2120, "mascot": "ciko", "next": "Rab 19.00 · GOR Senayan" }
```

Watch → phone:

```jsonc
{ "type": "hr", "bpm": 148 }
{ "type": "cadence", "spm": 120 }
{ "type": "control", "action": "pause" | "resume" | "stop" }
{ "type": "workout", "sport": "lari", "start": 1761300000000, "end": 1761302400000, "distance": 5020, "avgHr": 151 }
```

`cadence` berisi putaran per menit untuk sepeda atau langkah per menit untuk jalan/lari; nama field transport tetap `spm`. Pembacaan live disimpan pada titik waktu/jarak rekaman, sehingga dapat dibuka dari detail posting. Lihat `ACTIVITY_DETAILS.md` untuk alur persistensi dan grafik. Pesan `workout` tetap berupa ringkasan status koneksi; sinkronisasi ini tidak otomatis menerbitkan workout lama sebagai posting baru.

## Izin

- **Android**: izin `android.permission.health.*` (read/write exercise, distance, calories; read heart rate, steps) ada di `AndroidManifest.xml`. Ada juga intent rationale Health Connect (`ACTION_SHOW_PERMISSIONS_RATIONALE` dan alias `VIEW_PERMISSION_USAGE`). `MainActivity` memakai `FlutterFragmentActivity`. minSdk 26.
- **iOS**: `NSHealthShareUsageDescription` dan `NSHealthUpdateUsageDescription` ada di Info.plist. Capability HealthKit ada di `Runner.entitlements` dan sudah terpasang lewat `CODE_SIGN_ENTITLEMENTS`. Aktifkan juga HealthKit pada App ID di Apple Developer.

## Belum ada di repo ini

App companion native belum dibuat:

- target watchOS (SwiftUI + `WCSession`)
- modul Wear OS (Compose for Wear + `MessageClient` pada path `/klubby`)

Selama companion belum ada, jalur Health store tetap jalan, jadi XP terverifikasi dari jam sudah bisa dipakai. Live link otomatis nonaktif karena `isPaired`/`isReachable` bernilai `false`.
