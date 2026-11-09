part of 'profile_pages.dart';

/// Encouragement tied to the session milestones of each mascot.
String evolutionStageDescription(Animal animal, Stage stage) => switch (stage) {
  Stage.pemula =>
    'Sesi pertama membuka petualanganmu bersama ${animal.label}. '
        'Yuk, lanjutkan sampai 3 sesi untuk bertemu versi Gesit!',
  Stage.gesit =>
    'Sudah 3 sesi, ${animal.label} makin siap menemani langkahmu. '
        'Nikmati setiap sesi dan kumpulkan 7 sesi untuk membuka tahap Turbo!',
  Stage.turbo =>
    'Tujuh sesi bersama ${animal.label} jadi bukti kamu terus melangkah. '
        'Lanjutkan dengan ritmemu sendiri menuju tahap Juara di 14 sesi!',
  Stage.juara =>
    'Empat belas sesi, perjalananmu bersama ${animal.label} layak dirayakan. '
        'Masih ada tahap Legend di 30 sesi, jadi ayo buat cerita berikutnya!',
  Stage.legend =>
    'Tiga puluh sesi mengantarkan ${animal.label} ke tahap tertinggi, Legend. '
        'Terus kumpulkan sesi dan kenangan baru, petualangan kalian masih panjang!',
};
