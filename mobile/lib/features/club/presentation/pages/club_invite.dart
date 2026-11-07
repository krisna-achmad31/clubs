part of 'club_pages.dart';

/// B5 Undang anggota: from contacts (Klubby users get TAMBAH, the rest an
/// invite over WhatsApp), by number/username, or via the club link.
/// [fresh] is the step right after creating the club.
class InviteMembersPage extends StatelessWidget {
  const InviteMembersPage({super.key, required this.id, this.fresh = false});

  final String id;
  final bool fresh;

  @override
  Widget build(BuildContext context) => _ClubLoader(
    id: id,
    builder: (context, club) => _InviteView(club: club, fresh: fresh),
  );
}

enum _ContactsStep { idle, loading, denied, blocked, ready, failed }

class _InviteView extends StatefulWidget {
  const _InviteView({required this.club, required this.fresh});

  final Club club;
  final bool fresh;

  @override
  State<_InviteView> createState() => _InviteViewState();
}

class _InviteViewState extends State<_InviteView> {
  final _manual = TextEditingController();
  final _invited = <String>{};
  var _query = '';
  var _step = _ContactsStep.idle;
  var _added = 0;

  /// Contacts that already use Klubby, with the matching account.
  var _onKlubby = <(PhoneContact, KlubbyUser)>[];
  var _others = <PhoneContact>[];

  /// Result of the manual search: a user, or a number to invite.
  KlubbyUser? _found;
  String? _inviteNumber;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  ContactsService get _contacts => sl<ContactsService>();

  Future<void> _loadContacts() async {
    setState(() => _step = _ContactsStep.loading);
    try {
      final access = await _contacts.request();
      if (!mounted) return;
      if (access != ContactsAccess.granted) {
        setState(
          () => _step = access == ContactsAccess.blocked
              ? _ContactsStep.blocked
              : _ContactsStep.denied,
        );
        return;
      }
      final clubs = context.read<ClubsCubit>();
      final book = await _contacts.all();
      final users = await clubs.findUsers([for (final c in book) ...c.phones]);
      final byPhone = {for (final u in users) u.phone: u};
      final on = <(PhoneContact, KlubbyUser)>[];
      final off = <PhoneContact>[];
      for (final c in book) {
        final user = c.phones
            .map((p) => byPhone[normalizePhone(p)])
            .nonNulls
            .firstOrNull;
        user == null ? off.add(c) : on.add((c, user));
      }
      if (!mounted) return;
      setState(() {
        _onKlubby = on;
        _others = off;
        _step = _ContactsStep.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _step = _ContactsStep.failed);
    }
  }

  Future<void> _add(KlubbyUser user) async {
    await context.read<ClubsCubit>().addMember(widget.club.id, user);
    if (!mounted) return;
    setState(() => _added++);
    toast(context, '${user.name} masuk ${widget.club.name} 🎉');
  }

  String get _message =>
      'Hai! Yuk gabung ${widget.club.name} di Klubby ${widget.club.sport.emoji}\n'
      'Kode klub: ${widget.club.code}\nhttps://klubby.id/k/${widget.club.code}';

  Future<void> _inviteWa(String key, {String? phone}) async {
    final text = Uri.encodeComponent(_message);
    final url = phone == null
        ? 'https://wa.me/?text=$text'
        : 'https://wa.me/${waNumber(phone)}?text=$text';
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    // No WhatsApp: fall back to the system share sheet.
    if (!opened) await SharePlus.instance.share(ShareParams(text: _message));
    if (mounted) setState(() => _invited.add(key));
  }

  Future<void> _searchManual() async {
    final raw = _manual.text.trim();
    if (raw.isEmpty) return;
    final users = await context.read<ClubsCubit>().findUsers([raw]);
    if (!mounted) return;
    final digits = normalizePhone(raw);
    final isNumber = !raw.startsWith('@') && digits.length >= 9;
    setState(() {
      _found = users.firstOrNull;
      _inviteNumber = _found == null && isNumber ? digits : null;
    });
    if (_found == null && !isNumber) {
      toast(
        context,
        'Username "${raw.replaceFirst('@', '')}" belum terdaftar. '
        'Coba nomor HP-nya untuk kirim undangan.',
      );
    }
  }

  bool _matches(String name, List<String> phones) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final d = q.replaceAll(RegExp(r'[^0-9]'), '');
    return name.toLowerCase().contains(q) ||
        (d.length >= 3 && phones.any((p) => normalizePhone(p).contains(d)));
  }

  Widget _userRow(String name, String sub, KlubbyUser user, bool member) =>
      KRow(
        title: name,
        subtitle: sub,
        icon: LucideIcons.badgeCheck,
        trailing: member
            ? const KTag(
                'ANGGOTA ✓',
                bg: AppColors.primaryL,
                fg: AppColors.primaryD,
              )
            : widget.club.admin
            ? KMiniButton('TAMBAH', onTap: () => _add(user))
            : KMiniButton(
                'UNDANG',
                hue: Hue.white,
                textColor: AppColors.primary,
                onTap: () => _inviteWa(user.username, phone: user.phone),
              ),
      );

