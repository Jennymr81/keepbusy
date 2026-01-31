// lib/repositories/local/saved_repository_isar.dart
import 'dart:convert';

import 'package:isar/isar.dart';

import '../../data/db.dart';
import '../../models/saved_state.dart';

class SavedRepositoryIsar {
  SavedRepositoryIsar._();

  static const Id _singletonId = 0;

  static Future<SavedState> _getOrCreate(Isar isar) async {
    final existing = await isar.collection<SavedState>().get(_singletonId);
    if (existing != null) return existing;

    final created = SavedState()..id = _singletonId; // ✅ explicit singleton id
    await isar.collection<SavedState>().put(created);
    return created;
  }

  /// Loads favorites + slot selections (source of truth).
  static Future<({
    Set<int> favoriteEventIds,
    Map<int, Set<int>> slotSelections,
  })> load() async {
    final isar = await getIsar();
    final row = await isar.collection<SavedState>().get(_singletonId);

    if (row == null) {
      return (
        favoriteEventIds: <int>{},
        slotSelections: <int, Set<int>>{},
      );
    }

    final favList = (jsonDecode(row.favoriteEventIdsJson) as List)
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();

    final decoded = jsonDecode(row.slotSelectionsJson);
    final result = <int, Set<int>>{};

    if (decoded is Map<String, dynamic>) {
      decoded.forEach((slotIdStr, profListAny) {
        final slotId = int.tryParse(slotIdStr);
        if (slotId == null) return;

        final profSet = <int>{};
        if (profListAny is List) {
          for (final v in profListAny) {
            if (v is num) profSet.add(v.toInt());
          }
        }

        if (profSet.isNotEmpty) result[slotId] = profSet;
      });
    }

    return (favoriteEventIds: favList, slotSelections: result);
  }

  /// Saves favorites + slot selections (source of truth).
  static Future<void> save({
    required Set<int> favoriteEventIds,
    required Map<int, Set<int>> slotSelections,
  }) async {
    final isar = await getIsar();

    final Map<String, List<int>> out = {};
    slotSelections.forEach((slotId, profSet) {
      if (profSet.isEmpty) return;
      out[slotId.toString()] = (profSet.toList()..sort());
    });

    final favJson = jsonEncode(favoriteEventIds.toList()..sort());
    final selJson = jsonEncode(out);

    await isar.writeTxn(() async {
      final row = await _getOrCreate(isar);
      row.favoriteEventIdsJson = favJson;
      row.slotSelectionsJson = selJson;
      await isar.collection<SavedState>().put(row);
    });
  }

  static Future<void> clear() async {
    await save(
      favoriteEventIds: <int>{},
      slotSelections: <int, Set<int>>{},
    );
  }
}
