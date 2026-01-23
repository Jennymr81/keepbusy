import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;

import 'package:keepbusy/models/event_models.dart'; // EventSchema, EventSlotSchema
import 'package:keepbusy/models/profile.dart';       // ProfileSchema

import 'package:keepbusy/models/saved_state.dart';



// Singleton future (no need for `late`)
final Future<Isar> _isarFuture = _openIsar();

Future<Isar> _openIsar() async {
  const dbName = 'keepbusy_dev4';  // 👈 fresh dev DB

  // Reuse if already open
  final existing = Isar.getInstance(dbName);
  if (existing != null && existing.isOpen) return existing;

final schemas = [EventSchema, EventSlotSchema, ProfileSchema, SavedStateSchema];

  // directory is required; on Web it's ignored, so pass an empty string
  final String dirPath = kIsWeb
      ? ''
      : (await getApplicationSupportDirectory()).path;

  return Isar.open(
    schemas,
    name: dbName,
    directory: dirPath,
    inspector: kDebugMode,
  );
}

// Public getter
Future<Isar> getIsar() => _isarFuture;
