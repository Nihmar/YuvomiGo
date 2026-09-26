import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/utils/color_utils.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';

void main() {
  group('dateKey', () {
    test('pads month and day', () {
      expect(dateKey(DateTime(2026, 9, 1)), '2026-09-01');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('mondayOf', () {
    test('keeps a Monday unchanged', () {
      expect(dateKey(mondayOf(DateTime(2026, 9, 7))), '2026-09-07');
    });

    test('moves a Sunday back to the week start', () {
      expect(dateKey(mondayOf(DateTime(2026, 9, 13))), '2026-09-07');
    });
  });

  group('parseHexColor', () {
    test('parses #RRGGBB with and without the hash', () {
      expect(parseHexColor('#FF9800'), const Color(0xFFFF9800));
      expect(parseHexColor('2196F3'), const Color(0xFF2196F3));
    });

    test('returns null for invalid values', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor('#FFF'), isNull);
      expect(parseHexColor('#ZZZZZZ'), isNull);
    });
  });
}
