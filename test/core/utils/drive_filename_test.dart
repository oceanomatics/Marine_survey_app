import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/utils/drive_filename.dart';

void main() {
  group('buildDriveFilename', () {
    test('joins non-empty parts with " - " and appends the extension', () {
      final name = buildDriveFilename(
          ['2026-07-06', 'John Smith', 'Re Survey Report'], 'eml');
      expect(name, '2026-07-06 - John Smith - Re Survey Report.eml');
    });

    test('skips null and blank parts', () {
      final name = buildDriveFilename(['2026-07-06', null, '  ', 'Subject'], 'pdf');
      expect(name, '2026-07-06 - Subject.pdf');
    });

    test('falls back to "Untitled" when every part is empty', () {
      final name = buildDriveFilename([null, '  ', ''], 'pdf');
      expect(name, 'Untitled.pdf');
    });

    test('strips characters invalid on Windows/Drive filesystems', () {
      final name = buildDriveFilename(['A/B:C*D?E"F<G>H|I'], 'pdf');
      expect(name, 'A B C D E F G H I.pdf');
    });

    test('collapses internal whitespace including newlines and tabs', () {
      final name = buildDriveFilename(['Line1\nLine2\tLine3'], 'pdf');
      expect(name, 'Line1 Line2 Line3.pdf');
    });

    test('truncates a very long joined name to 150 chars before the extension', () {
      final longPart = 'x' * 300;
      final name = buildDriveFilename([longPart], 'pdf');
      final base = name.substring(0, name.length - '.pdf'.length);
      expect(base.length, 150);
      expect(name, endsWith('.pdf'));
    });
  });
}
