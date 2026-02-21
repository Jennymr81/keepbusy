import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../data/db.dart';
import '../models/event_models.dart';



// =============================================================
// DEV SAMPLE IMPORTER
// (optional helper to seed Folklorico event data into Isar)
// =============================================================
Future<void> importSpanishMexicanDanceSample() async {
  final isar = await getIsar();

  // 1) Build the Event (top-level info)
  final event = Event()
    ..date = DateTime(2024, 9, 6) // earliest date of any session
    ..profileIndex = 0
    ..title = 'Spanish & Mexican Dance (Folklorico)'
    ..locationName = 'Youth Center'
    ..address = '437 E Dalton Ave'
    ..city = 'Glendora'
    ..state = 'CA'
    ..zip = '91741'
    ..description =
        'Enjoy a cultural journey through dance with vibrant classes...'
    ..shortDescription =
        'Beginner, Intermediate, and Advanced folklorico dance.'
    ..feeNote = 'Shoes are required; info available first day of class.'
    ..interests = ['Dance', 'Youth sports'];

  // Helper to make weekly dates between two endpoints on a given weekday
  List<DateTime> _weeklyDates(DateTime start, DateTime end, int weekday) {
    // weekday: 1=Mon .. 7=Sun
    // move start forward to the first desired weekday
    var d = start;
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    final res = <DateTime>[];
    while (!d.isAfter(end)) {
      res.add(d);
      d = d.add(const Duration(days: 7));
    }
    return res;
  }

  // (Unused here but handy if you ever need it for sample images)
  ImageProvider _savedImageProvider(String? src) {
    const fallback = 'assets/soccer_camp.jpg';

    if (src == null || src.trim().isEmpty) {
      return const AssetImage(fallback);
    }
    if (src.startsWith('http')) {
      return NetworkImage(src);
    }
    if (src.startsWith('assets/')) {
      return AssetImage(src);
    }
    return FileImage(File(src));
  }

  // All slots go here
  final slots = <EventSlot>[];

  // Assume everything is on Saturday in your sample (adjust as needed)
  const sat = DateTime.saturday; // 6

  // Helper to make one session’s slots
  void addSession({
    required int sessionIndex,
    required DateTime start,
    required DateTime end,
    required int ageMin,
    required int ageMax,
    required double fee, // total for this session
    required int startHour,
    required int endHour,
  }) {
    final dates = _weeklyDates(start, end, sat);
    final startMinutes = startHour * 60; // 11:30 → 11 * 60 + 30, etc.
    final endMinutes = endHour * 60;

    for (final d in dates) {
      slots.add(
        EventSlot()
          ..date = d
          ..startMinutes = startMinutes
          ..endMinutes = endMinutes
          ..sessionIndex = sessionIndex
          ..ageMin = ageMin
          ..ageMax = ageMax
          ..cost = fee,
      );
    }
  }

  // === Example sessions based on your screenshot ===
  // Beginner: Sep 6 – Oct 18, ages 3–12, 11:00am–12:00pm, $101
  addSession(
    sessionIndex: 0,
    start: DateTime(2024, 9, 6),
    end: DateTime(2024, 10, 18),
    ageMin: 3,
    ageMax: 12,
    fee: 101,
    startHour: 11,
    endHour: 12,
  );

  // Beginner second block (same ages, different dates / fee)
  addSession(
    sessionIndex: 1,
    start: DateTime(2024, 11, 1),
    end: DateTime(2024, 12, 20),
    ageMin: 3,
    ageMax: 12,
    fee: 88,
    startHour: 11,
    endHour: 12,
  );

  // 2) Persist Event + slots using your existing pattern
  await isar.writeTxn(() async {
    await isar.events.put(event);
    for (final s in slots) {
      final id = await isar.eventSlots.put(s);
      final got = await isar.eventSlots.get(id);
      if (got != null) event.slotIds.add(got);
    }
    await event.slotIds.save();
    await isar.events.put(event);
  });
}
