import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/backend/dev_api.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/widgets/widgets.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final _api = sl<DevApi>();
  List<ChallengeResult>? _items;
  bool _loading = false;
  bool _loadFailed = false;
  bool _saving = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final items = await _api.challenges();
      if (mounted) setState(() => _items = items);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setMembership(ChallengeResult challenge) async {
    if (_saving || _loading || _loadFailed) return;
    setState(() => _saving = true);
    try {
      await _api.setChallengeMembership(challenge.id, !challenge.joined);
      if (mounted) await _load();
    } on Object {
      if (mounted) toast(context, 'Gagal menyimpan keikutsertaan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _detail(ChallengeResult challenge) async {
    final change = await showKSheet<bool>(
      context,
      (ctx) => KSheet(
        maxHeightFactor: .75,
        children: [
          Text(challenge.title, style: AppText.title()),
          Text(challenge.description, style: AppText.body()),
          if (challenge.joined) _progress(challenge),
          if (challenge.completed)
            KBanner.ok('Tantangan selesai')
          else ...[
            if (challenge.joined)
              Text(
                'Keluar akan menghapus progres tantangan ini.',
                style: AppText.bodySm(),
              ),
            KButton(
              challenge.joined ? 'Keluar tantangan' : 'Gabung tantangan',
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ],
      ),
    );
    if (mounted && change == true) await _setMembership(challenge);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _saving;
    final items = _items ?? const <ChallengeResult>[];
    final visible = items.where(
      (challenge) => switch (_tab) {
        0 => challenge.joined && !challenge.completed,
        1 => challenge.kind == 'klub' && !challenge.completed,
        2 => challenge.kind == 'teman' && !challenge.completed,
        _ => challenge.completed,
      },
    );
    final explore = items.where((challenge) => !challenge.joined);
    return KLoadingOverlay(
      loading: busy,
      message: _saving ? 'Menyimpan pilihanmu…' : 'Memuat tantangan…',
      child: KPage(
        header: const KHeader('Tantangan'),
        stagger: false,
        onRefresh: busy ? null : _load,
        children: [
          if (_loadFailed && !_loading)
            KContentState(
              error: true,
              title: 'Tantangan belum bisa dimuat',
              message: 'Cek koneksi internet lalu coba lagi.',
              action: 'Coba lagi',
              onAction: _load,
            ),
          if (_items != null && !busy && !_loadFailed) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in [
                  'Diikuti',
                  'Klub',
                  'Teman',
                  'Selesai',
                ].indexed)
                  KChip(
                    label,
                    selected: _tab == i,
                    onTap: () => setState(() => _tab = i),
                  ),
              ],
            ),
            if (visible.isEmpty)
              KContentState(
                title: _tab == 3
                    ? 'Belum ada tantangan selesai.'
                    : 'Belum ada tantangan di sini.',
                message: _tab == 3
                    ? 'Selesaikan tantangan untuk melihat pencapaianmu.'
                    : 'Pilih tantangan dan mulai bergerak bareng.',
              ),
            for (final challenge in visible)
              _card(challenge, enabled: !busy && !_loadFailed),
            if (_tab == 0 && explore.isNotEmpty) ...[
              const SectionTitle('Jelajahi tantangan'),
              for (final challenge in explore)
                KRow(
                  title: challenge.title,
                  icon: LucideIcons.flag,
                  trailing: KMiniButton(
                    'GABUNG',
                    hue: Hue.primary,
                    onTap: busy || _loadFailed
                        ? null
                        : () => _setMembership(challenge),
                  ),
                  onTap: busy || _loadFailed ? null : () => _detail(challenge),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _card(ChallengeResult challenge, {required bool enabled}) {
    final sport = Sports.byId(challenge.sportId);
    return KCard(
      onTap: enabled ? () => _detail(challenge) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KRow(
            title: challenge.title,
            subtitle: switch (challenge.kind) {
              'klub' => 'Klub',
              'teman' => 'Teman',
              _ => 'Pribadi',
            },
            emoji: sport.emoji,
            iconBg: sport.hue.light,
            padding: const EdgeInsets.only(bottom: 12),
          ),
          if (challenge.joined)
            _progress(challenge)
          else
            KLink(
              'Lihat tantangan',
              onTap: enabled ? () => _detail(challenge) : null,
            ),
        ],
      ),
    );
  }

  Widget _progress(ChallengeResult challenge) {
    final hue = Sports.byId(challenge.sportId).hue;
    final amount = challenge.progress;
    final label = amount % 1 == 0
        ? amount.toInt().toString()
        : Fmt.dec(amount, 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KProgress(
          value: (amount / challenge.goal).clamp(0.0, 1.0),
          height: 12,
          color: hue.base,
        ),
        const SizedBox(height: 6),
        Text(
          '$label/${challenge.goal} ${challenge.unit}',
          style: AppText.custom(13, c: hue.dark),
        ),
      ],
    );
  }
}
