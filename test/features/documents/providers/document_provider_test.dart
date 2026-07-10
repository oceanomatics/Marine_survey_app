// §3.4/§2.15 (10 July 2026): DocumentModel.includedInReport — the surveyor's
// chosen design (separate boolean, not a new DocAvailability enum value)
// distinguishing "enclosed in the exported report" from "retained on file
// but not enclosed".
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';

Map<String, dynamic> _baseJson({Map<String, dynamic>? overrides}) => {
      'doc_id': 'doc-1',
      'case_id': 'case-1',
      'title': 'Class Certificate',
      'availability': 'enclosed',
      ...?overrides,
    };

void main() {
  group('DocumentModel.fromJson — includedInReport', () {
    test('defaults to true when the key is missing (pre-migration rows)',
        () {
      final doc = DocumentModel.fromJson(_baseJson());
      expect(doc.includedInReport, isTrue);
    });

    test('reads included_in_report: false correctly', () {
      final doc = DocumentModel.fromJson(
          _baseJson(overrides: {'included_in_report': false}));
      expect(doc.includedInReport, isFalse);
    });

    test('reads included_in_report: true correctly', () {
      final doc = DocumentModel.fromJson(
          _baseJson(overrides: {'included_in_report': true}));
      expect(doc.includedInReport, isTrue);
    });
  });

  group('DocumentModel.copyWith', () {
    const doc = DocumentModel(
      docId: 'doc-1',
      caseId: 'case-1',
      title: 'Class Certificate',
      availability: DocAvailability.enclosed,
      includedInReport: true,
    );

    test('includedInReport can be toggled off', () {
      final updated = doc.copyWith(includedInReport: false);
      expect(updated.includedInReport, isFalse);
      // Unrelated fields untouched.
      expect(updated.availability, DocAvailability.enclosed);
      expect(updated.title, 'Class Certificate');
    });

    test('availability can be changed (requested -> enclosed, "mark as '
        'received") independent of includedInReport', () {
      const requested = DocumentModel(
        docId: 'doc-2',
        caseId: 'case-1',
        title: 'Owner Manual',
        availability: DocAvailability.requested,
      );
      final received = requested.copyWith(
          availability: DocAvailability.enclosed, includedInReport: true);
      expect(received.availability, DocAvailability.enclosed);
      expect(received.includedInReport, isTrue);
    });

    test('omitting includedInReport preserves the existing value', () {
      final updated = doc.copyWith(title: 'Renamed');
      expect(updated.includedInReport, isTrue);
    });
  });
}
