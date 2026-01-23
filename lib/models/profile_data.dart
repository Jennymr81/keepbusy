import 'package:flutter/material.dart';

class ProfileData {
  String firstName;
  String lastName;
  DateTime? birthdate;
  Color color;
  String? nickname;
  String? asset;
  Set<String> interests;

  ProfileData({
    required this.firstName,
    required this.lastName,
    required this.color,
    this.birthdate,
    this.nickname,
    this.asset,
    Set<String>? interests,
  }) : interests = interests ?? <String>{};
}
