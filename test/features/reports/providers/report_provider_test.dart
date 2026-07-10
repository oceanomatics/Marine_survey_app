// §3.4/§2.15 (10 July 2026): filterEnclosedInReportDocuments/
// filterRequestedDocuments were extracted from assembledDataProvider's
// live Supabase fetch so this filtering — which decides what actually
// ships in the exported report's "Documents Retained on File" section —
// is unit-testable independent of the network call.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';

void main() {
  group('filterEnclosedInReportDocuments', () {
    test('includes enclosed docs with included_in_report true', () {
      final docs = [
        {'availability': 'enclosed', 'included_in_report': true},
      ];
      expect(filterEnclosedInReportDocuments(docs), docs);
    });

    test('excludes enclosed docs with included_in_report false', () {
      final docs = [
        {'availability': 'enclosed', 'included_in_report': false},
      ];
      expect(filterEnclosedInReportDocuments(docs), isEmpty);
    });

    test('defaults included_in_report to true when the key is missing '
        '(pre-migration rows) — report output unchanged by migration 034',
        () {
      final docs = [
        {'availability': 'enclosed'},
      ];
      expect(filterEnclosedInReportDocuments(docs), docs);
    });

    test('excludes non-enclosed docs regardless of included_in_report', () {
      final docs = [
        {'availability': 'requested', 'included_in_report': true},
        {'availability': 'not_available', 'included_in_report': true},
        {'availability': 'tbc', 'included_in_report': true},
      ];
      expect(filterEnclosedInReportDocuments(docs), isEmpty);
    });

    test('empty input returns empty output', () {
      expect(filterEnclosedInReportDocuments(const []), isEmpty);
    });
  });

  group('filterRequestedDocuments', () {
    test('includes only requested docs', () {
      final docs = [
        {'availability': 'requested', 'title': 'A'},
        {'availability': 'enclosed', 'title': 'B'},
      ];
      expect(filterRequestedDocuments(docs), [
        {'availability': 'requested', 'title': 'A'},
      ]);
    });

    test('empty input returns empty output', () {
      expect(filterRequestedDocuments(const []), isEmpty);
    });
  });
}
