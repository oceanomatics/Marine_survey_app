import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/utils/accounts_reconciliation.dart';

AccountLineModel _line({
  required String id,
  required String docId,
  double gross = 0,
  LineItemStatus status = LineItemStatus.pendingReview,
  String? occurrenceId,
  String? invoiceCurrency,
  double? baseCurrencyAmount,
  double? fxRateToBase,
  String? description,
}) =>
    AccountLineModel(
      id: id,
      documentId: docId,
      caseId: 'case1',
      grossAmount: gross,
      status: status,
      occurrenceId: occurrenceId,
      invoiceCurrency: invoiceCurrency,
      baseCurrencyAmount: baseCurrencyAmount,
      fxRateToBase: fxRateToBase,
      description: description,
    );

RepairDocumentModel _doc({
  required String id,
  double? total,
  String currency = 'AUD',
  bool submitted = true,
  List<AccountLineModel> lines = const [],
  String? name,
}) =>
    RepairDocumentModel(
      id: id,
      caseId: 'case1',
      displayName: name ?? 'Doc $id',
      currency: currency,
      totalIncTax: total,
      submittedToInsurance: submitted,
      accountLines: lines,
    );

const _occs = [
  ReconOccurrence(id: 'occ1', label: 'Occ. 1 — Grounding'),
  ReconOccurrence(id: 'occ2', label: 'Occ. 2 — Fire'),
];

