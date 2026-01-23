import 'package:keepbusy/models/profile.dart';

// --- Profile display label (nickname-first) ---
// Uses local logic so this file doesn't depend on the exact helper name.
String profileLabel(Profile p) {
  final nick = (p.nickname ?? '').trim();
  if (nick.isNotEmpty) return nick;

  final first = p.firstName.trim();
  if (first.isNotEmpty) return first;

  return 'PROFILE';
}