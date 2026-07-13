import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';

AccountLineModel _line(LineItemStatus status) => AccountLineModel(
      id: 'l',
      documentId: 'd',
      caseId: 'c',
      status: status,
    );

void main() {
  group('deriveInvoiceStatus', () {
    test('no lines -> pendingReview', () {
      expect(deriveInvoiceStatus(const []), DocStatus.pendingReview);
    });

    test('all lines still pending review -> pendingReview', () {
      final lines = [
        _line(LineItemStatus.pendingReview),
        _line(LineItemStatus.pendingReview),
      ];
      expect(deriveInvoiceStatus(lines), DocStatus.pendingReview);
    });

    test('any line queried -> queried, even with others decided', () {
      final lines = [
        _line(LineItemStatus.approved),
        _line(LineItemStatus.queried),
      ];
      expect(deriveInvoiceStatus(lines), DocStatus.queried);
    });

    test('every line rejected -> rejected', () {
      final lines = [_line(LineItemStatus.rejected), _line(LineItemStatus.rejected)];
      expect(deriveInvoiceStatus(lines), DocStatus.rejected);
    });

    test('every line approved -> approved', () {
      final lines = [_line(LineItemStatus.approved), _line(LineItemStatus.approved)];
      expect(deriveInvoiceStatus(lines), DocStatus.approved);
    });

    test('apportioned and betterment lines count as decided -> approved', () {
      final lines = [
        _line(LineItemStatus.apportioned),
        _line(LineItemStatus.betterment),
      ];
      expect(deriveInvoiceStatus(lines), DocStatus.approved);
    });

    test('mix of approved and rejected, no queries -> partlyApproved', () {
      final lines = [_line(LineItemStatus.approved), _line(LineItemStatus.rejected)];
      expect(deriveInvoiceStatus(lines), DocStatus.partlyApproved);
    });

    test('mix of decided and still-pending lines -> partlyApproved', () {
      final lines = [
        _line(LineItemStatus.approved),
        _line(LineItemStatus.pendingReview),
      ];
      expect(deriveInvoiceStatus(lines), DocStatus.partlyApproved);
    });

    test('queried takes precedence over an all-rejected mix', () {
      final lines = [
        _line(LineItemStatus.rejected),
        _line(LineItemStatus.rejected),
        _line(LineItemStatus.queried),
      ];
      expect(deriveInvoiceStatus(lines), DocStatus.queried);
    });
  });

  // §4.1 (13 July 2026): repair_documents gained extraction_status
  // (previously only a bare ai_extracted_at timestamp) so invoice
  // extraction — now auto-fired on import — can show
  // processing/failed/retry the same way documents.dart does.
  group('RepairDocumentModel.fromJson — extractionStatus (§4.1)', () {
    Map<String, dynamic> json({Map<String, dynamic>? overrides}) => {
          'id': 'inv-1',
          'case_id': 'case-1',
          'display_name': 'Invoice 123',
          ...?overrides,
        };

    test('null when the column is absent (pre-migration rows, or never '
        'queued)', () {
      final doc = RepairDocumentModel.fromJson(json());
      expect(doc.extractionStatus, isNull);
      expect(doc.extractionProcessing, isFalse);
      expect(doc.extractionFailed, isFalse);
    });

    test('extractionProcessing true only for "processing"', () {
      final doc = RepairDocumentModel.fromJson(
          json(overrides: {'extraction_status': 'processing'}));
      expect(doc.extractionProcessing, isTrue);
      expect(doc.extractionFailed, isFalse);
    });

    test('extractionFailed true only for "failed"', () {
      final doc = RepairDocumentModel.fromJson(
          json(overrides: {'extraction_status': 'failed'}));
      expect(doc.extractionFailed, isTrue);
      expect(doc.extractionProcessing, isFalse);
    });

    test('"completed" is neither processing nor failed', () {
      final doc = RepairDocumentModel.fromJson(
          json(overrides: {'extraction_status': 'completed'}));
      expect(doc.extractionProcessing, isFalse);
      expect(doc.extractionFailed, isFalse);
    });
  });
}
