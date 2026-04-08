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
  }

  // ===============================
  // 🔹 LOAD PROFILES (ALL - legacy)
  // ===============================
  static Future<List<Profile>> loadProfiles() async {
    final isar = _isar ?? await getIsar();
    _isar = isar;
    return isar.collection<Profile>().where().findAll();
  }

  // ===============================
  // 🔹 LOAD PROFILES BY USER ✅ NEW
  // ===============================
  static Future<List<Profile>> loadProfilesByUser(String userId) async {
    final isar = _isar ?? await getIsar();
    _isar = isar;

    return isar
        .collection<Profile>()
        .filter()
        .userIdEqualTo(userId)
        .findAll();
  }

  // ===============================
  // 🔹 SAVE PROFILE (legacy)
  // ===============================
  static Future<void> saveProfile(Profile profile) async {
    final isar = _isar ?? await getIsar();
    _isar = isar;

    await isar.writeTxn(() async {
      final id = await isar.collection<Profile>().put(profile);
      profile.id = id;
    });
  }

  // ===============================
  // 🔹 SAVE PROFILE WITH USER ✅ NEW
  // ===============================
static Future<void> saveProfileForUser(
    Profile profile, String userId) async {

  debugPrint('SAVING PROFILE FOR USER: $userId');

  final isar = _isar ?? await getIsar();
  _isar = isar;

  profile.userId = userId;

  await isar.writeTxn(() async {
    final id = await isar.collection<Profile>().put(profile);
    profile.id = id;
  });
}

  // ===============================
  // 🔹 DELETE PROFILE
  // ===============================
  static Future<void> deleteProfile(Profile profile) async {
    final isar = _isar ?? await getIsar();
    _isar = isar;

    await isar.writeTxn(() async {
      if (profile.id != 0) {
        await isar.collection<Profile>().delete(profile.id);
        return;
      }

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