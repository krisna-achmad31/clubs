import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/core/services/contacts_service.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/club/domain/entities/club.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/club/presentation/pages/club_pages.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/app_harness.dart';

/// B5 Undang anggota: contacts, manual add, link, and every entry point.
void main() {
  AppHarness.install();

  Club smash() =>
      sl<ClubsCubit>().state.mine.firstWhere((c) => c.id == 'smash');

  Future<void> openInvite(WidgetTester tester) async {
    await AppHarness.mount(tester, R.club('smash'));
    await AppHarness.tapText(tester, 'Anggota');
    await AppHarness.tapText(tester, 'UNDANG ANGGOTA');
    expect(find.byType(InviteMembersPage), findsOneWidget);
  }

  test('phone numbers in any Indonesian format compare equal', () {
    for (final raw in ['+62 812-3456-0001', '6281234560001', '81234560001']) {
      expect(normalizePhone(raw), '081234560001', reason: raw);
    }
    expect(waNumber('0812 3456 0001'), '6281234560001');
  });

  testWidgets('contacts split into Klubby users (TAMBAH) and others (WA)', (
    tester,
  ) async {
    await openInvite(tester);
    final before = smash().members;
    await AppHarness.tapText(tester, 'BUKA KONTAK');
    expect(find.text('SUDAH PAKAI KLUBBY · 2'), findsOneWidget);
    expect(find.text('BELUM PAKAI KLUBBY · 1'), findsOneWidget);
    expect(find.text('Raka Badminton'), findsOneWidget);
    expect(find.text('@rakap'), findsOneWidget);
    // Add a Klubby user straight into the club.
    await tester.tap(find.text('TAMBAH').hitTestable().first);
    await AppHarness.settle(tester);
    expect(smash().members, before + 1);
    expect(smash().addedMembers, hasLength(1));
    expect(find.text('ANGGOTA ✓'), findsOneWidget);
    // Invite someone not on Klubby over WhatsApp.
    await AppHarness.tapText(tester, 'UNDANG VIA WA');
    expect(find.text('DIUNDANG ✓'), findsOneWidget);
    // Search narrows both lists.
    await tester.enterText(
      find.widgetWithText(TextField, 'Cari nama atau nomor di kontak'),
      'ibu',
    );
    await AppHarness.settle(tester);
    expect(find.text('SUDAH PAKAI KLUBBY · 0'), findsOneWidget);
    expect(find.text('Ibu Sari'), findsOneWidget);
    AppHarness.healthy(tester, 'contacts');
    // The added person shows up in the club's member list.
    await AppHarness.back(tester);
    expect(find.text(smash().addedMembers.first), findsOneWidget);
    await AppHarness.unmount(tester);
  });

  testWidgets('manual add: username, unknown number, unknown username', (
    tester,
  ) async {
    await openInvite(tester);
    final field = find.widgetWithText(TextField, 'Nomor HP atau @username');
    await tester.enterText(field, '@sisca');
    await AppHarness.tapText(tester, 'CARI');
    expect(find.text('Sisca Lestari'), findsOneWidget);
    await tester.tap(find.text('TAMBAH').hitTestable().first);
    await AppHarness.settle(tester);
    expect(smash().addedMembers, contains('Sisca Lestari'));
    await tester.enterText(field, '0899 1234 5678');
    await AppHarness.tapText(tester, 'CARI');
    expect(find.text('Belum pakai Klubby'), findsOneWidget);
    await AppHarness.tapText(tester, 'UNDANG VIA WA');
    expect(find.text('DIUNDANG ✓'), findsOneWidget);
    await tester.enterText(field, '@entahsiapa');
    await AppHarness.tapText(tester, 'CARI');
    expect(find.textContaining('belum terdaftar'), findsOneWidget);
    AppHarness.healthy(tester, 'manual');
    await AppHarness.unmount(tester);
  });

  testWidgets('contacts permission denied, then blocked', (tester) async {
    AppHarness.contacts.access = ContactsAccess.denied;
    await openInvite(tester);
    await AppHarness.tapText(tester, 'BUKA KONTAK');
    expect(find.text('Akses kontak belum diizinkan.'), findsOneWidget);
    AppHarness.contacts.access = ContactsAccess.blocked;
    await AppHarness.tapText(tester, 'COBA LAGI');
    await AppHarness.tapText(tester, 'BUKA PENGATURAN');
    expect(AppHarness.contacts.settingsOpened, 1);
    AppHarness.contacts.access = ContactsAccess.granted;
    await AppHarness.tapText(tester, 'BUKA KONTAK');
    expect(find.text('SUDAH PAKAI KLUBBY · 2'), findsOneWidget);
    AppHarness.healthy(tester, 'permission');
    await AppHarness.unmount(tester);
  });

  testWidgets('club menu opens the invite page; link can be copied', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.club('smash'));
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await AppHarness.settle(tester);
    await AppHarness.tapText(tester, 'Undang anggota');
    expect(find.byType(InviteMembersPage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(LucideIcons.copy),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byIcon(LucideIcons.copy));
    await AppHarness.settle(tester);
    expect(find.text('Tautan klub disalin'), findsOneWidget);
    AppHarness.healthy(tester, 'menu entry');
    await AppHarness.unmount(tester);
  });

  testWidgets('non-admin members invite over WA instead of adding', (
    tester,
  ) async {
    // Padel Pagi: I'm a member, not the admin.
    await AppHarness.mount(tester, R.invite('padelpagi'));
    await AppHarness.tapText(tester, 'BUKA KONTAK');
    expect(find.text('TAMBAH'), findsNothing);
    expect(find.text('UNDANG'), findsNWidgets(2));
    AppHarness.healthy(tester, 'non-admin');
    await AppHarness.unmount(tester);
  });

  testWidgets('payout validation is visible inside the sheet', (tester) async {
    await AppHarness.mount(tester, R.newClub);
    await AppHarness.tapText(tester, 'TAMBAH REKENING');
    final inSheet = find.descendant(
      of: find.byType(KSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(inSheet.at(0), '12345');
    await tester.enterText(inSheet.at(1), 'Uji');
    final sheetList = find
        .descendant(of: find.byType(KSheet), matching: find.byType(Scrollable))
        .first;
    await AppHarness.tapText(tester, 'SIMPAN', scrollable: sheetList);
    // Still open, and the reason is shown inside the sheet itself.
    expect(find.byType(KSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KSheet),
        matching: find.textContaining('harus 8–16 digit (sekarang 5)'),
      ),
      findsOneWidget,
    );
    await tester.enterText(inSheet.at(0), '1234567890');
    await AppHarness.settle(tester);
    expect(find.textContaining('harus 8–16 digit'), findsNothing);
    await AppHarness.tapText(tester, 'SIMPAN', scrollable: sheetList);
    expect(find.byType(KSheet), findsNothing);
    AppHarness.healthy(tester, 'payout validation');
    await AppHarness.unmount(tester);
  });

  testWidgets('toasts render above an open sheet', (tester) async {
    await AppHarness.mount(tester, R.club('smash'));
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await AppHarness.settle(tester);
    // Show a toast while the menu sheet is still open.
    toast(tester.element(find.byType(KSheet)), 'Halo dari atas');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Halo dari atas').hitTestable(), findsNothing);
    final toastRect = tester.getRect(find.text('Halo dari atas'));
    final sheetRect = tester.getRect(find.byType(KSheet));
    expect(toastRect.bottom, lessThan(sheetRect.top), reason: 'not covered');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Halo dari atas'), findsNothing);
    await AppHarness.unmount(tester);
  });

  testWidgets('Buat Klub: "Anggota awal" join when the club is created', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.clubs);
    await AppHarness.tapText(tester, 'BUAT KLUB');
    await tester.enterText(find.byType(TextField).first, 'PB Anggota Awal');
    await AppHarness.tapText(tester, 'TAMBAH ANGGOTA');
    AppHarness.sheetWithinHalf(tester, 'pick members');
    final sheetField = find.descendant(
      of: find.byType(KSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(sheetField, '@sisca');
    await AppHarness.tapText(tester, 'CARI');
    await AppHarness.tapText(tester, 'CARI DARI KONTAK');
    // @sisca plus the two contacts that use Klubby (Dinda, Raka).
    for (final name in ['Sisca Lestari', 'Dinda Putri', 'Raka Pratama']) {
      await AppHarness.tapText(
        tester,
        name,
        scrollable: find
            .descendant(
              of: find.byType(KSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await AppHarness.tapText(
      tester,
      'PILIH 3 ORANG',
      scrollable: find
          .descendant(
            of: find.byType(KSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('ANGGOTA AWAL · 3'), findsOneWidget);
    await AppHarness.tapText(tester, 'TAMBAH REKENING');
    final fields = find.descendant(
      of: find.byType(KSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '1234567890');
    await tester.enterText(fields.at(1), 'Uji Coba');
    await AppHarness.tapText(tester, 'SIMPAN');
    await AppHarness.tapText(tester, 'BUAT KLUB');
    final club = sl<ClubsCubit>().state.mine.firstWhere(
      (c) => c.name == 'PB Anggota Awal',
    );
    expect(club.addedMembers.toSet(), {
      'Sisca Lestari',
      'Dinda Putri',
      'Raka Pratama',
    });
    expect(club.members, 4);
    expect(find.byType(InviteMembersPage), findsOneWidget);
    AppHarness.healthy(tester, 'anggota awal');
    await AppHarness.unmount(tester);
  });
}
