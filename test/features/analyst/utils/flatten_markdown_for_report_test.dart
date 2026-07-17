import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/analyst/utils/flatten_markdown_for_report.dart';

void main() {
  group('flattenMarkdownForReport', () {
    test('strips bold/italic/code markers', () {
      final out = flattenMarkdownForReport(
          'The **main engine** was found to be *heavily* corroded, per `LOG-4`.');
      expect(out, 'The main engine was found to be heavily corroded, per LOG-4.');
    });

    test('converts a heading to an upper-case line', () {
      final out = flattenMarkdownForReport('## Findings\nSome text.');
      expect(out, 'FINDINGS\nSome text.');
    });

    test('converts a bullet list to bullet-point lines', () {
      final out = flattenMarkdownForReport('- First item\n- Second item');
      expect(out, '• First item\n• Second item');
    });

    test('preserves a markdown table as a clean table block so it can export '
        'as a real Word table (house-style item 20)', () {
      const table = '| Component | Assessment |\n'
          '|---|---|\n'
          '| Main engine | Wear consistent with age |\n'
          '| Rudder stock | Fractured |';
      final out = flattenMarkdownForReport(table);
      expect(
        out,
        '| Component | Assessment |\n'
        '| --- | --- |\n'
        '| Main engine | Wear consistent with age |\n'
        '| Rudder stock | Fractured |',
      );
    });

    test('table sandwiched between prose keeps blank-line isolation', () {
      const md = 'Intro sentence.\n'
          '| A | B |\n'
          '|---|---|\n'
          '| 1 | 2 |\n'
          'Closing sentence.';
      final out = flattenMarkdownForReport(md);
      expect(
        out,
        'Intro sentence.\n\n'
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 | 2 |\n\n'
        'Closing sentence.',
      );
    });

    test('leaves plain prose untouched', () {
      const prose = 'The vessel sustained damage to the port bow.';
      expect(flattenMarkdownForReport(prose), prose);
    });
  });
}
