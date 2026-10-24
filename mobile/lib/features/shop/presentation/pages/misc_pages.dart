import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';

/// N1 Error / offline states. [variant] picks one of the four designed cases.
class ErrorPage extends StatefulWidget {
  const ErrorPage({super.key, this.variant});

  final String? variant;

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage> {
  var _retrying = false;
  var _shake = 0;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _shake++;
    });
    toast(context, 'Masih belum nyambung, coba sebentar lagi ya');
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: KHeader('', leading: LucideIcons.x, onLeading: () => context.canPop() ? context.pop() : context.go(R.feed)),
      bottom: KButton('COBA LAGI', loading: _retrying, icon: LucideIcons.rotateCw, onTap: _retry),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Wobble(
            trigger: _shake,
            child: const MascotBody(animal: Animal.ciko, stage: Stage.pemula, size: 170),
          ),
        ),
        Center(child: Text('Tidak ada koneksi', style: AppText.h1())),
        Center(child: Text('Sinyal lagi ngumpet nih. Aktivitasmu aman tersimpan di HP, nanti otomatis tersinkron.', textAlign: TextAlign.center, style: AppText.body(AppColors.muted))),
        const SizedBox(height: 4),
        const FieldLabel('KASUS LAIN'),
        for (final (i, v) in _variants.indexed)
          StaggerIn(
            index: i,
            child: KCard(
              padding: const EdgeInsets.all(14),
              border: widget.variant == v.id ? v.hue.base : null,
              child: Row(children: [
                IconBox(v.icon, bg: v.hue.light, fg: v.hue.base, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v.title, style: AppText.custom(15)), Text(v.body, style: AppText.bodySm())])),
                if (v.action != null) ...[const SizedBox(width: 8), KMiniButton(v.action!, hue: v.hue, onTap: () => toast(context, '${v.action} …'))],
              ]),
            ),
          ),
      ],
    );
  }
}

typedef _Variant = ({String id, IconData icon, Hue hue, String title, String body, String? action});

const List<_Variant> _variants = [
  (id: 'record', icon: LucideIcons.wifiOff, hue: Hue.orange, title: 'Offline saat merekam', body: 'GPS tetap jalan. Rute diunggah begitu online.', action: null),
  (id: 'sync', icon: LucideIcons.cloudAlert, hue: Hue.red, title: 'Gagal sinkron', body: '1 aktivitas belum terkirim.', action: 'KIRIM ULANG'),
  (id: 'server', icon: LucideIcons.serverCrash, hue: Hue.purple, title: 'Server lagi sibuk', body: 'Kode KLB-503 · coba 1 menit lagi.', action: null),
  (id: 'deleted', icon: LucideIcons.calendarX, hue: Hue.blue, title: 'Mabar dihapus host', body: 'Uangmu otomatis kembali ke Saldo Klubby.', action: 'CARI MABAR'),
];

typedef _Item = ({String id, ShopIcon icon, String name, String desc, int price, String cat, Color bg});

const List<_Item> _items = [
  (id: 'bingkai_emas', icon: ShopIcon.bingkaiEmas, name: 'Bingkai Emas', desc: 'Foto profil berkilau', price: 300, cat: 'Bingkai', bg: AppColors.yellowL),
  (id: 'stiker_hewan', icon: ShopIcon.stikerHewan, name: 'Stiker Hewan', desc: 'Buat kudoz & chat', price: 150, cat: 'Stiker', bg: AppColors.purpleL),
  (id: 'pelangi', icon: ShopIcon.pelangi, name: 'Rute Pelangi', desc: 'Warna rute di peta', price: 400, cat: 'Bingkai', bg: AppColors.blueL),
  (id: 'boost_xp', icon: ShopIcon.boostPetir, name: 'Boost XP 2x', desc: '24 jam · sekali pakai', price: 250, cat: 'Pelindung', bg: AppColors.orangeL),
];

/// O1 Toko Permata.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  var _cat = 'Semua';

  void _buy(String id, int price, String name, {bool consumable = false}) {
    final me = context.read<MeCubit>();
    if (me.state.owned.contains(id)) return toast(context, '$name sudah kamu pakai');
    if (id == 'es_batu' && me.state.freezes >= me.state.maxFreezes) return toast(context, 'Es Batu penuh (${me.state.maxFreezes}/${me.state.maxFreezes})');
    if (!me.buy(id, price, consumable: consumable)) return toast(context, 'Permata belum cukup 💎');
    toast(context, '$name berhasil dibeli! 🎉');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final items = _items.where((i) => _cat == 'Semua' || i.cat == _cat).toList();
    return KPage(
      header: const KHeader('Toko'),
      children: [
        KCard(
          color: AppColors.blueL,
          border: AppColors.blueM,
          child: Row(children: [
            Image.asset(ShopIcon.permata.asset, width: 48, height: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [CountUp(value: p.gems, format: Fmt.group, style: AppText.custom(24, c: AppColors.blueD)), Text(' Permata', style: AppText.custom(18, c: AppColors.blueD))]),
                Text('Dapat dari streak, liga & tantangan', style: AppText.bodySm()),
              ]),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            for (final c in const ['Semua', 'Pelindung', 'Bingkai', 'Stiker']) ...[
              KChip(c, selected: _cat == c, onTap: () => setState(() => _cat = c)),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        if (_cat == 'Semua' || _cat == 'Pelindung')
          KCard(
            color: AppColors.blueL,
            border: AppColors.blue,
            child: Row(children: [
              Floaty(child: Image.asset(ShopIcon.esBatu.asset, width: 64, height: 64)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Es Batu', style: AppText.cardTitle()),
                  Text('Bekukan streak 1 hari saat absen. Punya ${p.freezes}/${p.maxFreezes}.', style: AppText.bodySm()),
                ]),
              ),
              const SizedBox(width: 8),
              KMiniButton('💎 200', hue: Hue.blue, onTap: () => _buy('es_batu', 200, 'Es Batu', consumable: true)),
            ]),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .78,
          children: [
            for (final (i, it) in items.indexed)
              StaggerIn(
                index: i,
                child: KCard(
                  padding: const EdgeInsets.all(12),
                  border: p.owned.contains(it.id) ? AppColors.primary : null,
                  child: Column(children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: it.bg, borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(it.icon.asset, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(it.name, style: AppText.custom(15)),
                    Text(it.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(AppColors.muted)),
                    const SizedBox(height: 8),
                    p.owned.contains(it.id)
                        ? const KPill('DIPAKAI', bg: AppColors.primaryL, fg: AppColors.primaryD, icon: LucideIcons.check)
                        : KMiniButton('💎 ${it.price}', hue: Hue.white, textColor: AppColors.blue, onTap: () => _buy(it.id, it.price, it.name, consumable: it.id == 'boost_xp')),
                  ]),
                ),
              ),
          ],
        ),
        Center(child: Text('Permata tidak bisa dibeli dengan uang — murni hasil olahraga 💪', textAlign: TextAlign.center, style: AppText.caption())),
      ],
    );
  }
}

