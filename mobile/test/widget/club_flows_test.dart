import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/club/presentation/pages/club_pages.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:klubby/features/feed/presentation/pages/feed_pages.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';
import 'package:klubby/features/session/presentation/pages/session_pages.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/app_harness.dart';

/// Tap-through of every entry point on the Klub tab on the real router.
void main() {
  AppHarness.install();

  Future<void> openClub(WidgetTester tester, String name) async {
    await AppHarness.mount(tester, R.clubs);
    // The KLUBKU row; the name also appears on the "mabar kamu" cards above.
    await AppHarness.tapText(tester, name, last: true);
    expect(find.byType(ClubPage), findsOneWidget, reason: name);
  }

  Finder clubList() => find
      .descendant(of: find.byType(ClubPage), matching: find.byType(Scrollable))
      .last;

  testWidgets('Klub tab: every club row, mabar card, search and plus', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.clubs);
    expect(find.byType(ClubsPage), findsOneWidget);
    for (final club in sl<ClubsCubit>().state.mine) {
      await AppHarness.tapText(tester, club.name, last: true);
      expect(find.byType(ClubPage), findsOneWidget, reason: club.id);
      AppHarness.healthy(tester, 'open ${club.id}');
      await AppHarness.back(tester);
    }
    for (final (s, _) in sl<SessionsCubit>().state.mine.take(2)) {
      await AppHarness.tapText(tester, s.title);
      AppHarness.healthy(tester, 'my mabar ${s.id}');
      expect(find.byType(ClubsPage).hitTestable(), findsNothing);
      await AppHarness.back(tester);
    }
    await tester.tap(find.byIcon(LucideIcons.search).hitTestable().first);
    await AppHarness.settle(tester);
    expect(find.byType(ExplorePage), findsOneWidget);
    await AppHarness.back(tester);
    for (final label in ['CARI KLUB', 'BUAT KLUB']) {
      await AppHarness.tapText(tester, label);
      AppHarness.healthy(tester, label);
      expect(find.byType(ClubsPage).hitTestable(), findsNothing, reason: label);
      await AppHarness.back(tester);
    }
    await AppHarness.unmount(tester);
  });

  testWidgets('invite: accept joins, decline removes the card', (tester) async {
    await AppHarness.mount(tester, R.clubs);
    final invite = sl<ClubsCubit>().state.invites.first;
    await AppHarness.tapText(tester, 'TERIMA');
    expect(sl<ClubsCubit>().state.isMember(invite.club.id), isTrue);
    expect(sl<ClubsCubit>().state.invites, isEmpty);
    AppHarness.healthy(tester, 'accept invite');
    await AppHarness.unmount(tester);
  });

  testWidgets('club page: Jadwal sessions, Feed, Anggota and member sheet', (
    tester,
  ) async {
    await openClub(tester, 'PB Smash Ceria');
    final sessions = sl<SessionsCubit>().state.sessions.values
        .where((s) => s.clubId == 'smash')
        .toList();
    expect(sessions, isNotEmpty);
    for (final s in sessions) {
      await AppHarness.tapText(tester, s.title, scrollable: clubList());
      expect(find.byType(SessionPage), findsOneWidget, reason: s.id);
      AppHarness.healthy(tester, 'session ${s.id}');
      await AppHarness.back(tester);
    }
    await AppHarness.tapText(tester, 'BUAT MABAR', scrollable: clubList());
    AppHarness.healthy(tester, 'buat mabar');
    await AppHarness.back(tester);
    await AppHarness.tapText(tester, 'Feed');
    AppHarness.healthy(tester, 'club feed');
    await AppHarness.tapText(tester, 'Anggota');
    await AppHarness.tapText(
      tester,
      'LIHAT SEMUA ANGGOTA',
      scrollable: clubList(),
    );
    AppHarness.sheetWithinHalf(tester, 'member sheet');
    AppHarness.healthy(tester, 'member sheet');
    await AppHarness.unmount(tester);
  });

  testWidgets('club Feed tab lists club posts whichever Feed tab is active', (
    tester,
  ) async {
    // Dinda's swim post is club-only for Klub Hiu Jakarta.
    await tester.runAsync(
      () => sl<ClubsCubit>().join(
        sl<ClubsCubit>().state.nearby.firstWhere((c) => c.id == 'hiu'),
      ),
    );
    await tester.runAsync(() => sl<FeedCubit>().setPublik(true));
    await openClub(tester, 'Klub Hiu Jakarta');
    await AppHarness.tapText(tester, 'Feed');
    await AppHarness.settle(tester);
    await AppHarness.settle(tester);
    expect(
      find.text('Renang pagi di GOR Bulungan 🏊'),
      findsOneWidget,
      reason: 'club feed must not depend on the PUBLIK/KOMUNITAS toggle',
    );
    await AppHarness.tapText(tester, 'Renang pagi di GOR Bulungan 🏊');
    expect(find.byType(PostDetailPage), findsOneWidget);
    AppHarness.healthy(tester, 'club post');
    await AppHarness.unmount(tester);
  });

  testWidgets('club chat: text, empty send, sticker, announce, members', (
    tester,
  ) async {
    await openClub(tester, 'PB Smash Ceria');
    await tester.tap(find.byIcon(LucideIcons.messageCircle).hitTestable());
    await AppHarness.settle(tester);
    expect(find.byType(ClubChatPage), findsOneWidget);
    expect(
      sl<ClubsCubit>().state.mine.firstWhere((c) => c.id == 'smash').unread,
      0,
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await AppHarness.settle(tester);
    final before = find.byType(KSticker).evaluate().length;
    await tester.enterText(find.byType(TextField), 'Halo semua');
    await tester.tap(find.byIcon(LucideIcons.send));
    await AppHarness.settle(tester);
    expect(find.text('Halo semua'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.smile).hitTestable());
    await AppHarness.settle(tester);
    AppHarness.sheetWithinHalf(tester, 'sticker sheet');
    await tester.tap(find.text('👑 GG!').hitTestable());
    await AppHarness.settle(tester);
    await AppHarness.settle(tester);
    expect(find.byType(KSticker).evaluate().length, greaterThan(before));
    await tester.tap(find.byType(KToggle));
    await AppHarness.settle(tester);
    await tester.enterText(find.byType(TextField), 'Info penting');
    await tester.tap(find.byIcon(LucideIcons.send));
    await AppHarness.settle(tester);
    // Sent as an announcement: pinned to the top banner too.
    expect(find.textContaining('PENGUMUMAN · DISEMATKAN'), findsOneWidget);
    expect(find.text('Info penting'), findsWidgets);
    await tester.tap(find.byIcon(LucideIcons.users));
    await AppHarness.settle(tester);
    AppHarness.sheetWithinHalf(tester, 'chat members');
    AppHarness.healthy(tester, 'chat');
    await AppHarness.unmount(tester);
  });

  testWidgets('kas: expense, withdraw, CSV gate to Pro', (tester) async {
    await openClub(tester, 'PB Smash Ceria');
    await AppHarness.tapText(tester, 'Kas');
    // Kas is a tab: it stays inside the club page.
    expect(find.byType(KasPage), findsOneWidget);
    expect(find.byType(ClubPage), findsOneWidget);
    await AppHarness.tapText(tester, 'CATAT KELUAR', scrollable: clubList());
    AppHarness.sheetWithinHalf(tester, 'expense sheet');
    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pump();
    await AppHarness.tapText(tester, 'SIMPAN PENGELUARAN');
    expect(find.text(Fmt.rp(1240000 - 50000)), findsOneWidget);
    await AppHarness.tapText(tester, 'TARIK DANA DEMO', scrollable: clubList());
    await tester.enterText(find.byType(TextField).first, '100000');
    await tester.pump();
    await AppHarness.tapText(tester, 'KONFIRMASI SIMULASI');
    expect(find.text(Fmt.rp(1240000 - 150000)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(LucideIcons.download),
      -200,
      scrollable: clubList(),
    );
    await tester.tap(find.byIcon(LucideIcons.download));
    await AppHarness.settle(tester);
    expect(find.byType(ProPage), findsOneWidget);
    AppHarness.healthy(tester, 'kas');
    await AppHarness.unmount(tester);
  });

  testWidgets('club menu: copy, Pro trial, report, leave', (tester) async {
    await openClub(tester, 'PB Smash Ceria');
    Future<void> menu() async {
      await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
      await AppHarness.settle(tester);
      AppHarness.sheetWithinHalf(tester, 'club menu');
    }

    await menu();
    await AppHarness.tapText(tester, 'Salin kode');
    await menu();
    await AppHarness.tapText(tester, 'Klub Pro');
    expect(find.byType(ProPage), findsOneWidget);
    await AppHarness.tapText(tester, 'AKTIFKAN TRIAL DEMO');
    await AppHarness.tapText(tester, 'AKTIFKAN DEMO');
    expect(
      sl<ClubsCubit>().state.mine.firstWhere((c) => c.id == 'smash').pro,
      isTrue,
    );
    await AppHarness.back(tester);
    await menu();
    await AppHarness.tapText(tester, 'Catat laporan klub');
    await AppHarness.tapText(tester, 'Spam');
    await menu();
    await AppHarness.tapText(tester, 'Keluar klub');
    await AppHarness.tapText(tester, 'KELUAR KLUB');
    expect(sl<ClubsCubit>().state.isMember('smash'), isFalse);
    expect(find.byType(ClubsPage), findsOneWidget);
    AppHarness.healthy(tester, 'club menu');
    await AppHarness.unmount(tester);
  });

  testWidgets('non-member club: join, approval request, gated chat & kas', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.club('hiu'));
    expect(find.text('GABUNG KLUB'), findsOneWidget);
    // Club-only posts stay hidden from non-members.
    await AppHarness.tapText(tester, 'Feed');
    expect(find.textContaining('Feed klub khusus anggota'), findsOneWidget);
    expect(find.text('Renang pagi di GOR Bulungan 🏊'), findsNothing);
    await AppHarness.tapText(tester, 'Kas');
    expect(find.textContaining('Kas klub khusus anggota'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.messageCircle).hitTestable());
    await AppHarness.settle(tester);
    expect(find.text('Gabung klub dulu'), findsOneWidget);
    AppHarness.sheetWithinHalf(tester, 'join gate');
    await AppHarness.tapText(tester, 'GABUNG KLUB');
    expect(sl<ClubsCubit>().state.isMember('hiu'), isTrue);
    expect(find.byType(ClubChatPage), findsOneWidget);
    await AppHarness.back(tester);
    AppHarness.router.go(R.club('futsalfc'));
    await AppHarness.settle(tester);
    await AppHarness.tapText(tester, 'MINTA GABUNG');
    expect(sl<ClubsCubit>().state.pending, contains('futsalfc'));
    expect(find.text('MENUNGGU'), findsOneWidget);
    AppHarness.healthy(tester, 'non-member');
    await AppHarness.unmount(tester);
  });

  testWidgets('Jelajahi: every tab and every result opens', (tester) async {
    await AppHarness.mount(tester, R.explore);
    for (final club in {
      for (final c in [
        ...sl<ClubsCubit>().state.mine,
        ...sl<ClubsCubit>().state.nearby,
      ])
        c.id: c,
    }.values) {
      await AppHarness.tapText(tester, club.name);
      expect(find.byType(ClubPage), findsOneWidget, reason: club.id);
      AppHarness.healthy(tester, 'explore club ${club.id}');
      await AppHarness.back(tester);
    }
    await AppHarness.tapText(tester, 'GABUNG');
    AppHarness.healthy(tester, 'explore gabung');
    for (final tab in ['Mabar', 'Turnamen', 'Venue', 'Orang']) {
      await AppHarness.tapText(tester, tab);
      final rows = find.descendant(
        of: find.byType(ExplorePage),
        matching: find.byType(KRow),
      );
      // First row is the area picker; open the first real result.
      expect(rows.evaluate().length, greaterThan(1), reason: tab);
      await tester.ensureVisible(rows.at(1));
      await tester.pump(const Duration(milliseconds: 300));
      // The row sits inside a tappable card; tapping its centre is enough.
      await tester.tap(rows.at(1), warnIfMissed: false);
      await AppHarness.settle(tester);
      AppHarness.healthy(tester, 'explore $tab');
      if (find.byType(KSheet).evaluate().isNotEmpty) {
        AppHarness.sheetWithinHalf(tester, 'explore $tab');
        Navigator.of(tester.element(find.byType(KSheet))).pop();
        await AppHarness.settle(tester);
      } else {
        expect(
          find.byType(ExplorePage).hitTestable(),
          findsNothing,
          reason: tab,
        );
        await AppHarness.back(tester);
      }
    }
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await AppHarness.settle(tester);
    await AppHarness.tapText(tester, 'HAPUS FILTER');
    AppHarness.healthy(tester, 'explore filter');
    await AppHarness.unmount(tester);
  });

  testWidgets('Buat Klub: validation, payout sheet, then lands on the club', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.clubs);
    await AppHarness.tapText(tester, 'BUAT KLUB');
    await AppHarness.tapText(tester, 'BUAT KLUB');
    expect(find.text('Isi nama klub dulu ya'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField).first, 'PB Uji Coba');
    // Sport picker: alphabetical with a search field.
    await AppHarness.tapText(tester, 'Badminton');
    final names = [
      for (final e
          in find
              .descendant(of: find.byType(KSheet), matching: find.byType(KRow))
              .evaluate())
        (e.widget as KRow).title,
    ];
    expect(names, isNotEmpty);
    expect(
      names,
      [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(KSheet),
        matching: find.byType(TextField),
      ),
      'pad',
    );
    await AppHarness.settle(tester);
    await AppHarness.tapText(tester, 'Padel');
    expect(find.text('Padel'), findsOneWidget);
    await AppHarness.tapText(tester, 'BUAT KLUB');
    expect(find.text('Tambahkan rekening pencairan kas dulu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    // The payout sheet opens by itself.
    AppHarness.sheetWithinHalf(tester, 'payout sheet');
    await AppHarness.tapText(tester, 'Lainnya');
    final fields = find.descendant(
      of: find.byType(KSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Bank Jago');
    await tester.enterText(fields.at(1), '1234567890');
    await tester.enterText(fields.at(2), 'Uji Coba');
    await AppHarness.tapText(tester, 'SIMPAN');
    await AppHarness.tapText(tester, 'BUAT KLUB');
    final created = sl<ClubsCubit>().state.mine.firstWhere(
      (c) => c.name == 'PB Uji Coba',
    );
    expect(created.sportId, 'padel');
    expect(created.payout!.provider, 'Bank Jago');
    // The invite step opens on top of the new club; skipping lands on it.
    expect(find.byType(InviteMembersPage), findsOneWidget);
    expect(find.textContaining('PB Uji Coba sudah jadi'), findsOneWidget);
    await AppHarness.tapText(tester, 'NANTI SAJA');
    expect(
      find.byType(ClubPage),
      findsOneWidget,
      reason: 'after creating, the new club page should open',
    );
    AppHarness.healthy(tester, 'create club');
    await AppHarness.unmount(tester);
  });
}
