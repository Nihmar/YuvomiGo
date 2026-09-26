import 'package:flutter/material.dart';

/// Converte un colore `#RRGGBB` in [Color]; null se il valore non è valido.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}