void main() {
  group('AccountsReconciliation identity', () {
    test('four buckets + unitemised balance tie out to submitted total', () {
      final doc = _doc(id: 'd1', total: 1000, lines: [
        _line(id: 'l1', docId: 'd1', gross: 300, status: LineItemStatus.approved, occurrenceId: 'occ1'),
        _line(id: 'l2', docId: 'd1', gross: 200, status: LineItemStatus.apportioned, occurrenceId: 'occ2'),
        _line(id: 'l3', docId: 'd1', gross: 50, status: LineItemStatus.approved), // reviewed, no occ
        _line(id: 'l4', docId: 'd1', gross: 250, status: LineItemStatus.pendingReview),
        _line(id: 'l5', docId: 'd1', gross: 100, status: LineItemStatus.rejected),
      ]);

      final r = AccountsReconciliation.build(
        docs: [doc],
        occurrences: _occs,
        baseCurrency: 'AUD',
      );

      expect(r.allocatedTotal, 500);   // 300 + 200
      expect(r.unallocated, 50);
      expect(r.unreviewed, 250);
      expect(r.rejected, 100);
      expect(r.itemisedTotal, 900);
      expect(r.submittedTotal, 1000);
      expect(r.unitemisedBalance, 100); // 1000 - 900
      expect(r.reconciles, isTrue);
      expect(r.residual.abs() < 0.01, isTrue);
      expect(r.reconciledTotal, closeTo(1000, 0.001));
    });

    test('per-occurrence buckets are grouped and ordered', () {
      final doc = _doc(id: 'd1', total: 500, lines: [
        _line(id: 'a', docId: 'd1', gross: 100, status: LineItemStatus.approved, occurrenceId: 'occ2'),
        _line(id: 'b', docId: 'd1', gross: 400, status: LineItemStatus.approved, occurrenceId: 'occ1'),
      ]);
      final r = AccountsReconciliation.build(
        docs: [doc], occurrences: _occs, baseCurrency: 'AUD');

      expect(r.occurrenceBuckets.length, 2);
      expect(r.occurrenceBuckets.first.occurrenceId, 'occ1'); // occ order preserved
      expect(r.occurrenceBuckets.first.gross, 400);
      expect(r.occurrenceBuckets[1].gross, 100);
    });

    test('unreviewed and rejected lines are listed, not dropped', () {
      final doc = _doc(id: 'd1', total: 300, lines: [
        _line(id: 'p1', docId: 'd1', gross: 100, status: LineItemStatus.pendingReview, description: 'Pending A'),
        _line(id: 'q1', docId: 'd1', gross: 80, status: LineItemStatus.queried, description: 'Queried B'),
        _line(id: 'r1', docId: 'd1', gross: 120, status: LineItemStatus.rejected, description: 'Rejected C'),
      ]);
      final r = AccountsReconciliation.build(
        docs: [doc], occurrences: _occs, baseCurrency: 'AUD');

      expect(r.unreviewedCount, 2); // pending + queried
      expect(r.unreviewed, 180);
      expect(r.rejectedCount, 1);
      expect(r.rejected, 120);
      expect(r.unreviewedLines.map((l) => l.line.description),
          containsAll(['Pending A', 'Queried B']));
      expect(r.rejectedLines.single.line.description, 'Rejected C');
    });

    test('context (not submitted) documents are excluded', () {
      final submitted = _doc(id: 'd1', total: 500, lines: [
        _line(id: 'l1', docId: 'd1', gross: 500, status: LineItemStatus.approved, occurrenceId: 'occ1'),
      ]);
      final context = _doc(id: 'd2', total: 9999, submitted: false, lines: [
        _line(id: 'l2', docId: 'd2', gross: 9999, status: LineItemStatus.approved, occurrenceId: 'occ1'),
      ]);
      final r = AccountsReconciliation.build(
        docs: [submitted, context], occurrences: _occs, baseCurrency: 'AUD');

      expect(r.submittedTotal, 500);
      expect(r.lineCount, 1);
    });
  });

  group('Estimate vs actual', () {
    test('effective estimate prefers surveyor figure, variance computed', () {
      final doc = _doc(id: 'd1', total: 1200, lines: [
        _line(id: 'l1', docId: 'd1', gross: 1200, status: LineItemStatus.approved, occurrenceId: 'occ1'),
      ]);
      final r = AccountsReconciliation.build(
        docs: [doc], occurrences: _occs, baseCurrency: 'AUD',
        estimate: 1000, budgetEstimate: 800);

      expect(r.effectiveEstimate, 1000);
      expect(r.estimateVariance, 200); // 1200 - 1000 (over)
    });

    test('falls back to budget estimate when no surveyor figure', () {
      final r = AccountsReconciliation.build(
        docs: const [], occurrences: _occs, baseCurrency: 'AUD',
        budgetEstimate: 800);
      expect(r.effectiveEstimate, 800);
    });
  });

  group('FX handling', () {
    test('uses baseCurrencyAmount when present', () {
      final doc = _doc(id: 'd1', total: 1000, currency: 'USD', lines: [
        _line(id: 'l1', docId: 'd1', gross: 1000, status: LineItemStatus.approved,
            occurrenceId: 'occ1', invoiceCurrency: 'USD',
            fxRateToBase: 1.5, baseCurrencyAmount: 1500),
      ]);
      final r = AccountsReconciliation.build(
        docs: [doc], occurrences: _occs, baseCurrency: 'AUD');

      expect(r.allocatedTotal, 1500);          // converted
      expect(r.submittedTotal, closeTo(1500, 0.001)); // 1000 * 1.5 doc rate
      expect(r.hasUnconvertedForeign, isFalse);
    });

    test('flags unconverted foreign lines and counts them at face value', () {
      final doc = _doc(id: 'd1', total: 1000, currency: 'USD', lines: [
        _line(id: 'l1', docId: 'd1', gross: 1000, status: LineItemStatus.approved,
            occurrenceId: 'occ1', invoiceCurrency: 'USD'), // no base amount
      ]);
      final r = AccountsReconciliation.build(
        docs: [doc], occurrences: _occs, baseCurrency: 'AUD');

      expect(r.hasUnconvertedForeign, isTrue);
      expect(r.allocatedTotal, 1000); // face value
      expect(r.reconciles, isTrue);   // still ties out
    });
  });

  test('empty input reconciles trivially', () {
    final r = AccountsReconciliation.build(
      docs: const [], occurrences: _occs, baseCurrency: 'AUD');
    expect(r.submittedTotal, 0);
    expect(r.itemisedTotal, 0);
    expect(r.reconciles, isTrue);
    expect(r.occurrenceBuckets, isEmpty);
  });
}
