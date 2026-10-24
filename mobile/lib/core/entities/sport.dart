import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'mascot.dart';

enum SportCategory {
  raket('Raket'),
  air('Air'),
  lari('Lari & Jalan'),
  tim('Tim'),
  kebugaran('Kebugaran'),
  belaDiri('Bela Diri'),
  roda('Roda'),
  petualangan('Petualangan'),
  presisi('Presisi');

  const SportCategory(this.label);
  final String label;
}

enum SkillLevel {
  pemula('Pemula'),
  pemulaPlus('Pemula+'),
  menengah('Menengah'),
  menengahPlus('Menengah+'),
  mahir('Mahir'),
  pro('Pro');

  const SkillLevel(this.label);
  final String label;
}

class Sport extends Equatable {
  const Sport(this.id, this.name, this.category, this.icon, this.animal, {this.emoji = '', this.positions = const []});

  final String id;
  final String name;
  final SportCategory category;
  final IconData icon;
  final Animal animal;
  final String emoji;
  final List<String> positions;

  /// GPS-recordable sports show distance/pace; the rest track time + score.
  bool get tracksDistance => const {'lari', 'trail', 'jalan', 'sepeda', 'mtb', 'renang', 'hiking', 'kayak', 'dayung', 'triathlon', 'skate', 'sepatu_roda'}.contains(id);

  @override
  List<Object?> get props => [id];
}

