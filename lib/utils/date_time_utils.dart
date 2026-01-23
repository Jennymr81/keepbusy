
// lib/utils/date_time_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';



// =============================================================
// DATE / TIME HELPERS
// (Calendar page, Event Quick View, Saved page, Event Entry)
// =============================================================


// Strip a DateTime down to Y-M-D (no time portion)
DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

// TimeOfDay <-> minutes since midnight
int? timeToMin(TimeOfDay? t) => t == null ? null : t.hour * 60 + t.minute;
TimeOfDay? minToTime(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

// “Mondays / Tuesdays / …” for labels when we want the long form
String _weekdayShort(int w) =>
    const ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'][w - 1];

String weekdayFrom(DateTime? d) =>
    d == null
        ? '—'
        : [
            'Mondays',
            'Tuesdays',
            'Wednesdays',
            'Thursdays',
            'Fridays',
            'Saturdays',
            'Sundays'
          ][d.weekday - 1];

// Count distinct ISO weeks from a set of dates
// (used to compute “X weeks” in Event Quick View / Saved page)
int _numWeeksFromDates(Set<DateTime> dates) {
  final buckets = <String>{};
  for (final raw in dates) {
    final dd = _d(raw);
    final monday = dd.subtract(Duration(days: (dd.weekday + 6) % 7));
    final weekNo =
        (monday.difference(DateTime(monday.year, 1, 1)).inDays ~/ 7) + 1;
    buckets.add('${monday.year}-W$weekNo');
  }
  return buckets.length;
}

// Friendly month abbreviations + helpers for range labels
const List<String> _month = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String _md(DateTime d) => '${_month[d.month]} ${d.day}';

String _rangeLabel(DateTime? a, DateTime? b) {
  if (a == null || b == null) return '—';
  final sameMonth = a.month == b.month && a.year == b.year;
  return sameMonth
      ? '${_month[a.month]} ${a.day} – ${b.day}'
      : '${_month[a.month]} ${a.day} – ${_month[b.month]} ${b.day}';
}