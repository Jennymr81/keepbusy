import 'package:isar/isar.dart';

part 'saved_state.g.dart';

@collection
class SavedState {
  Id id = 0; // singleton row (always 0)

  String favoriteEventIdsJson = '[]';
  String sessionSelectionsJson = '{}';
}
