import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/league.dart';
import '../../domain/repositories/league_repository.dart';

class LeagueState extends Equatable {
  const LeagueState({
    this.national = false,
    this.sportId = 'badminton',
    this.clubsKey = '',
    this.area,
    this.nationalBoard,
    this.loading = true,
  });

  final bool national;

  /// Sport the boards were loaded for (the user's active sport).
  final String sportId;

  /// Joined club ids the boards were loaded for; a change triggers a reload.
  final String clubsKey;
  final Division? area;
  final Division? nationalBoard;
  final bool loading;

  /// Board shown on the tab; null when the user has no league club here.
  Division? get division => national ? nationalBoard : area;

  LeagueState copyWith({bool? national}) => LeagueState(
    national: national ?? this.national,
    sportId: sportId,
    clubsKey: clubsKey,
    area: area,
    nationalBoard: nationalBoard,
    loading: loading,
  );

  @override
  List<Object?> get props => [
    national,
    sportId,
    clubsKey,
    area,
    nationalBoard,
    loading,
  ];
}

class LeagueCubit extends Cubit<LeagueState> {
  LeagueCubit(this._repo) : super(const LeagueState());

  final LeagueRepository _repo;
  var _request = 0;

  /// Loads both boards for [sportId] (default: the current one).
  Future<void> load({String? sportId, String? clubsKey}) async {
    final sport = sportId ?? state.sportId;
    final key = clubsKey ?? state.clubsKey;
    final id = ++_request;
    emit(
      LeagueState(
        national: state.national,
        sportId: sport,
        clubsKey: key,
        area: sport == state.sportId ? state.area : null,
        nationalBoard: sport == state.sportId ? state.nationalBoard : null,
      ),
    );
    final area = await _repo.division(national: false, sportId: sport);
    final national = await _repo.division(national: true, sportId: sport);
    if (id != _request || isClosed) return;
    emit(
      LeagueState(
        national: state.national,
        sportId: sport,
        clubsKey: key,
        area: area,
        nationalBoard: national,
        loading: false,
      ),
    );
  }

  /// Reloads only when the active sport or joined clubs changed.
  Future<void> sync({required String sportId, required String clubsKey}) {
    if (sportId == state.sportId && clubsKey == state.clubsKey) {
      return Future.value();
    }
    return load(sportId: sportId, clubsKey: clubsKey);
  }

  void setNational(bool v) => emit(state.copyWith(national: v));

  String? _picked;

  /// Sport chosen on the league tab; null follows the user's active sport.
  String? get picked => _picked;

  /// Shows the league of [sportId] without changing the active sport.
  Future<void> choose(String sportId) {
    _picked = sportId;
    return sync(sportId: sportId, clubsKey: state.clubsKey);
  }

  Future<Segment> segment(String id) => _repo.segment(id);
}
