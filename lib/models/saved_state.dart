import 'package:isar/isar.dart';

part 'saved_state.g.dart';

@collection
class SavedState {
  Id id = 0; // singleton row (always 0)

  String favoriteEventIdsJson = '[]';

  /// Source of truth: slotId -> profileIndexes
  String slotSelectionsJson = '{}';

  /// Legacy (can be removed later after full migration)
  String sessionSelectionsJson = '{}';
}
