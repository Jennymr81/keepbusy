import 'dart:io';
import 'package:flutter/widgets.dart';

const String kEventFallback   = 'assets/placeholders/event.jpg';
const String kProfileFallback = 'assets/placeholders/profile.jpg'; 

ImageProvider<Object> profileImageProvider(String? path) {
  final p = path?.trim();
  if (p == null || p.isEmpty) return const AssetImage(kProfileFallback);
  if (p.startsWith('http'))   return NetworkImage(p);
  if (p.startsWith('assets/'))return AssetImage(p);
  final f = File(p);
  return f.existsSync() ? FileImage(f) : const AssetImage(kProfileFallback);
}

ImageProvider<Object> eventImageProvider(dynamic event) {
  // Accepts your Event or just its imagePath string
  final String? p = (event is String) ? event : event?.imagePath;
  if (p == null || p.trim().isEmpty) return const AssetImage(kEventFallback);
  if (p.startsWith('http'))   return NetworkImage(p);
  if (p.startsWith('assets/'))return AssetImage(p);
  final f = File(p);
  return f.existsSync() ? FileImage(f) : const AssetImage(kEventFallback);
}
