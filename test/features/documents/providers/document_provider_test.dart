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

  // §4.1 (13 July 2026): pending_extraction persists the raw (un-confirmed)
  // Claude result so a background-run extraction survives navigating away.
  group('DocumentModel — extractionReadyForReview (§4.1)', () {
    test('fromJson reads pending_extraction and reports ready-for-review',
        () {
      final doc = DocumentModel.fromJson(_baseJson(overrides: {
        'extraction_status': 'ready_for_review',
        'pending_extraction': {
          'hard_fields': {'cert_number': 'ABC123'},
        },
      }));
      expect(doc.extractionReadyForReview, isTrue);
      expect(doc.pendingExtraction, {
        'hard_fields': {'cert_number': 'ABC123'},
      });
    });

    test('not ready-for-review without a stored pending_extraction payload,'
        ' even if the status column says so (defensive against drift)', () {
      final doc = DocumentModel.fromJson(
          _baseJson(overrides: {'extraction_status': 'ready_for_review'}));
      expect(doc.extractionReadyForReview, isFalse);
    });

    test('processing/failed/completed are not ready-for-review', () {
      for (final status in ['processing', 'failed', 'completed', 'pending']) {
        final doc = DocumentModel.fromJson(_baseJson(overrides: {
          'extraction_status': status,
          'pending_extraction': {'hard_fields': {}},
        }));
        expect(doc.extractionReadyForReview, isFalse,
            reason: 'status=$status should not be ready-for-review');
      }
    });

    test('copyWith(pendingExtraction: null) explicitly clears it '
        '(saveExtracted() confirm path)', () {
      const doc = DocumentModel(
        docId: 'doc-1',
        caseId: 'case-1',
        title: 'Class Certificate',
        extractionStatus: 'ready_for_review',
        pendingExtraction: {
          'hard_fields': {'cert_number': 'ABC123'},
        },
      );
      final confirmed = doc.copyWith(
        extractionStatus: 'completed',
        pendingExtraction: null,
      );
      expect(confirmed.pendingExtraction, isNull);
      expect(confirmed.extractionReadyForReview, isFalse);
    });

    test('copyWith omitting pendingExtraction preserves the existing value',
        () {
      const doc = DocumentModel(
        docId: 'doc-1',
        caseId: 'case-1',
        title: 'Class Certificate',
        pendingExtraction: {'hard_fields': {}},
      );
      final updated = doc.copyWith(title: 'Renamed');
      expect(updated.pendingExtraction, {'hard_fields': {}});
    });
  });

  // §3.14 (13 July 2026): cross-links a document back to the Correspondence
  // trail item its attachment was filed from (migration 036) — the "not an
  // orphan" fix.
  group('DocumentModel — sourceCorrespondenceId (§3.14)', () {
    test('null when the document has no correspondence origin (manual '
        'upload, requested record, etc.)', () {
      final doc = DocumentModel.fromJson(_baseJson());
      expect(doc.sourceCorrespondenceId, isNull);
    });

    test('fromJson reads source_correspondence_id', () {
      final doc = DocumentModel.fromJson(
          _baseJson(overrides: {'source_correspondence_id': 'corr-1'}));
      expect(doc.sourceCorrespondenceId, 'corr-1');
    });

    test('copyWith always preserves it — no caller ever changes a '
        "document's correspondence origin after creation", () {
      const doc = DocumentModel(
        docId: 'doc-1',
        caseId: 'case-1',
        title: 'Attachment.pdf',
        sourceCorrespondenceId: 'corr-1',
      );
      final updated = doc.copyWith(title: 'Renamed', aiExtracted: true);
      expect(updated.sourceCorrespondenceId, 'corr-1');
    });
  });
}
