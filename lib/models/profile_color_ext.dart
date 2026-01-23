import 'package:flutter/material.dart';
import 'profile.dart';

extension ProfileColorX on Profile {
  Color get color => Color(colorValue);
  set color(Color c) => colorValue = c.value;
}