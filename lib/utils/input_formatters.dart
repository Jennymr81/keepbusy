// lib/utils/input_formatters.dart

// lib/utils/input_formatters.dart

import 'package:flutter/services.dart';

class CurrencyFormatter extends TextInputFormatter {
  CurrencyFormatter({this.decimalDigits = 2});
  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;

    if (t.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(t)) return oldValue;
    if (t == '.') return oldValue;

    final parts = t.split('.');
    if (parts.length == 2 && parts[1].length > decimalDigits) {
      return oldValue;
    }
    return newValue;
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
    );
  }
}