  Widget _inviteRow(String key, String name, String sub, String? phone) => KRow(
    title: name,
    subtitle: sub,
    icon: LucideIcons.user,
    iconBg: AppColors.soft,
    iconFg: AppColors.muted,
    trailing: _invited.contains(key)
        ? const KTag('DIUNDANG ✓', bg: AppColors.soft, fg: AppColors.muted)
        : KMiniButton(
            'UNDANG VIA WA',
            hue: Hue.white,
            textColor: AppColors.primary,
            onTap: () => _inviteWa(key, phone: phone),
          ),
  );

  List<Widget> _contactSection() => switch (_step) {
    _ContactsStep.idle => [
      KCard(
        color: AppColors.primaryL,
        border: AppColors.primaryM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cari teman dari kontak', style: AppText.cardTitle()),
            const SizedBox(height: 4),
            Text(
              'Lihat siapa yang sudah pakai Klubby. Kontak hanya dibaca di HP-mu, tidak diunggah.',
              style: AppText.bodySm(),
            ),
            const SizedBox(height: 12),
            KButton(
              'BUKA KONTAK',
              icon: LucideIcons.contact,
              small: true,
              onTap: _loadContacts,
            ),
          ],
        ),
      ),
    ],
    _ContactsStep.loading => [const Center(child: CircularProgressIndicator())],
    _ContactsStep.denied => [
      KBanner.info('Akses kontak belum diizinkan.'),
      KButton.secondary('COBA LAGI', onTap: _loadContacts),
    ],
    _ContactsStep.blocked => [
      KBanner.error(
        'Akses kontak dimatikan. Izinkan kontak untuk Klubby di Pengaturan.',
      ),
      KButton.secondary(
        'BUKA PENGATURAN',
        onTap: () async {
          await _contacts.openSettings();
          if (mounted) setState(() => _step = _ContactsStep.idle);
        },
      ),
    ],
    _ContactsStep.failed => [
      KBanner.error('Kontak belum bisa dibaca. Coba lagi.'),
      KButton.secondary('COBA LAGI', onTap: _loadContacts),
    ],
    _ContactsStep.ready => _contactLists(),
  };

  List<Widget> _contactLists() {
    final members = widget.club.addedMembers.toSet();
    final on = _onKlubby.where((e) => _matches(e.$1.name, e.$1.phones));
    final off = _others.where((c) => _matches(c.name, c.phones)).toList();
    const cap = 100;
    return [
      KInput(
        hint: 'Cari nama atau nomor di kontak',
        icon: LucideIcons.search,
        onChanged: (v) => setState(() => _query = v),
      ),
      FieldLabel('SUDAH PAKAI KLUBBY · ${on.length}'),
      if (on.isEmpty)
        Text(
          'Belum ada kontakmu yang terdeteksi di Klubby.',
          style: AppText.bodySm(),
        ),
      for (final (c, u) in on)
        _userRow(c.name, '@${u.username}', u, members.contains(u.name)),
      FieldLabel('BELUM PAKAI KLUBBY · ${off.length}'),
      for (final c in off.take(cap))
        _inviteRow(c.phones.first, c.name, c.phones.first, c.phones.first),
      if (off.length > cap)
        Text(
          '${off.length - cap} kontak lain. Cari nama untuk mempersempit.',
          style: AppText.bodySm(),
        ),
      KBanner.info(
        'Pencocokan kontak masih demo: hanya nomor pengguna contoh '
        '(mis. 0812 3456 0001) yang terdeteksi sebagai pengguna Klubby.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final club =
        context
            .watch<ClubsCubit>()
            .state
            .mine
            .where((c) => c.id == widget.club.id)
            .firstOrNull ??
        widget.club;
    final found = _found;
    return KPage(
      header: KHeader(
        'Undang anggota',
        leading: widget.fresh ? LucideIcons.x : LucideIcons.arrowLeft,
      ),
      bottom: widget.fresh
          ? KButton(
              _added == 0 && _invited.isEmpty ? 'NANTI SAJA' : 'SELESAI',
              kind: _added == 0 && _invited.isEmpty
                  ? BtnKind.secondary
                  : BtnKind.primary,
              onTap: () => context.pop(),
            )
          : null,
      children: [
        if (widget.fresh)
          KBanner(
            icon: LucideIcons.partyPopper,
            bg: AppColors.primaryL,
            fg: AppColors.primaryD,
            iconColor: AppColors.primary,
            text:
                '${club.name} sudah jadi! Ajak teman main biar langsung rame.',
          ),
        Text(
          '${club.members} anggota${_added > 0 ? ' · +$_added baru' : ''}',
          style: AppText.bodySm(),
        ),
        const FieldLabel('TAMBAH MANUAL'),
        Row(
          children: [
            Expanded(
              child: KInput(
                controller: _manual,
                hint: 'Nomor HP atau @username',
                icon: LucideIcons.userPlus,
                onChanged: (_) => setState(() {
                  _found = null;
                  _inviteNumber = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            KMiniButton('CARI', onTap: _searchManual),
          ],
        ),
        if (found != null)
          _userRow(
            found.name,
            '@${found.username} · pengguna Klubby',
            found,
            club.addedMembers.contains(found.name),
          ),
        if (_inviteNumber case final n?)
          _inviteRow(n, n, 'Belum pakai Klubby', n),
        const FieldLabel('DARI KONTAK'),
        ..._contactSection(),
        const FieldLabel('ATAU BAGIKAN TAUTAN'),
        KCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kode ${club.code}', style: AppText.cardTitle()),
                    Text('klubby.id/k/${club.code}', style: AppText.bodySm()),
                  ],
                ),
              ),
              KIconButton(
                LucideIcons.copy,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: 'https://klubby.id/k/${club.code}'),
                  );
                  toast(context, 'Tautan klub disalin');
                },
              ),
              const SizedBox(width: 8),
              KIconButton(
                LucideIcons.share2,
                onTap: () =>
                    SharePlus.instance.share(ShareParams(text: _message)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Anggota awal" picker on Buat Klub: Klubby users found by number,
/// @username or the phone book. Returns the selection; they join on create.
class _PickMembersSheet extends StatefulWidget {
  const _PickMembersSheet({required this.initial});

  final List<KlubbyUser> initial;

  @override
  State<_PickMembersSheet> createState() => _PickMembersSheetState();
}

class _PickMembersSheetState extends State<_PickMembersSheet> {
  final _query = TextEditingController();
  late final _picked = [...widget.initial];
  var _shown = <KlubbyUser>[];
  String? _note;
  var _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _show(List<KlubbyUser> users, String empty) => setState(() {
    for (final u in users) {
      if (!_shown.contains(u)) _shown = [..._shown, u];
    }
    _note = users.isEmpty ? empty : null;
  });

  Future<void> _search() async {
    final raw = _query.text.trim();
    if (raw.isEmpty) return;
    final users = await context.read<ClubsCubit>().findUsers([raw]);
    if (mounted) {
      _show(
        users,
        '"$raw" belum pakai Klubby. Undang lewat WA setelah klub jadi.',
      );
    }
  }

  Future<void> _fromContacts() async {
    final contacts = sl<ContactsService>();
    final clubs = context.read<ClubsCubit>();
    setState(() => _loading = true);
    try {
      final access = await contacts.request();
      if (access != ContactsAccess.granted) {
        if (!mounted) return;
        setState(
          () => _note = access == ContactsAccess.blocked
              ? 'Akses kontak dimatikan. Izinkan di Pengaturan, atau cari pakai nomor.'
              : 'Akses kontak belum diizinkan.',
        );
        return;
      }
      final book = await contacts.all();
      final users = await clubs.findUsers([for (final c in book) ...c.phones]);
      if (mounted) {
        _show(
          users,
          'Belum ada kontakmu yang terdeteksi di Klubby (pencocokan masih demo).',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Kontak belum bisa dibaca.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => KSheet(
    children: [
      Text('Tambah anggota', style: AppText.title()),
      Text(
        'Pilih teman yang sudah pakai Klubby. Mereka langsung masuk saat klub dibuat.',
        style: AppText.bodySm(),
      ),
      Row(
        children: [
          Expanded(
            child: KInput(
              controller: _query,
              hint: 'Nomor HP atau @username',
              icon: LucideIcons.userPlus,
            ),
          ),
          const SizedBox(width: 8),
          KMiniButton('CARI', onTap: _search),
        ],
      ),
      KButton.secondary(
        'CARI DARI KONTAK',
        icon: LucideIcons.contact,
        onTap: _loading ? null : _fromContacts,
      ),
      if (_note case final n?) KBanner.info(n),
      for (final u in _shown)
        KRow(
          title: u.name,
          subtitle: '@${u.username}',
          icon: LucideIcons.badgeCheck,
          onTap: () => setState(
            () => _picked.contains(u) ? _picked.remove(u) : _picked.add(u),
          ),
          trailing: Icon(
            _picked.contains(u) ? LucideIcons.circleCheck : LucideIcons.circle,
            color: _picked.contains(u) ? AppColors.primary : AppColors.faint,
          ),
        ),
      KButton(
        _picked.isEmpty ? 'SELESAI' : 'PILIH ${_picked.length} ORANG',
        onTap: () => Navigator.pop(context, _picked),
      ),
    ],
  );
}
