import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/backend/dev_api.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/me_cubit.dart';

enum PeopleMode {
  search('Cari pengguna', 'Tidak ada pengguna yang cocok.'),
  following('Mengikuti', 'Kamu belum mengikuti siapa pun.'),
  followers('Pengikut', 'Kamu belum punya pengikut.');

  const PeopleMode(this.title, this.emptyMessage);
  final String title;
  final String emptyMessage;
}

class PeoplePage extends StatefulWidget {
  const PeoplePage(this.mode, {super.key});

  final PeopleMode mode;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  static const _pageSize = 30;
  final _api = sl<DevApi>();
  Future<List<PeopleResult>>? _results;
  Timer? _debounce;
  String _query = '';
  String? _savingId;
  int _offset = 0;
  late PeopleMode _mode = widget.mode;

  bool get _isSearch => _mode == PeopleMode.search;
  bool get _queryReady => _query.replaceFirst(RegExp(r'^@+'), '').length >= 2;

  @override
  void initState() {
    super.initState();
    if (!_isSearch) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _load() {
    _results = _api.findPeople(_mode.name, _query, _offset);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value.trim();
      _offset = 0;
      _results = null;
    });
    if (_queryReady) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(_load);
      });
    }
  }

  void _changePage(int offset) => setState(() {
    _offset = offset;
    _load();
  });

  Future<void> _toggleFollow(String id, bool follow) async {
    if (_savingId != null) return;
    final me = context.read<MeCubit>();
    setState(() => _savingId = id);
    try {
      await _api.setUserFollow(id, follow);
      if (mounted && _results != null) {
        setState(() {
          if (!follow && _mode == PeopleMode.following) _offset = 0;
          _load();
        });
      }
      await me.load();
    } on Object {
      if (mounted) toast(context, 'Gagal memperbarui status ikuti. Coba lagi.');
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => KPage(
    header: KHeader(_isSearch ? 'Cari pengguna' : 'Teman main'),
    stagger: false,
    children: [
      if (!_isSearch)
        KSegmented(
          items: const ['Pengikut', 'Mengikuti'],
          index: _mode == PeopleMode.followers ? 0 : 1,
          onChanged: (index) => setState(() {
            _mode = index == 0 ? PeopleMode.followers : PeopleMode.following;
            _offset = 0;
            _load();
          }),
        ),
      if (_isSearch)
        KInput(
          hint: 'Nama atau username',
          icon: LucideIcons.search,
          onChanged: _onQueryChanged,
        ),
      if (_isSearch && !_queryReady)
        Text('Ketik minimal 2 karakter.', style: AppText.bodySm())
      else
        FutureBuilder<List<PeopleResult>>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const KContentState(
                loading: true,
                title: 'Mencari teman main',
                message: 'Sebentar, daftar pengguna sedang dimuat.',
              );
            }
            if (snapshot.hasError) {
              return KContentState(
                error: true,
                title: 'Pengguna belum bisa dimuat',
                message: 'Cek koneksi internet lalu coba lagi.',
                action: 'Coba lagi',
                onAction: () => setState(_load),
              );
            }
            final people = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (people.isEmpty)
                  KContentState(
                    title: _mode.emptyMessage,
                    message: _isSearch
                        ? 'Coba nama atau username lain.'
                        : 'Cari teman olahraga dan mulai saling mengikuti.',
                  ),
                for (final person in people.take(_pageSize)) _personRow(person),
                Wrap(
                  spacing: 16,
                  children: [
                    if (_offset > 0)
                      KLink(
                        'Sebelumnya',
                        onTap: () => _changePage(_offset - _pageSize),
                      ),
                    if (people.length > _pageSize)
                      KLink(
                        'Selanjutnya',
                        onTap: () => _changePage(_offset + _pageSize),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
    ],
  );

  Widget _personRow(PeopleResult person) {
    final id = person.id;
    final following = person.isFollowing;
    final avatar = ProfileAvatar.values
        .where((value) => value.name == person.avatar)
        .firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '@${person.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.soft,
        child: Image.asset((avatar ?? ProfileAvatar.kapi).asset, width: 32),
      ),
      trailing: KMiniButton(
        following ? 'Berhenti ikuti' : 'Ikuti',
        loading: _savingId == id,
        onTap: _savingId == null ? () => _toggleFollow(id, !following) : null,
      ),
    );
  }
}
