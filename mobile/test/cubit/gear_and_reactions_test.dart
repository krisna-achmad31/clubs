import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/feed/data/feed_repository_impl.dart';
import 'package:klubby/features/profile/data/gear_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/gear.dart';
import 'package:klubby/features/profile/presentation/cubit/gear_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GearCubit', () {
    late GearCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cubit = GearCubit(
        GearRepositoryImpl(await SharedPreferences.getInstance()),
      );
      await cubit.load();
    });

    test('new default gear replaces the old default for that sport', () {
      cubit.add(
        const Gear(
          id: 'n',
          name: 'Nike Pegasus',
          kind: GearKind.sepatu,
          sportId: 'lari',
          limitKm: 800,
          isDefault: true,
        ),
      );
      expect(cubit.defaultFor('lari')?.id, 'n');
      expect(
        cubit.active.where((g) => g.sportId == 'lari' && g.isDefault),
        hasLength(1),
      );
    });

    test('first gear for a new sport becomes its default', () {
      cubit.add(
        const Gear(
          id: 'p',
          name: 'Bullpadel Vertex',
          kind: GearKind.raket,
          sportId: 'padel',
        ),
      );
      expect(cubit.defaultFor('padel')?.id, 'p');
    });

    test('retired gear drops out of active and loses default', () {
      cubit.retire('g3');
      expect(cubit.active.any((g) => g.id == 'g3'), isFalse);
      expect(cubit.defaultFor('sepeda'), isNull);
    });

    test('gear survives a reload', () async {
      cubit.add(
        const Gear(
          id: 'x',
          name: 'Kacamata',
          kind: GearKind.lainnya,
          sportId: 'renang',
        ),
      );
      final again = GearCubit(
        GearRepositoryImpl(await SharedPreferences.getInstance()),
      );
      await again.load();
      expect(again.state.any((g) => g.id == 'x'), isTrue);
    });
  });

  group('Feed reactions', () {
    test(
      'a friend can add a reaction the post did not have, and undo it',
      () async {
        final repo = FeedRepositoryImpl();
        await repo.react('dinda-renang', '💪');
        var post = await repo.byId('dinda-renang');
        final added = post.reactions.firstWhere((r) => r.emoji == '💪');
        expect((added.count, added.mine), (1, true));

        await repo.react('dinda-renang', '💪');
        post = await repo.byId('dinda-renang');
        expect(post.reactions.any((r) => r.emoji == '💪'), isFalse);
      },
    );

    test('hidden posts leave the feed', () async {
      final repo = FeedRepositoryImpl();
      await repo.hide('dinda-renang');
      expect(
        (await repo.feed(publik: true)).any((p) => p.id == 'dinda-renang'),
        isFalse,
      );
    });
  });
}
