import 'package:flutter/painting.dart';

import '../theme/app_colors.dart';

/// Streak stages. Each one stacks visual cues (colour, size, accessories, speed).
enum Stage {
  pemula('Pemula', 1, AppColors.yellowL, AppColors.yellow),
  gesit('Gesit', 3, AppColors.blueL, AppColors.blue),
  turbo('Turbo', 7, AppColors.orangeL, AppColors.orange),
  juara('Juara', 14, AppColors.purpleL, AppColors.purple),
  legend('Legend', 30, AppColors.greenL, AppColors.green);

  const Stage(this.label, this.minStreak, this.tint, this.color);

  final String label;
  final int minStreak;
  final Color tint;
  final Color color;

  static Stage forStreak(int days) => Stage.values.lastWhere((s) => days >= s.minStreak, orElse: () => Stage.pemula);

  Stage? get next => index + 1 < Stage.values.length ? Stage.values[index + 1] : null;
}

/// The 18 sport-family mascots ("Geng Gemoy").
enum Animal {
  otto('Otto', 'Berang-berang', 'Renang & selam'),
  pingo('Pingo', 'Pinguin', 'Selancar & perahu'),
  kiki('Kiki', 'Kelinci', 'Lari'),
  gugun('Gugun', 'Kambing', 'Hiking & paralayang'),
  rubi('Rubi', 'Rubah', 'Sepeda & roda'),
  doni('Doni', 'Corgi', 'Lempar-tangkap'),
  ciko('Ciko', 'Anak Ayam', 'Badminton & takraw'),
  pandu('Pandu', 'Panda', 'Padel, tenis & pickleball'),
  cimot('Cimot', 'Kucing', 'Tenis meja & squash'),
  koko('Koko', 'Koala', 'Sepak bola & futsal'),
  jeri('Jeri', 'Jerapah', 'Basket & voli'),
  bento('Bento', 'Banteng', 'Rugby & hoki'),
  tara('Tara', 'Harimau', 'Bela diri'),
  gembul('Gembul', 'Gajah', 'Fitness'),
  kura('Kura', 'Kura-kura', 'Yoga, pilates & catur'),
  flami('Flami', 'Flamingo', 'Dansa & senam'),
  momo('Momo', 'Monyet', 'Panjat'),
  eko('Eko', 'Elang', 'Presisi');

  const Animal(this.label, this.species, this.family);

  final String label;
  final String species;
  final String family;

  /// "Ciko si Anak Ayam"
  String get title => '$label si $species';

  String head(Stage s) => 'assets/mascots/head/${name}_${s.name}.webp';
  String body(Stage s) => 'assets/mascots/body/${name}_${s.name}.webp';
  String lottie(Stage s) => 'assets/lottie/${name}_${s.name}.json';
}

/// Neutral profile avatars (not part of the 18 sport mascots).
enum ProfileAvatar {
  kapi('Kapi', 'Kapibara'),
  lolo('Lolo', 'Aksolotl'),
  kodi('Kodi', 'Kodok'),
  owi('Owi', 'Burung hantu'),
  hamu('Hamu', 'Hamster'),
  paka('Paka', 'Alpaka'),
  madu('Madu', 'Beruang madu'),
  komo('Komo', 'Komodo');

  const ProfileAvatar(this.label, this.species);

  final String label;
  final String species;
  String get asset => 'assets/avatars/$name.webp';
}

enum ShopIcon {
  permata,
  esBatu,
  bingkaiEmas,
  stikerHewan,
  pelangi,
  boostPetir;

  String get asset => 'assets/icons/${switch (this) {
        permata => 'permata',
        esBatu => 'es_batu',
        bingkaiEmas => 'bingkai_emas',
        stikerHewan => 'stiker_hewan',
        pelangi => 'pelangi',
        boostPetir => 'boost_petir',
      }}.webp';
}
