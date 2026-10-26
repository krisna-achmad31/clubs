import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/league.dart';
import '../../domain/repositories/league_repository.dart';

class LeagueState extends Equatable {
  const LeagueState({this.national = false, this.division});

  final bool national;
  final Division? division;

  @override
  List<Object?> get props => [national, division];
}

class LeagueCubit extends Cubit<LeagueState> {
  LeagueCubit(this._repo) : super(const LeagueState());

  final LeagueRepository _repo;

  Future<void> load() async => emit(
    LeagueState(
      national: state.national,
      division: await _repo.division(national: state.national),
    ),
  );

  Future<void> setNational(bool v) async {
    emit(LeagueState(national: v, division: state.division));
    emit(
      LeagueState(
        national: v,
        division: await _repo.division(national: v),
      ),
    );
  }

  Future<Segment> segment(String id) => _repo.segment(id);
}
