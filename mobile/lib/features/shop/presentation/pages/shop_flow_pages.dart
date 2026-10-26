part of 'misc_pages.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.variant});
  final String? variant;
  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (variant) {
      'notFound' => (
        'Halaman nggak ketemu',
        'Tautan ini tidak tersedia. Buka beranda untuk melanjutkan.',
      ),
      'server' => (
        'Layanan belum tersedia',
        'Kembali ke beranda dan coba fitur lain. Koneksi layanan belum aktif di versi demo.',
      ),
      'deleted' => (
        'Mabar tidak tersedia',
        'Cari sesi mabar lainnya. Hubungi host untuk status sesi dan pengembalian dana.',
      ),
      'sync' => (
        'Sinkronisasi belum selesai',
        'Periksa izin kesehatan di Perangkat Terhubung, lalu coba sinkron lagi.',
      ),
      _ => (
        'Koneksi terputus',
        'Periksa data atau Wi-Fi. Kembali ke halaman sebelumnya untuk mencoba lagi.',
      ),
    };
    return KPage(
      header: const KHeader(''),
      bottom: KButton('KEMBALI KE BERANDA', onTap: () => context.go(R.feed)),
      children: [
        const Center(
          child: MascotBody(
            animal: Animal.ciko,
            stage: Stage.pemula,
            size: 170,
          ),
        ),
        Text(title, style: AppText.h1()),
        Text(body, style: AppText.body()),
        if (variant == 'deleted')
          KButton.secondary('CARI MABAR', onTap: () => context.push(R.explore)),
        if (variant == 'sync')
          KButton.secondary(
            'BUKA PERANGKAT TERHUBUNG',
            onTap: () => context.push(R.devices),
          ),
        if (context.canPop())
          KButton.secondary(
            'COBA HALAMAN SEBELUMNYA',
            onTap: () => context.pop(),
          ),
      ],
    );
  }
}

typedef _Product = ({
  String id,
  String name,
  int price,
  String category,
  String description,
  ShopIcon icon,
  bool available,
});
const _products = <_Product>[
  (
    id: 'es_batu',
    name: 'Es Batu Pelindung',
    price: 200,
    category: 'Pelindung',
    description:
        'Melindungi satu hari terlewat. Maksimal sesuai kapasitas profil.',
    icon: ShopIcon.esBatu,
    available: true,
  ),
  (
    id: 'bingkai_emas',
    name: 'Bingkai Emas',
    price: 300,
    category: 'Bingkai',
    description: 'Lingkaran emas pada avatar profil.',
    icon: ShopIcon.bingkaiEmas,
    available: true,
  ),
  (
    id: 'stiker_hewan',
    name: 'Stiker Hewan',
    price: 150,
    category: 'Stiker',
    description: 'Koleksi stiker hewan di profil. Pilihan stiker chat saat ini masih contoh.',
    icon: ShopIcon.stikerHewan,
    available: true,
  ),
  (
    id: 'pelangi',
    name: 'Rute Pelangi',
    price: 400,
    category: 'Rute',
    description:
        'Tampilan rute pelangi belum tersedia. Permata tidak akan dikurangi.',
    icon: ShopIcon.pelangi,
    available: false,
  ),
  (
    id: 'boost_xp',
    name: 'Boost XP 2x',
    price: 250,
    category: 'Bonus XP',
    description: 'Pengganda XP belum tersedia. Permata tidak akan dikurangi.',
    icon: ShopIcon.boostPetir,
    available: false,
  ),
];

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _category = 'Semua';
  Future<void> _detail(_Product product) async {
    final me = context.read<MeCubit>();
    final purchased = await showKSheet<bool>(
      context,
      (ctx) => BlocBuilder<MeCubit, UserProfile>(
        bloc: me,
        builder: (ctx, p) {
          final owned = product.id != 'es_batu' && p.owned.contains(product.id);
          final full = product.id == 'es_batu' && p.freezes >= p.maxFreezes;
          final enough = p.gems >= product.price;
          return KSheet(
            children: [
              Text(product.name, style: AppText.title()),
              Text(product.description, style: AppText.body()),
              Text(
                'Harga: 💎 ${product.price} · Saldo: ${p.gems}',
                style: AppText.bodySm(),
              ),
              if (!product.available) KBanner.info('Belum tersedia'),
              if (!enough)
                KBanner.tip(
                  'Kumpulkan Permata dari XP aktivitas. Pembelian dengan uang belum tersedia.',
                ),
              KButton(
                owned
                    ? 'SUDAH DIMILIKI'
                    : full
                    ? 'ES BATU PENUH'
                    : 'BELI · 💎 ${product.price}',
                onTap: product.available && !owned && !full && enough
                    ? () {
                        if (me.buy(
                          product.id,
                          product.price,
                          consumable: product.id == 'es_batu',
                        )) {
                          Navigator.pop(ctx, true);
                        }
                      }
                    : null,
              ),
              KButton.secondary('TUTUP', onTap: () => Navigator.pop(ctx)),
            ],
          );
        },
      ),
    );
    if (purchased == true && mounted) {
      toast(context, '${product.name} berhasil dibeli');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final products = _products
        .where(
          (p) =>
              p.id != 'es_batu' &&
              (_category == 'Semua' || p.category == _category),
        )
        .toList();
    return KPage(
      header: const KHeader('Toko Klubby'),
      children: [
        KCard(
          color: AppColors.purpleL,
          border: AppColors.purpleM,
          child: Row(
            children: [
              Image.asset(ShopIcon.permata.asset, width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CountUp(
                          value: p.gems,
                          format: Fmt.group,
                          style: AppText.custom(24, c: AppColors.purpleD),
                        ),
                        Text(
                          'Permata',
                          style: AppText.custom(18, c: AppColors.purpleD),
                        ),
                      ],
                    ),
                    Text('Dapat dari XP aktivitas', style: AppText.bodySm()),
                  ],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in [
              'Semua',
              'Pelindung',
              'Bingkai',
              'Stiker',
              'Rute',
              'Bonus XP',
            ])
              KChip(
                category,
                selected: category == _category,
                onTap: () => setState(() => _category = category),
              ),
          ],
        ),
        if (_category == 'Semua' || _category == 'Pelindung')
          KCard(
            color: AppColors.blueL,
            border: AppColors.blue,
            onTap: () => _detail(_products.first),
            child: Row(
              children: [
                Floaty(
                  child: Image.asset(
                    ShopIcon.esBatu.asset,
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Es Batu', style: AppText.cardTitle()),
                      Text(
                        'Lindungi satu hari terlewat. Punya ${p.freezes}/${p.maxFreezes}.',
                        style: AppText.bodySm(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                KMiniButton('💎 200', onTap: () => _detail(_products.first)),
              ],
            ),
          ),
        for (var row = 0; row < products.length; row += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  Expanded(
                    child: row + col >= products.length
                        ? const SizedBox.shrink()
                        : _tile(products[row + col], row + col, p),
                  ),
                ],
              ],
            ),
          ),
        Center(
          child: Text(
            'Permata didapat dari olahraga. Pembelian dengan uang belum tersedia.',
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
        ),
      ],
    );
  }

  Widget _tile(_Product product, int index, UserProfile p) => StaggerIn(
    key: ValueKey(product.id),
    index: index,
    child: KCard(
      padding: const EdgeInsets.all(12),
      border: p.owned.contains(product.id) ? AppColors.primary : null,
      onTap: () => _detail(product),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.purpleL,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              product.icon.asset,
              height: 88,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            textAlign: TextAlign.center,
            style: AppText.custom(15),
          ),
          Text(
            !product.available ? 'Belum tersedia' : product.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(),
          ),
          const SizedBox(height: 8),
          if (p.owned.contains(product.id))
            const KPill(
              'DIMILIKI',
              bg: AppColors.primaryL,
              fg: AppColors.primaryD,
              icon: LucideIcons.check,
            )
          else
            KMiniButton(
              product.available ? '💎 ${product.price}' : 'DETAIL',
              onTap: () => _detail(product),
            ),
        ],
      ),
    ),
  );
}

