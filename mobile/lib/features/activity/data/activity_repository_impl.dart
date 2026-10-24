import '../../../core/widgets/flat_map.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/activity.dart';
import '../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final _items = <Activity>[
    Activity(
      id: 'gbk',
      sportId: 'lari',
      title: 'Lari Pagi GBK',
      start: DateTime.now().copyWith(hour: 6, minute: 12),
      duration: const Duration(minutes: 32, seconds: 10),
      source: ActivitySource.gps,
      distanceKm: 5.24,
      avgHr: 152,
      route: FlatMap.demoRoute,
      splits: const [382, 365, 358, 374],
      clubName: 'Klub Lari Santai GBK',
    ),
  ];

  @override
  Future<List<Activity>> recent() async => List.unmodifiable(_items);

  @override
  Future<void> save(Activity a) async => _items.insert(0, a);

  @override
  Future<void> discard(String id) async => _items.removeWhere((a) => a.id == id);

  /// Host QR payloads look like `klubby://checkin/<sessionId>/<rotatingToken>`.
  @override
  Future<String> checkIn(String qr) async {
    final uri = Uri.tryParse(qr);
    if (uri == null || uri.scheme != 'klubby' || uri.host != 'checkin' || uri.pathSegments.isEmpty) {
      throw const CheckInException(CheckInError.unknownCode);
    }
    return uri.pathSegments.first;
  }
}
