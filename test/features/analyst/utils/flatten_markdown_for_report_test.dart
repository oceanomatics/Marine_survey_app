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

    test('flattens a markdown table into one line per row, header: value', () {
      const table = '| Component | Assessment |\n'
          '|---|---|\n'
          '| Main engine | Wear consistent with age |\n'
          '| Rudder stock | Fractured |';
      final out = flattenMarkdownForReport(table);
      expect(
        out,
        'Component: Main engine — Assessment: Wear consistent with age\n'
        'Component: Rudder stock — Assessment: Fractured',
      );
    });

    test('leaves plain prose untouched', () {
      const prose = 'The vessel sustained damage to the port bow.';
      expect(flattenMarkdownForReport(prose), prose);
    });
  });
}
