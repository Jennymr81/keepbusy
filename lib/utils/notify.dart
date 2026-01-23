// lib/utils/notify.dart
import 'package:flutter/material.dart';  // <-- REQUIRED

/// Global messenger key (hook this into MaterialApp)
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Call this from anywhere (no BuildContext needed)
void showSnack(String msg) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(msg)),
  );
}