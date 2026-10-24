# Klubby (mobile)

Aplikasi Flutter untuk Android dan iOS, dibangun dari desain `klubby_app.pen`.

## Menjalankan

```bash
flutter pub get
flutter run
```

Target platform:

- Android minSdk 26 (Health Connect)
- iOS 15+, memakai UIScene lifecycle sehingga siap untuk iOS 26/27

Sebelum build iOS pertama, jalankan `cd ios && pod install`. Lalu aktifkan capability HealthKit di Xcode/App ID.

## Arsitektur

Clean architecture per fitur. State management memakai BLoC (Cubit).

```
lib/
  core/          theme, widgets & motion, router (go_router), DI (get_it), services platform
  features/<f>/
    domain/        entities + repository interfaces (tanpa Flutter)
    data/          implementasi repository (mock/seed sekarang, siap diganti API)
    presentation/  cubit + pages
```

- Cubit global (Me, Sessions, Clubs, Feed, League, Wearable, Goyang, Tournament) disediakan di `app.dart`.
- Cubit per alur (Onboarding, Recorder) dibuat oleh `ShellRoute` di `core/router/app_router.dart`.
- Semua path ada di `core/router/routes.dart`. Kode layar di desain (A1…P6) tertulis di doc comment tiap page.

## Sensor & izin

| Fitur | Android | iOS |
|---|---|---|
| Rekam GPS (I2/I3), Beacon | `ACCESS_FINE/COARSE/BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION` | `NSLocationWhenInUse…`, `NSLocationAlwaysAndWhenInUse…`, background mode `location` |
| Scan QR check-in, foto profil | `CAMERA` | `NSCameraUsageDescription`, `NSPhotoLibrary…` |
| Goyang Ajak Main (akselerometer) | `ACTIVITY_RECOGNITION`, `HIGH_SAMPLING_RATE_SENSORS` | `NSMotionUsageDescription` |
| Smartwatch & kesehatan | `health.*` (Health Connect) | HealthKit entitlements + `NSHealth…` |
| Pengingat streak | `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` | izin notifikasi diminta di A8 |

Semua izin diminta saat dibutuhkan, tidak saat launch.

`ios/Runner/PrivacyInfo.xcprivacy` berisi privacy manifest Apple. `ios/Podfile` hanya meng-compile izin `permission_handler` yang benar-benar dipakai.

Detail smartwatch ada di [docs/SMARTWATCH.md](docs/SMARTWATCH.md).

## Tes

```bash
flutter analyze
flutter test
```