/// O3 Venue partner.
class VenuePage extends StatefulWidget {
  const VenuePage({super.key});

  @override
  State<VenuePage> createState() => _VenuePageState();
}

class _VenuePageState extends State<VenuePage> {
  var _slot = 1;
  static const _slots = [('07.00', true), ('08.00', true), ('09.00', true), ('19.00', false), ('20.00', true)];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return KPage(
      padding: EdgeInsets.zero,
      bottom: KButton('PESAN LAPANGAN · ${Fmt.rp(64000)}', onTap: () => toast(context, 'Lapangan 3 · ${_slots[_slot].$1} dipesan 🎉')),
      children: [
        Stack(children: [
          Container(
            height: 170 + top,
            color: AppColors.green,
            child: CustomPaint(painter: _CourtPainter(), size: Size.infinite),
          ),
          Positioned(top: top + 8, left: 12, child: KIconButton(LucideIcons.arrowLeft, color: AppColors.white, onTap: () => context.pop())),
          Positioned(
            left: 20,
            bottom: -1,
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: chunkyBorder(AppColors.line, bottom: 4)),
              child: Text('GS', style: AppText.custom(22, c: AppColors.green)),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GOR Senayan Badminton', style: AppText.h2()),
                  Text('2,1 km · ⭐ 4,8 (312 ulasan)', style: AppText.bodySm()),
                ]),
              ),
              const KPill('PARTNER', bg: AppColors.primaryL, fg: AppColors.primaryD, icon: LucideIcons.badgeCheck),
            ]),
            const KBanner(emoji: '🎁', title: 'Promo member Klubby', text: 'Diskon 20% tiap Senin–Kamis sebelum jam 16.00', bg: AppColors.orangeL, fg: AppColors.orangeD),
            Text('Slot hari ini', style: AppText.cardTitle()),
            Row(children: [
              for (final (i, (t, ok)) in _slots.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: ok ? 1 : .4,
                    child: KChoice(
                      selected: _slot == i,
                      onTap: ok ? () => setState(() => _slot = i) : null,
                      height: 48,
                      padding: EdgeInsets.zero,
                      child: Center(child: Text(t, style: AppText.custom(13, c: ok ? AppColors.ink : AppColors.faint))),
                    ),
                  ),
                ),
              ],
            ]),
            KCard(
              child: Row(children: [
                const IconBox(LucideIcons.layoutGrid, bg: AppColors.greenL, fg: AppColors.green),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lapangan 3', style: AppText.cardTitle()), Text('Karpet vinyl · 1 jam', style: AppText.bodySm())])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.rp(80000), style: AppText.custom(12, c: AppColors.faint).copyWith(decoration: TextDecoration.lineThrough)),
                  Text(Fmt.rp(64000), style: AppText.custom(17, c: AppColors.primary)),
                ]),
              ]),
            ),
            SectionTitle('Mabar di sini', action: 'SEMUA', onAction: () => context.push(R.explore)),
            for (final (id, t, sub, slots) in const [
              ('rabu-malam', 'Smash Rabu Malam', 'Rab, 19.00 · Rp35.000', '8/12'),
              ('sabtu-pagi', 'Mabar Pemula Sabtu', 'Sab, 08.00 · Rp30.000', '5/8'),
            ])
              KCard(
                onTap: () => context.push(R.session(id)),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const IconBox(LucideIcons.users, bg: AppColors.blueL, fg: AppColors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.custom(15)), Text('$sub · $slots', style: AppText.bodySm())])),
                  KMiniButton('IKUT', hue: Hue.primary, onTap: () => context.push(R.session(id))),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final dark = Paint()..color = AppColors.greenD.withValues(alpha: .35);
    final w = size.width / 2 - 30;
    for (final x in [20.0, size.width / 2 + 10]) {
      final r = Rect.fromLTWH(x, 24, w, size.height - 48);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), dark);
      canvas.drawRect(r, line);
      canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), line);
      canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), line..strokeWidth = 2);
      line.strokeWidth = 3;
    }
  }

  @override
  bool shouldRepaint(_CourtPainter old) => false;
}