class VenuePage extends StatefulWidget {
  const VenuePage({super.key, this.id});
  final String? id;
  @override
  State<VenuePage> createState() => _VenuePageState();
}

class _VenuePageState extends State<VenuePage> {
  String _slot = '08.00';
  int _court = 1;
  var _date = DateTime.now();
  String get _dateKey => '${_date.year}-${_date.month}-${_date.day}';
  @override
  Widget build(BuildContext context) {
    final venue = Venues.byId(widget.id);
    final me = context.read<MeCubit>();
    final p = context.watch<MeCubit>().state;
    final key = 'booking_${venue.id}_$_dateKey';
    final booking = '$_court|$_slot';
    final booked = p.text(key).split(',').contains(booking);
    final sessions = context
        .watch<SessionsCubit>()
        .state
        .sessions
        .values
        .where((s) => s.venue == venue.name)
        .toList();
    return KPage(
      header: KHeader(venue.name),
      bottom: KButton(
        booked
            ? 'DIPESAN DI DEMO ✓'
            : 'SIMULASI PESAN · ${Fmt.rp(venue.pricePerHour)}',
        onTap: booked
            ? null
            : () async {
                final yes = await showConfirmSheet(
                  context,
                  title: 'Simulasikan pesanan?',
                  body:
                      '${venue.name}\n${Fmt.dayDate(_date)} · $_slot\nLapangan $_court · ${Fmt.rp(venue.pricePerHour)} / jam\nIni pesanan demo di perangkat. Tidak ada pembayaran atau reservasi nyata.',
                  confirm: 'SIMPAN PESANAN DEMO',
                  hue: Hue.primary,
                );
                if (!yes || !context.mounted) return;
                final all =
                    me.state
                        .text(key)
                        .split(',')
                        .where((v) => v.isNotEmpty)
                        .toSet()
                      ..add(booking);
                me.setSetting(key, all.join(','));
                toast(context, 'Pesanan demo tersimpan');
              },
      ),
      children: [
        SizedBox(
          height: 150,
          child: ColoredBox(
            color: AppColors.green,
            child: CustomPaint(painter: _CourtPainter(), size: Size.infinite),
          ),
        ),
        Text(venue.name, style: AppText.h2()),
        Text(venue.area, style: AppText.bodySm()),
        KBanner.info(
          'Daftar venue dan harga adalah contoh. Pemesanan langsung ke pengelola belum terhubung.',
        ),
        KField(
          text: '${_date.day} ${Fmt.monthsLong[_date.month - 1]} ${_date.year}',
          icon: LucideIcons.calendar,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (date != null && mounted) setState(() => _date = date);
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final court in [1, 2, 3])
              KChip(
                'Lapangan $court',
                selected: _court == court,
                onTap: () => setState(() => _court = court),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in ['07.00', '08.00', '09.00', '19.00', '20.00'])
              KChip(
                slot,
                selected: _slot == slot,
                onTap: () => setState(() => _slot = slot),
              ),
          ],
        ),
        const SectionTitle('Mabar di sini'),
        if (sessions.isEmpty)
          Text('Belum ada sesi contoh di venue ini.', style: AppText.bodySm()),
        for (final s in sessions)
          KRow(
            title: s.title,
            subtitle: '${s.when} · ${Fmt.rp(s.fee)}',
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => context.push(R.session(s.id)),
          ),
      ],
    );
  }
}