/// 66 sports = Reclub's 62 + 4 local favourites, each mapped to one mascot family.
abstract final class Sports {
  static const all = <Sport>[
    // Raket
    Sport('badminton', 'Badminton', SportCategory.raket, LucideIcons.feather, Animal.ciko, emoji: '🏸', positions: ['Tunggal', 'Ganda depan', 'Ganda belakang']),
    Sport('padel', 'Padel', SportCategory.raket, LucideIcons.circleDot, Animal.pandu, emoji: '🎾', positions: ['Kanan', 'Kiri']),
    Sport('tenis', 'Tenis', SportCategory.raket, LucideIcons.circleDot, Animal.pandu, emoji: '🎾'),
    Sport('pickleball', 'Pickleball', SportCategory.raket, LucideIcons.target, Animal.pandu, emoji: '🏓'),
    Sport('tenis_meja', 'Tenis Meja', SportCategory.raket, LucideIcons.disc, Animal.cimot, emoji: '🏓'),
    Sport('squash', 'Squash', SportCategory.raket, LucideIcons.square, Animal.cimot, emoji: '🎾'),
    Sport('roundnet', 'Roundnet', SportCategory.raket, LucideIcons.circle, Animal.cimot, emoji: '🟡'),
    Sport('takraw', 'Sepak Takraw', SportCategory.raket, LucideIcons.hexagon, Animal.ciko, emoji: '⚽'),
    // Lari & jalan
    Sport('lari', 'Lari', SportCategory.lari, LucideIcons.footprints, Animal.kiki, emoji: '🏃'),
    Sport('trail', 'Trail Run', SportCategory.lari, LucideIcons.mountain, Animal.kiki, emoji: '🏃'),
    Sport('jalan', 'Jalan Kaki', SportCategory.lari, LucideIcons.footprints, Animal.kiki, emoji: '🚶'),
    Sport('triathlon', 'Triathlon', SportCategory.lari, LucideIcons.medal, Animal.kiki, emoji: '🏅'),
    // Air
    Sport('renang', 'Renang', SportCategory.air, LucideIcons.waves, Animal.otto, emoji: '🏊'),
    Sport('selam', 'Selam', SportCategory.air, LucideIcons.fish, Animal.otto, emoji: '🤿'),
    Sport('polo_air', 'Polo Air', SportCategory.air, LucideIcons.waves, Animal.otto, emoji: '🤽'),
    Sport('selancar', 'Selancar', SportCategory.air, LucideIcons.waves, Animal.pingo, emoji: '🏄'),
    Sport('kayak', 'Kayak', SportCategory.air, LucideIcons.sailboat, Animal.pingo, emoji: '🛶'),
    Sport('dayung', 'Dayung', SportCategory.air, LucideIcons.ship, Animal.pingo, emoji: '🚣'),
    Sport('layar', 'Layar', SportCategory.air, LucideIcons.sailboat, Animal.pingo, emoji: '⛵'),
    Sport('sup', 'Paddle Board', SportCategory.air, LucideIcons.anchor, Animal.pingo, emoji: '🏄'),
    // Tim
    Sport('sepak_bola', 'Sepak Bola', SportCategory.tim, LucideIcons.goal, Animal.koko, emoji: '⚽', positions: ['Kiper', 'Bek', 'Gelandang', 'Penyerang']),
    Sport('futsal', 'Futsal', SportCategory.tim, LucideIcons.goal, Animal.koko, emoji: '⚽', positions: ['Kiper', 'Anchor', 'Flank', 'Pivot']),
    Sport('mini_soccer', 'Mini Soccer', SportCategory.tim, LucideIcons.goal, Animal.koko, emoji: '⚽', positions: ['Kiper', 'Bek', 'Gelandang', 'Penyerang']),
    Sport('basket', 'Basket', SportCategory.tim, LucideIcons.circleDashed, Animal.jeri, emoji: '🏀', positions: ['PG', 'SG', 'SF', 'PF', 'C']),
    Sport('voli', 'Voli', SportCategory.tim, LucideIcons.volleyball, Animal.jeri, emoji: '🏐', positions: ['Setter', 'Spiker', 'Libero', 'Blocker']),
    Sport('voli_pantai', 'Voli Pantai', SportCategory.tim, LucideIcons.volleyball, Animal.jeri, emoji: '🏐'),
    Sport('netball', 'Netball', SportCategory.tim, LucideIcons.circleDashed, Animal.jeri, emoji: '🏀'),
    Sport('rugby', 'Rugby', SportCategory.tim, LucideIcons.shield, Animal.bento, emoji: '🏉'),
    Sport('hoki', 'Hoki', SportCategory.tim, LucideIcons.slash, Animal.bento, emoji: '🏑'),
    Sport('american_football', 'American Football', SportCategory.tim, LucideIcons.shield, Animal.bento, emoji: '🏈'),
    Sport('lacrosse', 'Lacrosse', SportCategory.tim, LucideIcons.slash, Animal.bento, emoji: '🥍'),
    Sport('frisbee', 'Ultimate Frisbee', SportCategory.tim, LucideIcons.disc, Animal.doni, emoji: '🥏'),
    Sport('softball', 'Softball', SportCategory.tim, LucideIcons.circle, Animal.doni, emoji: '🥎'),
    Sport('baseball', 'Baseball', SportCategory.tim, LucideIcons.circle, Animal.doni, emoji: '⚾'),
    Sport('kriket', 'Kriket', SportCategory.tim, LucideIcons.slash, Animal.doni, emoji: '🏏'),
    Sport('dodgeball', 'Dodgeball', SportCategory.tim, LucideIcons.circle, Animal.doni, emoji: '🔴'),
    // Petualangan
    Sport('hiking', 'Hiking', SportCategory.petualangan, LucideIcons.mountain, Animal.gugun, emoji: '🥾'),
    Sport('paralayang', 'Paralayang', SportCategory.petualangan, LucideIcons.wind, Animal.gugun, emoji: '🪂'),
    Sport('panjat', 'Panjat Tebing', SportCategory.petualangan, LucideIcons.mountainSnow, Animal.momo, emoji: '🧗'),
    Sport('bouldering', 'Bouldering', SportCategory.petualangan, LucideIcons.hand, Animal.momo, emoji: '🧗'),
    // Roda
    Sport('sepeda', 'Sepeda', SportCategory.roda, LucideIcons.bike, Animal.rubi, emoji: '🚴'),
    Sport('mtb', 'Sepeda Gunung', SportCategory.roda, LucideIcons.bike, Animal.rubi, emoji: '🚵'),
    Sport('skate', 'Skateboard', SportCategory.roda, LucideIcons.gauge, Animal.rubi, emoji: '🛹'),
    Sport('sepatu_roda', 'Sepatu Roda', SportCategory.roda, LucideIcons.gauge, Animal.rubi, emoji: '🛼'),
    Sport('motorsport', 'Motorsport', SportCategory.roda, LucideIcons.car, Animal.rubi, emoji: '🏍️'),
    Sport('gokart', 'Gokart', SportCategory.roda, LucideIcons.car, Animal.rubi, emoji: '🏎️'),
    // Kebugaran
    Sport('fitness', 'Fitness', SportCategory.kebugaran, LucideIcons.dumbbell, Animal.gembul, emoji: '🏋️'),
    Sport('crossfit', 'CrossFit', SportCategory.kebugaran, LucideIcons.dumbbell, Animal.gembul, emoji: '🏋️'),
    Sport('kalistenik', 'Kalistenik', SportCategory.kebugaran, LucideIcons.personStanding, Animal.gembul, emoji: '🤸'),
    Sport('yoga', 'Yoga', SportCategory.kebugaran, LucideIcons.flower2, Animal.kura, emoji: '🧘'),
    Sport('pilates', 'Pilates', SportCategory.kebugaran, LucideIcons.activity, Animal.kura, emoji: '🧘'),
    Sport('catur', 'Catur', SportCategory.kebugaran, LucideIcons.crown, Animal.kura, emoji: '♟️'),
    Sport('senam', 'Senam', SportCategory.kebugaran, LucideIcons.music, Animal.flami, emoji: '💃'),
    Sport('dansa', 'Dansa', SportCategory.kebugaran, LucideIcons.music, Animal.flami, emoji: '💃'),
    Sport('zumba', 'Zumba', SportCategory.kebugaran, LucideIcons.music, Animal.flami, emoji: '💃'),
    // Bela diri
    Sport('bela_diri', 'Bela Diri', SportCategory.belaDiri, LucideIcons.swords, Animal.tara, emoji: '🥋'),
    Sport('tinju', 'Tinju', SportCategory.belaDiri, LucideIcons.handFist, Animal.tara, emoji: '🥊'),
    Sport('muay_thai', 'Muay Thai', SportCategory.belaDiri, LucideIcons.handFist, Animal.tara, emoji: '🥊'),
    Sport('silat', 'Pencak Silat', SportCategory.belaDiri, LucideIcons.swords, Animal.tara, emoji: '🥋'),
    Sport('anggar', 'Anggar', SportCategory.belaDiri, LucideIcons.swords, Animal.tara, emoji: '🤺'),
    Sport('taekwondo', 'Taekwondo', SportCategory.belaDiri, LucideIcons.swords, Animal.tara, emoji: '🥋'),
    // Presisi
    Sport('golf', 'Golf', SportCategory.presisi, LucideIcons.flag, Animal.eko, emoji: '⛳'),
    Sport('panahan', 'Panahan', SportCategory.presisi, LucideIcons.bowArrow, Animal.eko, emoji: '🏹'),
    Sport('darts', 'Darts', SportCategory.presisi, LucideIcons.target, Animal.eko, emoji: '🎯'),
    Sport('biliar', 'Biliar', SportCategory.presisi, LucideIcons.circle, Animal.eko, emoji: '🎱'),
    Sport('bowling', 'Bowling', SportCategory.presisi, LucideIcons.circleDot, Animal.eko, emoji: '🎳'),
  ];

  static final Map<String, Sport> _byId = {for (final s in all) s.id: s};

  static Sport byId(String id) => _byId[id] ?? all.first;

  static Sport get badminton => byId('badminton');
  static Sport get padel => byId('padel');
  static Sport get futsal => byId('futsal');
  static Sport get lari => byId('lari');
  static Sport get renang => byId('renang');
  static Sport get sepeda => byId('sepeda');
}
