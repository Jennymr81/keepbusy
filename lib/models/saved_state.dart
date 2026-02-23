import 'package:isar/isar.dart';

part 'saved_state.g.dart';

@collection
class SavedState {
  Id id = Isar.autoIncrement; // unique row per user

  @Index(unique: true, replace: true)
  late String userId;

  String favoriteEventIdsJson = '[]';

  /// Source of truth: slotId -> profileIndexes
  String slotSelectionsJson = '{}';
}
