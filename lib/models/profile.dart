import 'package:isar/isar.dart';

part 'profile.g.dart';

@collection
class Profile {
  Id id = Isar.autoIncrement;

  String firstName = '';
  String lastName = '';
  String? nickname;
  DateTime? birthdate;

  // stored color value
  int colorValue = 0xFFFFFFFF;

  // path to avatar or uploaded image
  String? asset;

  List<String> interests = [];
}
