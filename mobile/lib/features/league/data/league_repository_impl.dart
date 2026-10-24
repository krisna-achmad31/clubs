import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/league.dart';
import '../domain/repositories/league_repository.dart';

class LeagueRepositoryImpl implements LeagueRepository {
  static const _area = Division(
    label: 'Divisi 1',
    sportId: 'badminton',
    daysLeft: 3,
    promoteTop: 3,
    prize: 'Hadiah Top 3: jersey klub + 2 jam lapangan gratis · didukung Mitra Sponsor',
    clubCount: 20,
    standings: [
      Standing(rank: 1, name: 'Shuttle Squad Tebet', emoji: '🦅', members: 64, points: 8420),
      Standing(rank: 2, name: 'PB Garuda Muda', emoji: '🐉', members: 120, points: 8105),
      Standing(rank: 3, name: 'Rajawali BC', emoji: '⚡', members: 48, points: 7880),
      Standing(rank: 4, name: 'PB Smash Ceria', emoji: '🏸', members: 96, points: 7640, mine: true),
      Standing(rank: 5, name: 'Kok Terbang', emoji: '🪶', members: 37, points: 7010),
    ],
    score: ClubScore(verifiedHours: 312, attendance: 152, streakDays: 144),
    contributors: [Contributor(1, 'Rian', '🐼', 640), Contributor(2, 'Kamu', '🐥', 310, me: true), Contributor(3, 'Dinda', '🐰', 295)],
    myWeekPoints: 320,
    myWeekNote: '2 mabar hadir · 6 jam verified · streak 14',
    ignoredManual: 2,
  );

  static const _national = Division(
    label: 'Divisi Nasional',
    sportId: 'badminton',
    daysLeft: 3,
    promoteTop: 10,
    prize: 'Hadiah Top 10 nasional: voucher lapangan + merchandise Klubby',
    clubCount: 1240,
    standings: [
      Standing(rank: 1, name: 'PB Djarum Kids Kudus', emoji: '🦅', members: 312, points: 21480),
      Standing(rank: 2, name: 'Smash Bandung', emoji: '🐯', members: 188, points: 19920),
      Standing(rank: 3, name: 'Surabaya Shuttlers', emoji: '🦈', members: 240, points: 19100),
      Standing(rank: 128, name: 'PB Smash Ceria', emoji: '🏸', members: 96, points: 7640, mine: true),
    ],
    score: ClubScore(verifiedHours: 312, attendance: 152, streakDays: 144),
    contributors: [Contributor(1, 'Rian', '🐼', 640), Contributor(2, 'Kamu', '🐥', 310, me: true), Contributor(3, 'Dinda', '🐰', 295)],
    myWeekPoints: 320,
    myWeekNote: '2 mabar hadir · 6 jam verified · streak 14',
    ignoredManual: 2,
  );

  @override
  Future<Division> division({required bool national}) async => national ? _national : _area;

  @override
  Future<Segment> segment(String id) async => const Segment(
        name: 'Tanjakan Senayan',
        sportId: 'lari',
        km: 1.1,
        climb: 24,
        crown: ('Raka', '3:41'),
        legend: ('Dinda', '22x/90hr'),
        efforts: [
          SegmentEffort(1, 'Raka', '🐰', '3:41'),
          SegmentEffort(2, 'Rian', '🐼', '3:55'),
          SegmentEffort(3, 'Dinda', '🐥', '4:02'),
          SegmentEffort(7, 'Kamu', '🐥', '4:12', me: true, pr: true),
        ],
      );
}
