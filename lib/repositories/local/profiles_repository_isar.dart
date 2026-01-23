import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import '../../data/db.dart';
import '../../models/event_models.dart';
import '../../models/profile.dart';




class ProfileService {
    static Isar? _isar;

  /// Initialize Isar (call this once in main.dart)
  static Future<void> init() async {
    if (_isar != null) return;
    // Use the shared Isar instance from DB.dart
    _isar = await getIsar();

    // Optional debug info
    final cnt = await _isar!.collection<Event>().count();
    debugPrint('KEEPBUSY(DB): events in DB = $cnt');
  }


  /// Save or update a profile
static Future<void> saveProfile(Profile profile) async {
  final isar = _isar;
  if (isar == null) return;

  await isar.writeTxn(() async {
    // UPDATE if this id already exists
    if (profile.id != 0) {
      final existing = await isar.collection<Profile>().get(profile.id);
      if (existing != null) {
        existing
          ..firstName  = profile.firstName
          ..lastName   = profile.lastName
          ..nickname   = profile.nickname
          ..birthdate  = profile.birthdate
          ..colorValue = profile.colorValue
          ..asset      = profile.asset
          ..interests  = profile.interests;
        await isar.collection<Profile>().put(existing);
        return;
      }
      // fall through to insert if not found
    }

    // INSERT (new) — capture id and write it back to the same object
    final newId = await isar.collection<Profile>().put(profile);
    if (profile.id == 0) {
      profile.id = newId;
    }
  });
}

  /// Delete exactly one profile. If the incoming object has no id yet (id==0),
  /// try to locate the row by stable fields and delete that row instead.
  static Future<void> deleteProfile(Profile profile) async {
    final isar = _isar;
    if (isar == null) return;

    await isar.writeTxn(() async {
      Id idToDelete = profile.id;

      // If we weren't given a real id, try to find the row by fields.
      if (idToDelete == 0) {
        final match = await isar
            .collection<Profile>()
            .filter()
            .firstNameEqualTo(profile.firstName)
            .and()
            .lastNameEqualTo(profile.lastName)
            .and()
            .birthdateEqualTo(profile.birthdate)
            .and()
            .nicknameEqualTo(profile.nickname)
            .findFirst();

        if (match != null) {
          idToDelete = match.id;
        }
      }

      if (idToDelete != 0) {
        await isar.collection<Profile>().delete(idToDelete);
      }
    });
  }


  /// Load all profiles
  static Future<List<Profile>> loadProfiles() async {
    final isar = _isar;
    if (isar == null) return [];
    return await isar.collection<Profile>().where().findAll();
  }
}
