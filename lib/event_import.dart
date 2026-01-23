// lib/event_import.dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models/event_models.dart';
import 'data/db.dart' show getIsar; // adjust if getIsar is in a different file





// ------------------
// Import DTO classes
// ------------------

class ImportedSession {
  ImportedSession({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.weekday,      // 1 = Mon ... 7 = Sun
    required this.startMinutes, // e.g. 11:00 -> 660
    required this.endMinutes,
    required this.ageMin,
    required this.ageMax,
    required this.fee,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final int ageMin;
  final int ageMax;
  final double fee;

  factory ImportedSession.fromJson(Map<String, dynamic> json) {
    int _weekdayFromAbbrev(String s) {
      const map = {
        'mon': DateTime.monday,
        'tue': DateTime.tuesday,
        'wed': DateTime.wednesday,
        'thu': DateTime.thursday,
        'fri': DateTime.friday,
        'sat': DateTime.saturday,
        'sun': DateTime.sunday,
      };
      return map[s.toLowerCase()] ?? DateTime.monday;
    }

    int _minutesFromTime(String hhmm) {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    }

    return ImportedSession(
      label: json['label'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      weekday: _weekdayFromAbbrev(json['weekday'] as String),
      startMinutes: _minutesFromTime(json['startTime'] as String),
      endMinutes: _minutesFromTime(json['endTime'] as String),
      ageMin: json['ageMin'] as int,
      ageMax: json['ageMax'] as int,
      fee: (json['fee'] as num).toDouble(),
    );
  }
}

class ImportedEvent {
  ImportedEvent({
    required this.title,
    required this.category,
    required this.description,
    required this.locationName,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.sessions,
  });

  final String title;
  final String category;
  final String description;
  final String locationName;
  final String address;
  final String city;
  final String state;
  final String zip;
  final List<ImportedSession> sessions;

  factory ImportedEvent.fromJson(Map<String, dynamic> json) {
    final sessJson = json['sessions'] as List<dynamic>? ?? const [];
    return ImportedEvent(
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zip: json['zip'] as String? ?? '',
      sessions: sessJson
          .map((e) => ImportedSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ------------------
// Load JSON from asset
// ------------------

Future<List<ImportedEvent>> loadImportedEventsFromAsset(
    String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => ImportedEvent.fromJson(e as Map<String, dynamic>))
      .toList();
}

// ------------------
// Import into Isar
// ------------------

Future<void> importEventsFromFeed(List<ImportedEvent> feed) async {
  final isar = await getIsar();

  // helper: weekly dates between start/end on a specific weekday
  List<DateTime> _weeklyDates(DateTime start, DateTime end, int weekday) {
    var d = start;
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    final dates = <DateTime>[];
    while (!d.isAfter(end)) {
      dates.add(d);
      d = d.add(const Duration(days: 7));
    }
    return dates;
  }

  await isar.writeTxn(() async {
    for (final imported in feed) {
      if (imported.sessions.isEmpty) continue;

      // Build a flat list of all dates for this event
      final allDates = imported.sessions
          .expand((s) => _weeklyDates(s.startDate, s.endDate, s.weekday))
          .toList()
        ..sort();

      if (allDates.isEmpty) continue;

      final event = Event()
        ..date         = allDates.first
        ..profileIndex = 0
        ..title        = imported.title
        ..locationName = imported.locationName
        ..address      = imported.address
        ..city         = imported.city
        ..state        = imported.state
        ..zip          = imported.zip
        ..description  = imported.description
        ..shortDescription = imported.description
        ..interests    = [imported.category];

      final slots = <EventSlot>[];

      for (int i = 0; i < imported.sessions.length; i++) {
        final s = imported.sessions[i];
        final dates = _weeklyDates(s.startDate, s.endDate, s.weekday);

        for (final d in dates) {
          slots.add(
            EventSlot()
              ..date         = d
              ..startMinutes = s.startMinutes
              ..endMinutes   = s.endMinutes
              ..sessionIndex = i
              ..ageMin       = s.ageMin
              ..ageMax       = s.ageMax
              ..cost         = s.fee,
          );
        }
      }

      await isar.events.put(event);
      for (final s in slots) {
        final sid  = await isar.eventSlots.put(s);
        final slot = await isar.eventSlots.get(sid);
        if (slot != null) {
          event.slotIds.add(slot);
        }
      }
      await event.slotIds.save();
      await isar.events.put(event);
    }
  });
}

