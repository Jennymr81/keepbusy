// lib/utils/date_utils.dart

import 'package:flutter/material.dart';

/// Normalize a DateTime to just year-month-day (no time component).
DateTime asDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Short weekday labels used across the app (Mon, Tue, etc.).
const List<String> kWeekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// Convert weekday int (1=Mon ... 7=Sun) to a short label.
String weekdayShortFromInt(int weekday) {
  if (weekday < 1 || weekday > 7) return '?';
  return kWeekdayShort[weekday - 1];
}

/// Convenience: get short weekday from a DateTime directly.
String weekdayShortFromDate(DateTime d) => kWeekdayShort[d.weekday - 1];

/// Month labels for simple "Jan 3" style formatting.
const List<String> _monthNames = [
  '',
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Format a date as "Jan 3".
String monthDay(DateTime d) => '${_monthNames[d.month]} ${d.day}';

/// Format a date range like "Jan 3 – Feb 7".
String monthDayRange(DateTime? a, DateTime? b) {
  if (a == null || b == null) return '—';
  final sameMonth = a.month == b.month && a.year == b.year;
  if (sameMonth) {
    return '${_monthNames[a.month]} ${a.day} – ${b.day}';
  }
  return '${_monthNames[a.month]} ${a.day} – '
         '${_monthNames[b.month]} ${b.day}';
}

/// Convert TimeOfDay to minutes since midnight.
int? timeOfDayToMinutes(TimeOfDay? t) =>
    t == null ? null : t.hour * 60 + t.minute;

/// Convert minutes since midnight back to TimeOfDay.
TimeOfDay? minutesToTimeOfDay(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

/// Rough number of calendar weeks covered by a set of distinct dates.
/// Example: if there are sessions on Tue/Thu for 6 weeks, this returns 6.
int numWeeksFromDates(Iterable<DateTime> dates) {
  // Normalize to Y-M-D and remove duplicates.
  final set = {for (final d in dates) asDate(d)};
  if (set.isEmpty) return 0;

  final sorted = set.toList()..sort();
  final first = sorted.first;
  final last = sorted.last;

  // Snap each to the Monday of its week.
  DateTime toMonday(DateTime d) =>
      asDate(d).subtract(Duration(days: d.weekday - DateTime.monday));

  final firstWeek = toMonday(first);
  final lastWeek = toMonday(last);

  final diffDays = lastWeek.difference(firstWeek).inDays;
  return diffDays ~/ 7 + 1;
}
