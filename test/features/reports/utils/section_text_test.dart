import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/section_text.dart';

void main() {
  group('splitSectionParagraphs', () {
    test('splits on blank lines and drops empties', () {
      expect(splitSectionParagraphs('a\n\n\nb\n\n  '), ['a', 'b']);
    });
  });

  group('tryParseMarkdownTable', () {
    test('ordinary prose is not a table', () {
      expect(tryParseMarkdownTable('Just a sentence with no pipes.'), isNull);
      expect(
          tryParseMarkdownTable('A line | with a pipe\nbut no separator row'),
          isNull);
    });

    test('parses a GFM table, dropping the separator row', () {
      final rows = tryParseMarkdownTable(
          '| Item | Qty |\n| --- | --- |\n| Bolt | 4 |\n| Nut | 8 |');
      expect(rows, isNotNull);
      expect(rows!.length, 3);
      expect(rows[0], ['Item', 'Qty']);
      expect(rows[1], ['Bolt', '4']);
      expect(rows[2], ['Nut', '8']);
    });

    test('handles tables without outer leading/trailing pipes', () {
      final rows = tryParseMarkdownTable('Name | Role\n--- | ---\nSmith | C/E');
      expect(rows, isNotNull);
      expect(rows![0], ['Name', 'Role']);
      expect(rows[1], ['Smith', 'C/E']);
    });

    test('pads ragged rows to a uniform width', () {
      final rows = tryParseMarkdownTable(
          '| A | B | C |\n|---|---|---|\n| 1 | 2 |');
      expect(rows, isNotNull);
      expect(rows![1], ['1', '2', '']);
    });

    test('a header + separator with no body rows is not a table', () {
      expect(tryParseMarkdownTable('| A | B |\n| --- | --- |'), isNull);
    });

    test('requires a separator row to qualify', () {
      expect(
          tryParseMarkdownTable('| A | B |\n| 1 | 2 |\n| 3 | 4 |'), isNull);
    });
  });
}
