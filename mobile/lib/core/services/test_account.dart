import '../backend/dev_api.dart';
import '../di/injector.dart';
import '../../features/profile/presentation/cubit/me_cubit.dart';

/// Current signed-in Klubby account identity resolved from DI/API state.
abstract final class TestAccount {
  static String get id {
    if (sl.isRegistered<MeCubit>()) {
      final username = sl<MeCubit>().state.username;
      if (username.isNotEmpty) return username;
    }
    if (sl.isRegistered<DevApi>()) {
      return sl<DevApi>().currentUserId ?? '';
    }
    return '';
  }

  static String get name {
    if (sl.isRegistered<MeCubit>()) {
      final n = sl<MeCubit>().state.name;
      if (n.isNotEmpty) return n;
    }
    return '';
  }
}
