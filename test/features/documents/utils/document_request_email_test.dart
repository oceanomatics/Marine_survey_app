import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/documents/providers/document_provider.dart';
import 'package:marine_survey_app/features/documents/utils/document_request_email.dart';

CaseModel _case({String? vesselName, String? title}) => CaseModel(
      caseId: 'c1',
      technicalFileNo: 'AU-M53-056789',
      caseType: CaseType.hm,
      status: CaseStatus.open,
      vesselName: vesselName,
      title: title,
    );

DocumentModel _doc(String title, {DateTime? requestedDate}) => DocumentModel(
      docId: 'd1',
      caseId: 'c1',
      title: title,
      availability: DocAvailability.requested,
      requestedDate: requestedDate,
    );

void main() {
  group('buildDocumentRequestEmail', () {
    test('subject includes vessel name and technical file no.', () {
      final email = buildDocumentRequestEmail(
        caseModel: _case(vesselName: 'MV Southern Star'),
        requested: [_doc('Class Certificate')],
      );
      expect(email.subject,
          'Documentation Request — MV Southern Star (AU-M53-056789)');
    });

    test('falls back to case title, then technical file no., when vessel name is unset', () {
      final withTitle =
          buildDocumentRequestEmail(caseModel: _case(title: 'Fallback Title'), requested: const []);
      expect(withTitle.subject, contains('Fallback Title'));

      final withNeither = buildDocumentRequestEmail(caseModel: _case(), requested: const []);
      expect(withNeither.subject, contains('AU-M53-056789'));
    });

    test('lists every requested document by title', () {
      final email = buildDocumentRequestEmail(
        caseModel: _case(vesselName: 'MV Test'),
        requested: [_doc('Class Certificate'), _doc('Engine Logbook')],
      );
      expect(email.body, contains('Class Certificate'));
      expect(email.body, contains('Engine Logbook'));
    });

    test('includes the requested date when set', () {
      final email = buildDocumentRequestEmail(
        caseModel: _case(vesselName: 'MV Test'),
        requested: [_doc('Class Certificate', requestedDate: DateTime(2026, 7, 1))],
      );
      expect(email.body, contains('01/07/2026'));
    });

    test('empty requested list still produces a valid email shell', () {
      final email =
          buildDocumentRequestEmail(caseModel: _case(vesselName: 'MV Test'), requested: const []);
      expect(email.subject, isNotEmpty);
      expect(email.body, contains('Dear Sirs'));
    });
  });
}
