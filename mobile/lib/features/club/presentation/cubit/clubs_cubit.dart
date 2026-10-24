import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';

class ClubsState extends Equatable {
  const ClubsState({this.mine = const [], this.nearby = const [], this.invites = const [], this.pending = const {}, this.loading = true});

  final List<Club> mine;
  final List<Club> nearby;
  final List<ClubInvite> invites;

  /// Clubs that need approval and were requested ("MINTA").
  final Set<String> pending;
  final bool loading;

  bool isMember(String id) => mine.any((c) => c.id == id);

  ClubsState copyWith({List<Club>? mine, List<Club>? nearby, List<ClubInvite>? invites, Set<String>? pending, bool? loading}) => ClubsState(
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
    final r = await Future.wait([_repo.myClubs(), _repo.nearby(sportId: sportId), _repo.invites()]);
    emit(state.copyWith(mine: r[0] as List<Club>, nearby: r[1] as List<Club>, invites: r[2] as List<ClubInvite>, loading: false));
  }

  Future<void> join(Club club) async {
    if (club.needsApproval) {
      emit(state.copyWith(pending: {...state.pending, club.id}));
      return;
    }
    await _repo.join(club.id);
    await load();
  }

  Future<void> acceptInvite(ClubInvite i) async {
    await _repo.join(i.club.id);
    await load();
  }

  Future<void> declineInvite(ClubInvite i) async {
    await _repo.decline(i.club.id);
    await load();
  }

  Future<Club> create({required String name, required String sportId, required String area, required ClubPrivacy privacy}) async {
    final c = await _repo.create(name: name, sportId: sportId, area: area, privacy: privacy);
    await load();
    return c;
  }
}
