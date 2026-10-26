import '../../../activity/domain/entities/activity.dart';
import 'stamp_entry.dart';
import 'user_profile.dart';

/// One view of the existing calendar and saved activities, shared by the
/// calendar, profile preview and Story. Session details remain in Activity.
abstract final class StampCalendar {
  static Map<DateTime, StampEntry> days(
    UserProfile profile,
    Iterable<Activity> activities,
  ) {
    final days = {
      for (final entry in profile.calendarHistory) entry.day: entry,
    };
    for (final activity in activities) {
      final date = DateTime(
        activity.start.year,
        activity.start.month,
        activity.start.day,
      );
      days[date] = (days[date] ?? StampEntry(date)).addSport(activity.sportId);
    }
    return days;
  }
}
