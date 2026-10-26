import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';

class ClubsState extends Equatable {
  const ClubsState({
    this.mine = const [],
    this.nearby = const [],
    this.invites = const [],
    this.pending = const {},
    this.loading = true,
  });

  final List<Club> mine;
  final List<Club> nearby;
  final List<ClubInvite> invites;

  /// Clubs that need approval and were requested ("MINTA").
  final Set<String> pending;
  final bool loading;

  bool isMember(String id) => mine.any((c) => c.id == id);

  ClubsState copyWith({
    List<Club>? mine,
    List<Club>? nearby,
    List<ClubInvite>? invites,
    Set<String>? pending,
    bool? loading,
  }) => ClubsState(
    mine: mine ?? this.mine,
    nearby: nearby ?? this.nearby,
    invites: invites ?? this.invites,
    pending: pending ?? this.pending,
    loading: loading ?? this.loading,
  );

  @override
  List<Object?> get props => [mine, nearby, invites, pending, loading];
}

class ClubsCubit extends Cubit<ClubsState> {
  ClubsCubit(this._repo) : super(const ClubsState());

  final ClubRepository _repo;

  Future<void> load({String? sportId}) async {
    final r = await Future.wait([
      _repo.myClubs(),
      _repo.nearby(sportId: sportId),
      _repo.invites(),
    ]);
    emit(
      state.copyWith(
        mine: r[0] as List<Club>,
        nearby: r[1] as List<Club>,
        invites: r[2] as List<ClubInvite>,
        loading: false,
      ),
    );
  }

  Future<void> join(Club club) async {
    if (club.needsApproval) {
      emit(state.copyWith(pending: {...state.pending, club.id}));
      return;
    }
    await _repo.join(club.id);
    await load();
  }

  Future<void> leave(Club club) async {
    await _repo.leave(club.id);
    await load();
  }

  /// Chat opened: clear the unread badge.
  Future<void> markRead(String clubId) async {
    await _repo.markRead(clubId);
    await load();
  }

  Future<void> setPayout(String clubId, PayoutAccount payout) async {
    await _repo.setPayout(clubId, payout);
    await load();
  }

  /// Klub Pro trial started from O2.
  Future<void> activatePro(String clubId) async {
    await _repo.activatePro(clubId);
    await load();
  }

  Future<KasSummary> kas(String clubId) => _repo.kas(clubId);

  /// "Catat keluar": money spent from kas.
  Future<KasSummary> addExpense(
    String clubId, {
    required int amount,
    required String category,
    required String note,
  }) {
    final kind = switch (category) {
      'Sewa GOR' => 'gor',
      'Kok/Bola' => 'kok',
      _ => 'lain',
    };
    return _repo.addKas(
      clubId,
      KasEntry(
        title: note.isEmpty ? category : note,
        sub: '$category · ${_today()}',
        amount: -amount,
        kind: kind,
      ),
    );
  }

  /// "Tarik dana" to the payout account. Not spending, so monthly totals stay.
  Future<KasSummary> withdraw(
    String clubId, {
    required int amount,
    required PayoutAccount to,
  }) => _repo.addKas(
    clubId,
    KasEntry(
      title: 'Tarik dana',
      sub: '${to.masked} · ${_today()}',
      amount: -amount,
      kind: 'tarik',
    ),
    counts: false,
  );

  static String _today() {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final d = DateTime.now();
    return '${d.day} ${m[d.month - 1]}';
  }

  Future<void> acceptInvite(ClubInvite i) async {
    await _repo.join(i.club.id);
    await load();
  }

  Future<void> declineInvite(ClubInvite i) async {
    await _repo.decline(i.club.id);
    await load();
  }

  Future<Club> create({
    required String name,
    required String sportId,
    required String area,
    required ClubPrivacy privacy,
    String? logoPath,
    PayoutAccount? payout,
  }) async {
    final c = await _repo.create(
      name: name,
      sportId: sportId,
      area: area,
      privacy: privacy,
      logoPath: logoPath,
      payout: payout,
    );
    await load();
    return c;
  }
}
