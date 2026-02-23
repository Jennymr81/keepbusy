import 'package:isar/isar.dart';

part 'event_models.g.dart';


// ==============================
// Event (main object)
// ==============================
@collection
class Event {
  Id id = Isar.autoIncrement;

  late DateTime date;
  late int profileIndex = 0;
  late String title;

DateTime? createdAt; 


  // Location
  String? locationName;
  String? address;
  String? city;
  String? state;
  String? zip;

  double? locationLat;
  double? locationLng;

  // Age / pricing defaults (can be overridden per session)
  int? ageMin;
  int? ageMax;
  double? cost;      // default cost (per week or per session – your choice)
  double? fee;
  String? feeNote;

  // Used for grouping slots into sessions in UI (not persistence)
  int? sessionIndex;

  // Text
  String? shortDescription;
  String? description;

  // Other metadata
  List<String> interests = [];
  List<String> links = [];

  // Sessions (slots)
  final slotIds = IsarLinks<EventSlot>();

  // Image
  String? imagePath;
  double? imageAlignY; // -1.0 (top) … 0.0 (center) … 1.0 (bottom)
}

// ==============================
// EventSlot (individual dates for a session)
// ==============================
@collection
class EventSlot {
  Id id = Isar.autoIncrement;

  late DateTime date;
  int? startMinutes;
  int? endMinutes;
  int? sessionIndex; // which session this slot belongs to

  // Per-session overrides
  int? ageMin;
  int? ageMax;
  double? cost;      // per-week or per-session cost for this session

  String? level;
  String? locationName; 
}
