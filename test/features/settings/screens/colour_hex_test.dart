import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/settings/screens/organisation_detail_screen.dart';

void main() {
  group('colourToHex6', () {
    test('formats a navy colour as uppercase RRGGBB', () {
      expect(colourToHex6(const Color(0xFF1A3A5C)), '1A3A5C');
    });

    test('pads single-digit components with leading zero', () {
      expect(colourToHex6(const Color(0xFF010203)), '010203');
    });

    test('white and black', () {
      expect(colourToHex6(const Color(0xFFFFFFFF)), 'FFFFFF');
      expect(colourToHex6(const Color(0xFF000000)), '000000');
    });

    test('ignores alpha channel', () {
      expect(colourToHex6(const Color(0x801A3A5C)), '1A3A5C');
    });
  });
}
