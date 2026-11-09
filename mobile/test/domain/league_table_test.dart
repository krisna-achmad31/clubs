import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/club/data/club_repository_impl.dart';
import 'package:klubby/features/league/data/league_repository_impl.dart';
import 'package:klubby/features/league/domain/entities/league.dart';

void main() {
  late LeagueRepositoryImpl repo;
  setUp(() => repo = LeagueRepositoryImpl(ClubRepositoryImpl()));

  // Demo history (6 h, 2 mabar) plus the seed's 13-day streak.
  const demo = MyContribution(
    verifiedMinutes: 360,
    attendance: 2,
    streakDays: 13,
  );

  test('area board follows the club: name, members and city', () async {
    final d = (await repo.division(national: false, sportId: 'badminton'))!;
    final club = await ClubRepositoryImpl().byId('smash');
    expect(d.city, 'Jakarta Selatan');
    expect(d.areaCode, 'JAKSEL');
    expect(d.clubCount, 20);
    final t = d.table(d.myBase + const MyContribution(streakDays: 13));
    expect(t.mine.name, club.name);
    expect(t.mine.members, club.members);
    expect(t.mine.rank, 4);
    expect(t.mine.points, 7640);
    expect(t.standings, hasLength(20));
    expect(
      [for (final s in t.standings) s.rank],
      [for (var i = 1; i <= 20; i++) i],
    );
  });

  test('my verified activity raises club points and rank live', () async {
    final d = (await repo.division(national: false, sportId: 'badminton'))!;
    expect(d.table(demo).gapToNext, 241);
    // +5 verified hours (+50) and +8 mabar (+200) → 7890, overtakes #3.
    final t = d.table(
      demo + const MyContribution(verifiedMinutes: 300, attendance: 8),
    );
    expect(t.mine.points, 7890);
    expect(t.mine.rank, 3);
    expect(t.promoted, isTrue);
    expect(t.standings[3].name, 'Rajawali BC');
    expect(t.standings[3].rank, 4);
  });

  test('contributors include me, sorted by points', () async {
    final d = (await repo.division(national: false, sportId: 'badminton'))!;
    final t = d.table(demo);
    expect(
      [for (final c in t.contributors) c.name],
      ['Rian', 'Dinda', 'Sari', 'Kamu'],
    );
    expect(t.contributors.last.points, demo.points);
  });

  test('national keeps the gap and only shifts clubs I overtake', () async {
    final d = (await repo.division(national: true, sportId: 'badminton'))!;
    expect(d.national, isTrue);
    expect(d.relegateBottom, 0);
    final t = d.table(demo);
    expect([for (final s in t.standings) s.rank], [1, 2, 3, 127, 128, 129]);
    expect(t.mine.rank, 128);
    final up = d.table(demo + const MyContribution(attendance: 3));
    expect(up.mine.rank, 127);
    expect(up.standings[4].name, 'PB Elang Medan');
    expect(up.standings[4].rank, 128);
  });

  test('no board without a league club in the sport', () async {
    final clubs = ClubRepositoryImpl();
    final r = LeagueRepositoryImpl(clubs);
    expect(await r.division(national: false, sportId: 'padel'), isNull);
    await clubs.leave('smash');
    expect(await r.division(national: false, sportId: 'badminton'), isNull);
  });
}
