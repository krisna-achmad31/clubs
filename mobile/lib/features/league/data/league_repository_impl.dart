import '../../../core/backend/dev_api.dart';
import '../../../core/widgets/area_picker.dart';
import '../../club/domain/entities/club.dart';
import '../../club/domain/repositories/club_repository.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/league.dart';
import '../domain/repositories/league_repository.dart';

/// League standings synced with Supabase via [DevApi.leagueStandings].
class LeagueRepositoryImpl implements LeagueRepository {
  LeagueRepositoryImpl(this._clubs, [this._api]);

  final ClubRepository _clubs;
  final DevApi? _api;

  // Hardcoded demo seasons & segments disabled — data now comes from DevApi.
  // static const _seasons = {...};

  static int get _daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(now.year, now.month + 1, 1).difference(today).inDays;
  }

  @override
  Future<Division?> division({
    required bool national,
    required String sportId,
  }) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return null;
    final myClubs = await _clubs.myClubs();
    final Club? club = myClubs.where((c) => c.sportId == sportId).firstOrNull;
    if (club == null) return null;

    try {
      final data = await api.leagueStandings(club.id);
      final rawList =
          (data[national ? 'national' : 'area'] as List? ?? const []).cast<Map>();
      final rawTeam = (data['teammates'] as List? ?? const []).cast<Map>();

      final rivals = <Standing>[
        for (final r in rawList)
          if (r['id'] != club.id)
            Standing(
              rank: (r['rank'] as num).toInt(),
              name: r['name'] as String,
              emoji: r['emoji'] as String? ?? '🏆',
              members: (r['members'] as num?)?.toInt() ?? 1,
              points: (r['points'] as num?)?.toInt() ?? 0,
              clubId: r['id'] as String?,
            ),
      ];

      final teammates = <Contributor>[
        for (final t in rawTeam)
          Contributor(
            t['name'] as String? ?? 'Anggota',
            '🏸',
            (t['points'] as num?)?.toInt() ?? 0,
          ),
      ];

      final myClubRow = rawList.where((r) => r['id'] == club.id).firstOrNull;
      final clubPoints = (myClubRow?['points'] as num?)?.toInt() ?? 0;

      final String? baseCity = national
          ? null
          : Areas.find(club.area)?.city ??
              (club.area.contains(',') ? club.area.split(',').last.trim() : club.area);

      return Division(
        label: national ? 'Nasional' : 'Divisi 1',
        sportId: sportId,
        daysLeft: _daysLeft,
        promoteTop: national ? 0 : 2,
        relegateBottom: national ? 0 : 2,
        prize: national ? 'Trofi Juara Nasional' : 'Badge Divisi & Bonus XP',
        clubCount: rawList.isEmpty ? 1 : rawList.length,
        city: national ? null : baseCity,
        clubArea: club.area,
        club: Standing(
          rank: (myClubRow?['rank'] as num?)?.toInt() ?? 1,
          name: club.name,
          emoji: club.emoji,
          members: club.members,
          points: clubPoints,
          mine: true,
          clubId: club.id,
        ),
        clubBase: const ClubScore(attendance: 0, streakDays: 0),
        rivals: rivals,
        teammates: teammates,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<Segment> segment(String id) async {
    return Segment(
      name: id,
      sportId: 'lari',
      km: 0,
      climb: 0,
      crown: const ('-', '-'),
      legend: const ('-', '-'),
      efforts: const [],
    );
  }
}
