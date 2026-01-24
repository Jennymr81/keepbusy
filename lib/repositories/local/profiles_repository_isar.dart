// lib/repositories/local/profiles_repository_isar.dart
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import '../../data/db.dart';
import '../../models/profile.dart';

class ProfilesRepositoryIsar {
  ProfilesRepositoryIsar._();

  static Isar? _isar;

  static Future<void> init() async {
    _isar ??= await getIsar();
    debugPrint('KEEPBUSY(DB): ProfilesRepositoryIsar ready');
  }

  static Future<List<Profile>> loadProfiles() async {
    final isar = _isar ?? await getIsar();
    _isar = isar;
    return isar.collection<Profile>().where().findAll();
  }

  static Future<void> saveProfile(Profile profile) async {
    final isar = _isar ?? await getIsar();
    _isar = isar;

    await isar.writeTxn(() async {
      final id = await isar.collection<Profile>().put(profile);
      profile.id = id; // keep object in sync
    });
  }

  static Future<void> deleteProfile(Profile profile) async {
    final isar = _isar ?? await getIsar();
    _isar = isar;

    await isar.writeTxn(() async {
      if (profile.id != 0) {
        await isar.collection<Profile>().delete(profile.id);
        return;
      }

      // fallback if id missing
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
        await isar.collection<Profile>().delete(match.id);
      }
    });
  }
}