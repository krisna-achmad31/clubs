import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/backend/dev_api.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';
import '../cubit/clubs_cubit.dart';

enum _ExploreTab {
  club('Klub'),
  mabar('Mabar'),
  tournament('Turnamen'),
  venue('Venue'),
  people('Orang');

  const _ExploreTab(this.label);
  final String label;
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  static const _pageSize = 30;
  final _search = TextEditingController();
  final _api = sl<DevApi>();
  _ExploreTab _tab = _ExploreTab.club;
  String? _sport;
  late String _area = context.read<MeCubit>().state.area;
  GeoPoint? _areaCenter;
  GeoPoint? _gpsOrigin;
  Timer? _debounce;
  Future<List<ExploreResult>>? _results;
  String? _saving;
  int _offset = 0;

  bool get _peopleNeedsQuery =>
      _tab == _ExploreTab.people &&
      _search.text.trim().replaceFirst(RegExp(r'^@+'), '').length < 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    if (_peopleNeedsQuery) {
      _results = null;
      return;
    }
    final query = _search.text.trim();
    final term = query.toLowerCase();
    final savedArea = Areas.find(_area);
    final origin = _tab == _ExploreTab.club
        ? _gpsOrigin ??
              _areaCenter ??
              (savedArea == null
                  ? null
                  : GeoPoint(savedArea.lat, savedArea.lng))
        : null;
    _results = _api.explore(
      kind: _tab.name,
      query: query,
      sport: _tab == _ExploreTab.tournament ? null : _sport,
      area: _area.isEmpty ? null : _area,
      lat: origin == null ? null : double.parse(origin.lat.toStringAsFixed(4)),
      lon: origin == null ? null : double.parse(origin.lng.toStringAsFixed(4)),
      offset: _offset,
      matchingSports: [
        if (term.isNotEmpty)
          for (final sport in Sports.all)
            if (sport.name.toLowerCase().contains(term)) sport.id,
      ],
    );
  }

  void _reload({int offset = 0}) {
    _debounce?.cancel();
    setState(() {
      _offset = offset;
      _load();
    });
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    setState(() => _results = null);
    if (!_peopleNeedsQuery) {
      _debounce = Timer(const Duration(milliseconds: 300), _reload);
    }
  }

  Future<void> _mutate(ExploreResult result) async {
    if (_saving != null) return;
    final isClub = _tab == _ExploreTab.club;
    final follow = result.status != 'following';
    final me = context.read<MeCubit>();
    final clubs = context.read<ClubsCubit>();
    setState(() => _saving = result.id);
    try {
      if (isClub) {
        await _api.joinClub(result.id);
      } else {
        await _api.setUserFollow(result.id, follow);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = null);
        toast(
          context,
          apiFeedback(error, fallback: 'Perubahan gagal disimpan.'),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = null);
      _reload(offset: _offset);
      toast(
        context,
        isClub
            ? (result.status == 'persetujuan'
                  ? 'Permintaan bergabung dikirim.'
                  : 'Berhasil gabung klub.')
            : (follow ? 'Pengguna diikuti.' : 'Berhenti mengikuti pengguna.'),
      );
    }
    // Keep the Klub and Profil tabs in sync after the server accepts the change.
    try {
      if (isClub && !clubs.isClosed) await clubs.load();
      if (!isClub && !me.isClosed) await me.load();
    } on Object {
      // The directory has its own server reload and retry state.
    }
  }

  Future<void> _openSession(String id) async {
    if (_saving != null) return;
    final sessions = context.read<SessionsCubit>();
    setState(() => _saving = id);
    try {
      await sessions.ensureAvailable(id);
      if (mounted) unawaited(context.push(R.session(id)));
    } on Object catch (error) {
      if (mounted) {
        toast(context, apiFeedback(error, fallback: 'Mabar gagal dibuka.'));
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => KPage(
    header: const KHeader('Jelajahi'),
    stagger: false,
    onRefresh: () async {
      _reload();
      try {
        await _results;
      } on Object {
        // FutureBuilder renders the failure.
      }
    },
    children: [
      KRow(
        title: _area.isEmpty ? 'Pilih area' : _area,
        subtitle: _gpsOrigin != null
            ? 'Klub diurutkan dari lokasi sekarang'
            : (_areaCenter != null || Areas.find(_area) != null)
            ? 'Klub diurutkan dari pusat area'
            : 'Area membantu mengurutkan hasil',
        icon: LucideIcons.mapPin,
        onTap: () async {
          final area = await showAreaSelection(context, current: _area);
          if (area == null || !mounted) return;
          _area = area.label;
          _areaCenter = area.center;
          _gpsOrigin = area.origin;
          _reload();
        },
      ),
      KInput(
        controller: _search,
        hint: _tab == _ExploreTab.people
            ? 'Cari nama atau @username'
            : 'Cari nama, olahraga, atau lokasi',
        icon: LucideIcons.search,
        onChanged: _onQueryChanged,
      ),
      if (_tab != _ExploreTab.tournament)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KChip(
              'Semua olahraga',
              selected: _sport == null,
              onTap: () {
                _sport = null;
                _reload();
              },
            ),
            KChip(
              _sport == null
                  ? '${Sports.all.length} olahraga ▾'
                  : '${Sports.byId(_sport!).name} ▾',
              selected: _sport != null,
              onTap: () async {
                final sport = await showSportPicker(
                  context,
                  selectedId: _sport,
                );
                if (sport == null || !mounted) return;
                _sport = sport.id;
                _reload();
              },
            ),
          ],
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tab in _ExploreTab.values)
            KChip(
              tab.label,
              selected: _tab == tab,
              onTap: () {
                if (_tab == tab) return;
                _tab = tab;
                _reload();
              },
            ),
        ],
      ),
      if (_tab == _ExploreTab.tournament)
        KLink('Buat turnamen', onTap: () => context.push(R.tournamentNew)),
      if (_tab == _ExploreTab.venue)
        Text(
          'Venue dari jadwal Mabar yang bisa dilihat.',
          style: AppText.bodySm(),
        ),
      if (_peopleNeedsQuery)
        Text(
          'Ketik minimal 2 karakter untuk mencari akun.',
          style: AppText.bodySm(),
        )
      else
        FutureBuilder<List<ExploreResult>>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const KContentState(
                loading: true,
                title: 'Mencari teman bergerak',
                message: 'Sebentar, hasil Jelajahi sedang dimuat.',
              );
            }
            if (snapshot.hasError) {
              return KContentState(
                error: true,
                title: 'Jelajahi belum bisa dimuat',
                message: apiFeedback(
                  snapshot.error!,
                  fallback: 'Jelajahi gagal dimuat.',
                ),
                action: 'Coba lagi',
                onAction: _reload,
              );
            }
            final results = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (results.isEmpty)
                  KContentState(
                    title: 'Belum ada hasil',
                    message: _tab == _ExploreTab.tournament
                        ? 'Belum ada turnamen tersimpan di akunmu.'
                        : 'Belum ada hasil. Coba kata kunci atau olahraga lain.',
                  ),
                for (final entry in results.take(_pageSize))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _row(entry),
                  ),
                if (_offset > 0 || results.length > _pageSize)
                  Wrap(
                    spacing: 16,
                    children: [
                      if (_offset > 0)
                        KLink(
                          'Sebelumnya',
                          onTap: () => _reload(offset: _offset - _pageSize),
                        ),
                      if (results.length > _pageSize)
                        KLink(
                          'Selanjutnya',
                          onTap: () => _reload(offset: _offset + _pageSize),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
    ],
  );

  Widget _row(ExploreResult entry) {
    final sport = entry.sportId == null ? null : Sports.byId(entry.sportId!);
    final details = switch (_tab) {
      _ExploreTab.club => [
        sport?.name,
        entry.area,
        if (entry.distanceKm != null)
          '${Fmt.dec(entry.distanceKm!, 1)} km dari ${_gpsOrigin != null ? 'lokasi sekarang' : 'pusat area'}',
        '${entry.total} anggota',
        if ((entry.slots ?? 0) > 0) '${entry.slots} Mabar dalam 7 hari',
      ],
      _ExploreTab.mabar => [
        entry.subtitle,
        sport?.name,
        if (entry.startsAt case final start?) Fmt.dayDate(start),
        if (entry.fee != null) entry.fee == 0 ? 'Gratis' : Fmt.rp(entry.fee!),
        '${entry.total}/${entry.slots} peserta',
      ],
      _ExploreTab.tournament => [
        entry.status == 'finished' ? 'Selesai' : 'Berjalan',
        if (entry.startsAt case final updated?) Fmt.dayDate(updated),
      ],
      _ExploreTab.venue => [sport?.name, entry.subtitle],
      _ExploreTab.people => ['@${entry.subtitle}', sport?.name],
    };
    final onTap = switch (_tab) {
      _ExploreTab.club => () => context.push(R.club(entry.id)),
      _ExploreTab.mabar ||
      _ExploreTab.venue => () => _openSession(entry.sessionId!),
      _ => null,
    };
    final trailing = switch (_tab) {
      _ExploreTab.club when entry.status == 'active' => const KTag(
        'ANGGOTA',
        bg: AppColors.bg,
        fg: AppColors.faint,
        border: AppColors.line,
      ),
      _ExploreTab.club when entry.status == 'pending' => const KTag(
        'MENUNGGU',
        bg: AppColors.purpleL,
        fg: AppColors.purple,
      ),
      _ExploreTab.club || _ExploreTab.people => KMiniButton(
        _saving == entry.id
            ? 'MENYIMPAN…'
            : switch (entry.status) {
                'persetujuan' => 'MINTA',
                'publik' => 'GABUNG',
                'following' => 'Berhenti ikuti',
                _ => 'Ikuti',
              },
        onTap: _saving == null ? () => _mutate(entry) : null,
      ),
      _ => null,
    };
    return KCard(
      onTap: onTap,
      child: KRow(
        title: entry.title,
        subtitle: details.nonNulls
            .where((value) => value.isNotEmpty)
            .join(' · '),
        emoji: sport?.emoji,
        trailing: trailing,
      ),
    );
  }
}
