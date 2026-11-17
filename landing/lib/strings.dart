enum Lang { id, en }

class Feature {
  const Feature(this.tag, this.title, this.body);
  final String tag;
  final String title;
  final String body;
}

class S {
  const S(this.lang);
  final Lang lang;
  bool get _en => lang == Lang.en;
  String _(String id, String en) => _en ? en : id;

  List<String> get navLinks => _en
      ? ['Features', 'Mascots', 'How it works', 'For hosts']
      : ['Fitur', 'Maskot', 'Cara Kerja', 'Untuk Host'];
  String get navCta => _('UNDUH GRATIS', 'GET IT FREE');

  String get badge =>
      _('Main bareng, streak bareng', 'Play together, streak together');
  String get headline => _(
      'Olahraga jadi rutin karena kamu nggak main sendirian.',
      'Sport becomes a habit when you never play alone.');
  String get subhead => _(
      'Klubby mempertemukan kamu dengan klub badminton, padel, futsal, lari, dan 60+ olahraga lain di sekitarmu. RSVP mabar, bayar di app, jaga streak bareng teman satu klub.',
      'Klubby connects you with badminton, padel, futsal, running and 60+ other sports clubs near you. RSVP to games, pay in the app, and keep your streak alive with your clubmates.');
  String get ctaPrimary => _('MULAI GRATIS', 'START FREE');
  String get ctaSecondary => _('SAYA PUNYA KLUB', 'I RUN A CLUB');
  List<(String, String)> get stats => [
        ('66', _('olahraga', 'sports')),
        ('18', _('maskot hewan', 'animal mascots')),
        (_('0 ribet', 'Zero hassle'), _('catat iuran', 'fee tracking')),
      ];

  String get featKicker => _('KENAPA KLUBBY', 'WHY KLUBBY');
  String get featTitle => _(
      'Semua urusan mabar, dari ajak teman sampai lunas iuran.',
      'Every part of game day, from inviting friends to settling fees.');
  List<Feature> get features => [
        Feature(
          _('RSVP & bayar di app', 'RSVP & pay in the app'),
          _('Nggak ada lagi rekap manual di grup chat.',
              'No more manual tallies in the group chat.'),
          _('Host buka sesi, anggota RSVP dan bayar langsung. Slot penuh? Otomatis masuk waiting list dan naik sendiri kalau ada yang batal.',
              'Hosts open a session, members RSVP and pay on the spot. Session full? You join the waiting list and move up automatically when someone cancels.'),
        ),
        Feature(
          _('Streak yang dijaga bareng', 'Streaks you keep together'),
          _('Rajin olahraga karena satu klub saling nunggu.',
              'Show up, because your club is counting on you.'),
          _('Check-in lewat QR di lapangan, rekam aktivitas, atau goyang ajak main. Tiap sesi menambah streak dan poin liga klubmu.',
              'Check in with a QR code at the court, record an activity, or shake to invite friends. Every session grows your streak and your club\'s league points.'),
        ),
        Feature(
          _('Terverifikasi otomatis', 'Auto-verified'),
          _('Sinkron dengan jam pintar favoritmu.',
              'Syncs with your favorite smartwatch.'),
          _('Health Connect, Apple Health, dan Strava langsung tercatat. Aktivitas terverifikasi masuk papan peringkat, yang santai tetap dihitung.',
              'Health Connect, Apple Health and Strava log instantly. Verified activities hit the leaderboard, and casual ones still count.'),
        ),
      ];

  String get mascotTitle =>
      _('Satu olahraga, satu sahabat.', 'One sport, one buddy.');
  String get mascotBody => _(
      '18 maskot hewan menemani 66 olahraga. Makin konsisten kamu, makin keren mereka berevolusi: Pemula, Gesit, Turbo, Juara, sampai Legend.',
      '18 animal mascots across 66 sports. The more consistent you are, the cooler they evolve: Rookie, Agile, Turbo, Champion, all the way to Legend.');
  List<String> get animals => _en
      ? ['the otter', 'the penguin', 'the rabbit', 'the mountain goat', 'the fox', 'the corgi']
      : ['si Berang-berang', 'si Pinguin', 'si Kelinci', 'si Kambing Gunung', 'si Rubah', 'si Anjing Corgi'];
  List<String> get sports => _en
      ? ['🏊 Swim & dive', '🏄 Surf & paddle', '🏃 Running', '🥾 Outdoor & climb', '🚴 Wheels', '🥏 Throw & catch']
      : ['🏊 Renang & selam', '🏄 Selancar & perahu', '🏃 Lari', '🥾 Alam & ketinggian', '🚴 Roda', '🥏 Lempar & tangkap'];
  List<String> get levels => _en
      ? ['ROOKIE', 'AGILE', 'TURBO', 'CHAMPION', 'LEGEND', 'TURBO']
      : ['PEMULA', 'GESIT', 'TURBO', 'JUARA', 'LEGEND', 'TURBO'];

  String get stepsTitle => _('Mulai dalam 3 langkah', 'Get started in 3 steps');
  List<(String, String)> get steps => [
        (
          _('Pilih olahragamu', 'Pick your sport'),
          _('Badminton, padel, futsal, lari, renang, dan 60+ lainnya. Maskotmu langsung ikut.',
              'Badminton, padel, futsal, running, swimming and 60+ more. Your mascot comes along.')
        ),
        (
          _('Gabung atau buat klub', 'Join or start a club'),
          _('Cari klub di sekitar, atau undang teman lewat WhatsApp untuk klub barumu.',
              'Find clubs nearby, or invite friends on WhatsApp to your new club.')
        ),
        (
          _('RSVP, main, jaga streak', 'RSVP, play, keep the streak'),
          _('Datang, check-in, dan lihat klubmu naik liga tiap minggu.',
              'Show up, check in, and watch your club climb the league every week.')
        ),
      ];

  String get ctaTitle => _('Klubmu sudah nunggu di lapangan.',
      'Your club is waiting on the court.');
  String get ctaBody => _(
      'Gratis untuk pemain. Host klub bisa kelola sesi, iuran, dan anggota tanpa spreadsheet.',
      'Free for players. Club hosts manage sessions, fees and members without a spreadsheet.');
  String get appStoreTop => _('Unduh di', 'Download on the');
  String get playTop => _('TEMUKAN DI', 'GET IT ON');
  String get footer => _('© 2026 Klubby · Main bareng, streak bareng',
      '© 2026 Klubby · Play together, streak together');
}
