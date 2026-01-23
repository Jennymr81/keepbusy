import 'dart:convert';

import 'package:isar/isar.dart';

import '../../data/db.dart';
import '../../models/saved_state.dart';


class SavedStateService {
  SavedStateService._();

  static const Id _singletonId = 0;

  static Future<SavedState> _getOrCreate(Isar isar) async {
    final existing = await isar.collection<SavedState>().get(_singletonId);
    if (existing != null) return existing;

    final created = SavedState();
    await isar.collection<SavedState>().put(created);
    return created;
  }

  /// Loads favorites + session selections.
  /// Returns:
  /// - favorites: Set<int>
  /// - selections: Map<int, Map<int, Set<int>>>
  static Future<({
    Set<int> favoriteEventIds,
    Map<int, Map<int, Set<int>>> sessionSelections,
  })> load() async {
    final isar = await getIsar();
    final row = await isar.collection<SavedState>()
.get(_singletonId);

    if (row == null) {
      return (favoriteEventIds: <int>{}, sessionSelections: <int, Map<int, Set<int>>>{});
    }

    // favorites
    final favList = (jsonDecode(row.favoriteEventIdsJson) as List)
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();

    // selections: Map<String, Map<String, List<int>>>
    final decoded = jsonDecode(row.sessionSelectionsJson);
    final result = <int, Map<int, Set<int>>>{};

    if (decoded is Map<String, dynamic>) {
      decoded.forEach((eventIdStr, sessionsAny) {
        final eventId = int.tryParse(eventIdStr);
        if (eventId == null) return;

        final sessionsMap = <int, Set<int>>{};
        if (sessionsAny is Map<String, dynamic>) {
          sessionsAny.forEach((sessIdxStr, profListAny) {
            final sessIdx = int.tryParse(sessIdxStr);
            if (sessIdx == null) return;

            final profSet = <int>{};
            if (profListAny is List) {
              for (final v in profListAny) {
                if (v is num) profSet.add(v.toInt());
              }
            }

            if (profSet.isNotEmpty) sessionsMap[sessIdx] = profSet;
          });
        }

        if (sessionsMap.isNotEmpty) result[eventId] = sessionsMap;
      });
    }

    return (favoriteEventIds: favList, sessionSelections: result);
  }

  /// Saves favorites + session selections.
  static Future<void> save({
    required Set<int> favoriteEventIds,
    required Map<int, Map<int, Set<int>>> sessionSelections,
  }) async {
    final isar = await getIsar();

    // JSON-safe selections: Map<String, Map<String, List<int>>>
    final Map<String, Map<String, List<int>>> out = {};
    sessionSelections.forEach((eventId, sessions) {
      if (sessions.isEmpty) return;

      final Map<String, List<int>> sessJson = {};
      sessions.forEach((sessionIdx, profSet) {
        if (profSet.isEmpty) return;
        sessJson[sessionIdx.toString()] = (profSet.toList()..sort());
      });

      if (sessJson.isNotEmpty) out[eventId.toString()] = sessJson;
    });

    final favJson = jsonEncode(favoriteEventIds.toList()..sort());
    final selJson = jsonEncode(out);

    await isar.writeTxn(() async {
      final row = await _getOrCreate(isar);
      row.favoriteEventIdsJson = favJson;
      row.sessionSelectionsJson = selJson;
      await isar.collection<SavedState>()
.put(row);
    });
  }

  /// Clears everything saved.
  static Future<void> clear() async {
    await save(favoriteEventIds: <int>{}, sessionSelections: <int, Map<int, Set<int>>>{});
  }
}
