import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/services/test_account.dart';
import 'package:klubby/core/services/watch_bridge.dart';

/// Watch ↔ phone account link (hardcoded test account until login exists).
void main() {
  Map<String, dynamic> workout([String? account]) => {
    'type': 'workout',
    'sport': 'lari',
    'start': 1000,
    'end': 61000,
    'account': ?account,
  };

  test('the watch asking for the account is parsed', () {
    expect(WatchEvent.parse({'type': 'whoami'}), isA<WatchWhoAmI>());
  });

  test('only workouts from another account are rejected', () {
    bool other(String? a) =>
        (WatchEvent.parse(workout(a))! as WatchWorkout).otherAccount;
    expect(other(TestAccount.id), isFalse);
    expect(other(null), isFalse, reason: 'older watch builds send no account');
    expect(other('someone_else'), isTrue);
  });
}
