import 'package:isar/isar.dart';

part 'saved_state.g.dart';

@collection
class SavedState {
  Id id = 0; // singleton row

  late String favoriteEventIdsJson;
  late String sessionSelectionsJson;

  SavedState({
    this.id = 0,
    this.favoriteEventIdsJson = '[]',
    this.sessionSelectionsJson = '{}',
  });
}
