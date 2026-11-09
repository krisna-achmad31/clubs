import '../../../core/widgets/area_picker.dart';
import '../../club/domain/entities/club.dart';
import '../../club/domain/repositories/club_repository.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/league.dart';
import '../domain/repositories/league_repository.dart';

/// Authored season data for one league club. Names, members and area of the
/// user's own club always come from [ClubRepository], so both stay in sync.
class _Season {
  const _Season({
    required this.clubBase,
    required this.myBase,
    required this.teammates,
    required this.area,
    required this.national,
  });

  final ClubScore clubBase;
  final MyContribution myBase;
  final List<Contributor> teammates;
  final List<Standing> area;
  final List<Standing> national;
}

class LeagueRepositoryImpl implements LeagueRepository {
  LeagueRepositoryImpl(this._clubs);

  final ClubRepository _clubs;

  /// Seasons run one calendar month; this one ends at the end of the month.
  static int get _daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(now.year, now.month + 1, 1).difference(today).inDays;
  }

  static const _seasons = {
    'smash': _Season(
      // Every other member's season so far; the user's share is added live.
      clubBase: ClubScore(verifiedHours: 306, attendance: 150, streakDays: 131),
      // 6 verified hours, 2 mabar and 2 manual logs before this demo install.
      myBase: MyContribution(
        verifiedMinutes: 360,
        attendance: 2,
        manualIgnored: 2,
      ),
      teammates: [
        Contributor('Rian', '🐼', 640),
        Contributor('Dinda', '🐰', 295),
        Contributor('Sari', '🦊', 210),
      ],
      area: [
        Standing(
          rank: 1,
          name: 'Shuttle Squad Tebet',
          emoji: '🦅',
          members: 64,
          points: 8420,
        ),
        Standing(
          rank: 2,
          name: 'PB Garuda Muda',
          emoji: '🐉',
          members: 120,
          points: 8105,
        ),
        Standing(
          rank: 3,
          name: 'Rajawali BC',
          emoji: '⚡',
          members: 48,
          points: 7880,
        ),
        Standing(
          rank: 4,
          name: 'Kok Terbang',
          emoji: '🪶',
          members: 37,
          points: 7010,
        ),
        Standing(
          rank: 5,
          name: 'PB Cilandak Juara',
          emoji: '🏆',
          members: 55,
          points: 6740,
        ),
        Standing(
          rank: 6,
          name: 'Smash Kemang',
          emoji: '💥',
          members: 42,
          points: 6415,
        ),
        Standing(
          rank: 7,
          name: 'PB Pancoran Jaya',
          emoji: '🦁',
          members: 71,
          points: 6120,
        ),
        Standing(
          rank: 8,
          name: 'Netizen Badminton',
          emoji: '📱',
          members: 29,
          points: 5880,
        ),
        Standing(
          rank: 9,
          name: 'PB Kebayoran Muda',
          emoji: '🌱',
          members: 63,
          points: 5610,
        ),
        Standing(
          rank: 10,
          name: 'Shuttle Senopati',
          emoji: '🚀',
          members: 34,
          points: 5340,
        ),
        Standing(
          rank: 11,
          name: 'PB Mampang',
          emoji: '🐺',
          members: 58,
          points: 5025,
        ),
        Standing(
          rank: 12,
          name: 'Rally Jagakarsa',
          emoji: '🔥',
          members: 40,
          points: 4790,
        ),
        Standing(
          rank: 13,
          name: 'PB Tunas Setiabudi',
          emoji: '🌿',
          members: 46,
          points: 4460,
        ),
        Standing(
          rank: 14,
          name: 'Drop Shot Club',
          emoji: '🎯',
          members: 27,
          points: 4180,
        ),
        Standing(
          rank: 15,
          name: 'PB Pasar Minggu',
          emoji: '🐝',
          members: 52,
          points: 3920,
        ),
        Standing(
          rank: 16,
          name: 'Ganda Campur Cipete',
          emoji: '🤝',
          members: 24,
          points: 3610,
        ),
        Standing(
          rank: 17,
          name: 'PB Pesanggrahan',
          emoji: '🐢',
          members: 39,
          points: 3240,
        ),
        Standing(
          rank: 18,
          name: 'Kok Melayang',
          emoji: '🎈',
          members: 22,
          points: 2870,
        ),
        Standing(
          rank: 19,
          name: 'Bulu Tangkis Gandaria',
          emoji: '🐧',
          members: 31,
          points: 2410,
        ),
      ],
      national: [
        Standing(
          rank: 1,
          name: 'PB Djarum Kids Kudus',
          emoji: '🦅',
          members: 312,
          points: 21480,
        ),
        Standing(
          rank: 2,
          name: 'Smash Bandung',
          emoji: '🐯',
          members: 188,
          points: 19920,
        ),
        Standing(
          rank: 3,
          name: 'Surabaya Shuttlers',
          emoji: '🦈',
          members: 240,
          points: 19100,
        ),
        Standing(
          rank: 127,
          name: 'PB Elang Medan',
          emoji: '🦉',
          members: 58,
          points: 7695,
        ),
        Standing(
          rank: 128,
          name: 'Shuttle Makassar',
          emoji: '🌊',
          members: 44,
          points: 7590,
        ),
      ],
    ),
  };

  @override
  Future<Division?> division({
    required bool national,
    required String sportId,
  }) async {
    final Club? club = (await _clubs.myClubs())
        .where((c) => c.sportId == sportId && c.division != null)
        .firstOrNull;
    final season = club == null ? null : _seasons[club.id];
    if (club == null || season == null) return null;
    final city = Areas.all.where((a) => a.name == club.area).firstOrNull?.city;
    final mine = Standing(
      rank: 0,
      name: club.name,
      emoji: club.emoji,
      members: club.members,
      points: 0,
      mine: true,
      clubId: club.id,
    );
    if (national) {
      return Division(
        label: 'Divisi Nasional',
        sportId: sportId,
        daysLeft: _daysLeft,
        promoteTop: 10,
        prize: 'Hadiah Top 10 nasional: voucher lapangan + merchandise Klubby',
        clubCount: 1240,
        club: mine,
        clubArea: club.area,
        clubBase: season.clubBase,
        rivals: season.national,
        teammates: season.teammates,
        myBase: season.myBase,
      );
    }
    return Division(
      label: 'Divisi ${club.division}',
      sportId: sportId,
      daysLeft: _daysLeft,
      promoteTop: 3,
      relegateBottom: 3,
      prize: 'Hadiah Top 3: jersey klub + 2 jam lapangan gratis · didukung Mitra Sponsor',
      clubCount: season.area.length + 1,
      city: city ?? club.area,
      clubArea: club.area,
      club: mine,
      clubBase: season.clubBase,
      rivals: season.area,
      teammates: season.teammates,
      myBase: season.myBase,
    );
  }

  @override
  Future<Segment> segment(String id) async => const Segment(
    name: 'Tanjakan Senayan',
    sportId: 'lari',
    km: 1.1,
    climb: 24,
    crown: ('Raka', '3:41'),
    legend: ('Dinda', '22x/90hr'),
    efforts: [
      SegmentEffort(1, 'Raka', '🐰', '3:41', club: true, following: true),
      SegmentEffort(2, 'Rian', '🐼', '3:55'),
      SegmentEffort(3, 'Dinda', '🐥', '4:02', following: true),
    ],
  );
}
