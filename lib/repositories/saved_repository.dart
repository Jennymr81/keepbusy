abstract class SavedRepository {
  Future<({
    Set<int> favoriteEventIds,
    Map<int, Set<int>> slotSelections,
  })> load(String userId);

  Future<void> save({
    required String userId,
    required Set<int> favoriteEventIds,
    required Map<int, Set<int>> slotSelections,
  });

  Future<void> clear(String userId);
}