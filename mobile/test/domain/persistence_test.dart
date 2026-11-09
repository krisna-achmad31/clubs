import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/club/data/club_repository_impl.dart';
import 'package:klubby/features/club/domain/entities/club.dart';
import 'package:klubby/features/feed/data/feed_repository_impl.dart';
import 'package:klubby/features/feed/domain/entities/feed_post.dart';
import 'package:klubby/features/session/data/session_repository_impl.dart';
import 'package:klubby/features/session/domain/entities/mabar_session.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clubs, chat and kas survive a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ClubRepositoryImpl(prefs);
    await repo.join('hiu');
    await repo.send('smash', 'halo dari tes');
    await repo.addKas(
      'smash',
      const KasEntry(title: 'Iuran', sub: 'tes', amount: 5000, kind: 'iuran'),
    );
    final made = await repo.create(
      name: 'Klub Tes',
      sportId: 'lari',
      area: 'Senayan',
      privacy: ClubPrivacy.publik,
    );
    await Future<void>.delayed(Duration.zero);

    final restarted = ClubRepositoryImpl(prefs);
    final mine = (await restarted.myClubs()).map((c) => c.id);
    expect(mine, containsAll(['hiu', made.id]));
    expect((await restarted.chat('smash')).last.text, 'halo dari tes');
    expect((await restarted.kas('smash')).balance, 1245000);

    await restarted.resetForNewAccount();
    final fresh = ClubRepositoryImpl(prefs);
    expect((await fresh.myClubs()).map((c) => c.id), ['padelpagi']);
  });

  test('sessions and tickets survive a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = SessionsCubit(SessionRepositoryImpl(prefs));
    await cubit.load();
    final s = await cubit.create(const SessionDraft(title: 'Mabar Tes'));
    expect(cubit.startPayment(s.id, const []), isTrue);
    await Future<void>.delayed(Duration.zero);

    final restarted = SessionsCubit(SessionRepositoryImpl(prefs));
    await restarted.load();
    expect(restarted.state[s.id]?.title, 'Mabar Tes');
    expect(restarted.state.rsvp(s.id).status, RsvpStatus.pendingPayment);

    await restarted.resetForNewAccount();
    final fresh = SessionsCubit(SessionRepositoryImpl(prefs));
    await fresh.load();
    expect(fresh.state[s.id], isNull);
    expect(fresh.state.rsvps, isEmpty);
  });

  test('feed reactions and comments survive a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = FeedRepositoryImpl(prefs: prefs);
    final post = (await repo.feed(publik: true)).first;
    await repo.react(post.id, '🔥');
    await repo.comment(
      post.id,
      const Comment(
        author: 'Kamu',
        emoji: '🐥',
        avatarBg: Color(0xFFFFFFFF),
        text: 'mantap',
        mine: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final again = await FeedRepositoryImpl(prefs: prefs).byId(post.id);
    expect(again.comments.last.text, 'mantap');
    expect(again.reactions.any((r) => r.emoji == '🔥' && r.mine), isTrue);
  });
}
