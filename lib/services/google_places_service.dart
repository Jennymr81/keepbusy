import 'package:google_place/google_place.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../secrets.dart';



class GPlaceSuggestion {
  final String description;
  final String placeId;
  GPlaceSuggestion(this.description, this.placeId);
}

class GPlaceDetails {
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  GPlaceDetails({required this.name, required this.address, this.lat, this.lng});
}

class GooglePlacesService {
  late final GooglePlace _client;
  String _sessionToken = const Uuid().v4();

  GooglePlacesService({String? apiKey}) {
    _client = GooglePlace(apiKey ?? kGooglePlacesApiKey);
  }

  /// Autocomplete predictions worldwide, with optional location bias if we can get it.
Future<List<GPlaceSuggestion>> suggest(String input) async {
  final q = input.trim();
  if (q.isEmpty) return [];

  // 1) Declare loc BEFORE the call
  LatLon? loc;

  // 2) Try to bias by current position (optional)
  try {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (svc) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition();
        loc = LatLon(p.latitude, p.longitude);
      }
    }
  } catch (_) {}

  // 3) Pass ONLY named args after the first positional 'q'
  final res = await _client.autocomplete.get(
    q,
    sessionToken: _sessionToken,   // named
    location: loc,                 // named (LatLon?)
    radius: 20000,                 // named (you can omit if loc == null)
    // types: 'establishment',     // optional filter
  );

    final preds = res?.predictions ?? [];
  return preds
      .map((p) => GPlaceSuggestion(p.description ?? '', p.placeId ?? ''))
      .where((s) => s.placeId.isNotEmpty)
      .toList();
}

  /// Resolve a placeId to name/address/coords.
  Future<GPlaceDetails?> details(String placeId) async {
    final res = await _client.details.get(placeId, sessionToken: _sessionToken);
    final r = res?.result;
    if (r == null) return null;
    final name = r.name ?? (r.vicinity ?? r.formattedAddress ?? '');
    final addr = r.formattedAddress ?? r.vicinity ?? r.name ?? '';
    final loc = r.geometry?.location;
    return GPlaceDetails(
      name: name,
      address: addr,
      lat: loc?.lat?.toDouble(),
      lng: loc?.lng?.toDouble(),
    );
  }

  /// Call this when the user finishes a search flow, to start a fresh billing session next time.
  void startNewSession() {
    _sessionToken = const Uuid().v4();
  }
}
