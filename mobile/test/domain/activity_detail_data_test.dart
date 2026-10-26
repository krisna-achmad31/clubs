import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/entities/activity_analysis.dart';
import 'package:klubby/features/activity/domain/entities/activity_sample.dart';
import 'package:klubby/features/feed/data/feed_repository_impl.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';

import '../support/detailed_activity_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('summaries distinguish moving time from total time and compute measured sensor statistics', () {
    final data = ActivityAnalysis(detailedActivity());
    expect(data.averagePace, 600);
    expect(data.elapsedPace, 720);
    expect(data.averageHeartRate, 137.5);
    expect(data.maxHeartRate, 160);
    expect(data.averageCadence, 116.25);
    expect(data.maxCadence, 130);
    expect(data.elevationGain, 13);
    expect(data.splits.map((p) => p.km), [1, 1, .5]);
    expect(data.splits.map((p) => p.seconds), [600, 600, 300]);
    expect(data.fastestSplit, 600);
    expect(
      data.series(ActivityMetric.pace).map((p) => p.value),
      everyElement(600),
    );
    expect(data.route.length, 4);
    expect(
      data.route.every(
        (p) => p.dx >= .09 && p.dx <= .91 && p.dy >= .09 && p.dy <= .91,
      ),
      isTrue,
    );
  });
  test('pace retains time between actual distance changes when stationary GPS samples arrive', () {
    final json = detailedActivity().toJson();
    json['samples'] = [
      for (final (seconds, distance) in [(0.0, 0.0), (9.0, 0.0), (10.0, 10.0)])
        ActivitySample(
          elapsedSeconds: seconds,
          movingSeconds: seconds,
          distanceMeters: distance,
          latitude: -6.2,
          longitude: 106.8 + distance / 100000,
        ).toJson(),
    ];
    final data = ActivityAnalysis(Activity.fromJson(json));
    expect(data.series(ActivityMetric.pace).single.value, 1000);
  });
  test(
    'legacy activities retain summary data without fabricated sensor charts',
    () {
      final json = detailedActivity().toJson()
        ..remove('samples')
        ..remove('elapsedSeconds');
      json['hr'] = 147;
      final data = ActivityAnalysis(Activity.fromJson(json));
      expect(data.elapsed, const Duration(minutes: 25));
      expect(data.averageHeartRate, 147);
      expect(data.maxHeartRate, isNull);
      expect(data.averageCadence, isNull);
      expect(data.elevationGain, isNull);
      for (final metric in ActivityMetric.values) {
        expect(data.series(metric), isEmpty);
      }
    },
  );
  test('raw samples, timestamps, pause duration and notes survive repository restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final activity = detailedActivity();
    await ActivityRepositoryImpl(prefs).save(activity);
    final restored = (await ActivityRepositoryImpl(prefs).recent()).first;
    expect(restored.toJson(), activity.toJson());
    expect(restored.samples, activity.samples);
    expect(ActivityAnalysis(restored).elapsedPace, 720);
  });
  test('published activity opens the same detailed recording from the feed after restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final activities = ActivityRepositoryImpl(prefs);
    await activities.save(detailedActivity());
    final profiles = ProfileRepositoryImpl(prefs);
    final feed = FeedRepositoryImpl(activities: activities, profiles: profiles);
    final post = (await feed.feed(publik: false)).first;
    expect(post.id, 'activity:details');
    expect(post.mine, isTrue);
    expect(post.activity!.samples.length, 4);
    expect(post.author, 'Budi Santoso');
    expect(post.hasRoute, isTrue);
    expect(post.splits, [600, 600]);
    await feed.react(post.id, '🔥');
    expect((await feed.byId(post.id)).reactions.single.mine, isTrue);
    final restarted = FeedRepositoryImpl(
      activities: ActivityRepositoryImpl(prefs),
      profiles: ProfileRepositoryImpl(prefs),
    );
    expect(
      (await restarted.byId(post.id)).activity!.toJson(),
      detailedActivity().toJson(),
    );
    expect(
      (await restarted.feed(publik: false))
          .where((p) => p.id == 'activity:gbk'),
      isEmpty,
    );
  });
  test('followers-only posts stay out of the public feed and unknown ids do not open a different activity', () async {
    final prefs = await SharedPreferences.getInstance();
    final activities = ActivityRepositoryImpl(prefs);
    await activities.save(detailedActivity());
    await activities.save(
      detailedActivity(id: 'public', privacy: Privacy.publik),
    );
    final feed = FeedRepositoryImpl(
      activities: activities,
      profiles: ProfileRepositoryImpl(prefs),
    );
    final posts = await feed.feed(publik: true);
    expect(posts.any((p) => p.id == 'activity:details'), isFalse);
    expect(posts.any((p) => p.id == 'activity:public'), isTrue);
    await expectLater(feed.byId('missing'), throwsStateError);
  });
}
