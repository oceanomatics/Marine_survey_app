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
}
