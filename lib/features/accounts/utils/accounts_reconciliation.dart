// lib/features/accounts/utils/accounts_reconciliation.dart
//
// Pure reconciliation model for the Accounts summary.
//
// The problem this solves: the summary used to show per-occurrence *approved*
// totals (e.g. AUD 3,400 + 40,976) alongside a "Total (gross)" of AUD 2,008,013
// with no explanation of the gap — the difference was hidden in "32 lines
// pending review" and "32 lines not allocated to an occurrence".
//
// This model partitions every submitted account line into exactly one of four
// mutually-exclusive gross buckets so the numbers tie out:
//
//     Σ per-occurrence allocated
//   +   unallocated   (reviewed, no occurrence)
//   +   unreviewed    (pending review / queried)
//   +   rejected
//   = itemised total  (Σ of all line gross amounts, in base currency)
//
// Document totals (what was *submitted* to the insurer) may exceed the sum of
// extracted line items (e.g. an invoice with a headline total but no itemised
// breakdown). That difference is surfaced as [unitemisedBalance] so the four
// buckets plus the balance reconcile to [submittedTotal] — every dollar is
// accounted for.
//
// All money is normalised to the case base currency using each line's locked
// [AccountLineModel.baseCurrencyAmount] / [AccountLineModel.fxRateToBase] when
// available. Lines in a foreign currency that have *not* been converted are
// still counted at face value but flagged via [hasUnconvertedForeign] so the UI
// can warn rather than silently mislabel them.

import '../models/accounts_models.dart';

/// Lightweight occurrence reference (decoupled from the survey feature so this
/// util stays trivially testable).
class ReconOccurrence {
  const ReconOccurrence({required this.id, required this.label});
  final String id;
  final String label;
}

/// A single line surfaced in a review list (unreviewed / rejected).
class ReconLine {
  const ReconLine({
    required this.line,
    required this.documentName,
    required this.baseAmount,
    required this.currency,
  });

  final AccountLineModel line;
  final String documentName;

  /// Gross amount normalised to the case base currency.
  final double baseAmount;

  /// Base currency the [baseAmount] is expressed in.
  final String currency;

  bool get isForeignUnconverted =>
      line.invoiceCurrency != null &&
      line.invoiceCurrency != currency &&
      line.baseCurrencyAmount == null;
}

/// One reconciled per-occurrence allocation bucket.
class OccurrenceBucket {
  const OccurrenceBucket({
    required this.occurrenceId,
    required this.label,
    required this.gross,
  });
  final String occurrenceId;
  final String label;
  final double gross;
}

class AccountsReconciliation {
  const AccountsReconciliation({
    required this.currency,
    required this.occurrenceBuckets,
    required this.unallocated,
    required this.unreviewed,
    required this.rejected,
    required this.itemisedTotal,
    required this.submittedTotal,
    required this.unreviewedLines,
    required this.rejectedLines,
    required this.hasUnconvertedForeign,
    required this.lineCount,
    this.estimate,
    this.budgetEstimate,
    this.estimateCurrency,
  });

  /// Base currency all figures are expressed in.
  final String currency;

  /// Reviewed lines allocated to an occurrence, grouped by occurrence.
  final List<OccurrenceBucket> occurrenceBuckets;

  /// Reviewed lines with no occurrence link.
  final double unallocated;

  /// Lines still pending review / queried.
  final double unreviewed;

  /// Rejected lines.
  final double rejected;

  /// Σ of all submitted line gross amounts (base currency).
  final double itemisedTotal;

  /// Σ of submitted document totals (base currency) — what was billed.
  final double submittedTotal;

  final List<ReconLine> unreviewedLines;
  final List<ReconLine> rejectedLines;

  /// True when at least one foreign-currency line could not be converted.
  final bool hasUnconvertedForeign;

  /// Number of submitted account lines considered.
  final int lineCount;

  /// Surveyor's headline estimate (from the Cost Estimate tab), if entered.
  final double? estimate;

  /// Roll-up of repair-period budget-item estimates, if any.
  final double? budgetEstimate;

  /// Currency the estimate figures are expressed in.
  final String? estimateCurrency;

  double get allocatedTotal =>
      occurrenceBuckets.fold(0.0, (s, b) => s + b.gross);

  /// Difference between what was submitted and what has been itemised into
  /// lines. Positive = document totals exceed extracted lines (not itemised);
  /// negative = lines exceed document totals (over-itemised / data mismatch).
  double get unitemisedBalance => submittedTotal - itemisedTotal;

  /// Sum of the four buckets plus the unitemised balance. Equals
  /// [submittedTotal] by construction.
  double get reconciledTotal =>
      allocatedTotal + unallocated + unreviewed + rejected + unitemisedBalance;

  /// Should be ~0 — guards the reconciliation identity.
  double get residual => submittedTotal - reconciledTotal;

  bool get reconciles => residual.abs() < 0.01;

  int get unreviewedCount => unreviewedLines.length;
  int get rejectedCount => rejectedLines.length;

  /// Best-available effective estimate for an Estimate-vs-Actual headline:
  /// the surveyor's figure if set, otherwise the budget roll-up.
  double? get effectiveEstimate => estimate ?? budgetEstimate;

  /// Variance of actual submitted vs the effective estimate (actual - est).
  double? get estimateVariance {
    final e = effectiveEstimate;
    return e == null ? null : submittedTotal - e;
  }

  static bool _isRejected(AccountLineModel l) =>
      l.status == LineItemStatus.rejected;

  static bool _isUnreviewed(AccountLineModel l) =>
      l.status == LineItemStatus.pendingReview ||
      l.status == LineItemStatus.queried;

  /// Normalise a line's gross to base currency. Prefers the locked
  /// [baseCurrencyAmount]; falls back to grossAmount at face value.
  static double baseAmountOf(AccountLineModel l) =>
      l.baseCurrencyAmount ?? l.grossAmount;

  static bool _isForeignUnconverted(AccountLineModel l, String base) =>
      l.invoiceCurrency != null &&
      l.invoiceCurrency != base &&
      l.baseCurrencyAmount == null;

  /// Build a reconciliation from the *submitted-to-insurer* documents only.
  factory AccountsReconciliation.build({
    required List<RepairDocumentModel> docs,
    required List<ReconOccurrence> occurrences,
    required String baseCurrency,
    double? estimate,
    double? budgetEstimate,
    String? estimateCurrency,
  }) {
    final submitted = docs.where((d) => d.submittedToInsurance).toList();

    final occOrder = <String>[for (final o in occurrences) o.id];
    final occLabel = {for (final o in occurrences) o.id: o.label};
    final occGross = <String, double>{};

    double unallocated = 0, unreviewed = 0, rejected = 0, itemised = 0;
    final unreviewedLines = <ReconLine>[];
    final rejectedLines = <ReconLine>[];
    bool unconverted = false;
    int lineCount = 0;

    // Map each document to a rate for its headline total (from its lines).
    double submittedTotal = 0;
    for (final doc in submitted) {
      // ── Document headline total, converted to base ──────────────────────
      final docTotal = doc.totalIncTax ?? 0;
      if (docTotal != 0) {
        if (doc.currency == baseCurrency) {
          submittedTotal += docTotal;
        } else {
          final rate = doc.accountLines
              .map((l) => l.fxRateToBase)
              .firstWhere((r) => r != null, orElse: () => null);
          if (rate != null) {
            submittedTotal += docTotal * rate;
          } else {
            submittedTotal += docTotal; // face value
            unconverted = true;
          }
        }
      }

      // ── Per-line partitioning ───────────────────────────────────────────
      for (final l in doc.accountLines) {
        lineCount++;
        final amt = baseAmountOf(l);
        itemised += amt;
        if (_isForeignUnconverted(l, baseCurrency)) unconverted = true;

        if (_isRejected(l)) {
          rejected += amt;
          rejectedLines.add(ReconLine(
            line: l,
            documentName: doc.effectiveName,
            baseAmount: amt,
            currency: baseCurrency,
          ));
        } else if (_isUnreviewed(l)) {
          unreviewed += amt;
          unreviewedLines.add(ReconLine(
            line: l,
            documentName: doc.effectiveName,
            baseAmount: amt,
            currency: baseCurrency,
          ));
        } else {
          // Reviewed (approved / apportioned / betterment).
          final occId = l.occurrenceId;
          if (occId != null && occLabel.containsKey(occId)) {
            occGross[occId] = (occGross[occId] ?? 0) + amt;
          } else {
            unallocated += amt;
          }
        }
      }
    }

    final buckets = <OccurrenceBucket>[
      for (final id in occOrder)
        if ((occGross[id] ?? 0).abs() > 0.005)
          OccurrenceBucket(
            occurrenceId: id,
            label: occLabel[id] ?? id,
            gross: occGross[id]!,
          ),
    ];

    return AccountsReconciliation(
      currency: baseCurrency,
      occurrenceBuckets: buckets,
      unallocated: unallocated,
      unreviewed: unreviewed,
      rejected: rejected,
      itemisedTotal: itemised,
      submittedTotal: submittedTotal,
      unreviewedLines: unreviewedLines,
      rejectedLines: rejectedLines,
      hasUnconvertedForeign: unconverted,
      lineCount: lineCount,
      estimate: estimate,
      budgetEstimate: budgetEstimate,
      estimateCurrency: estimateCurrency ?? baseCurrency,
    );
  }
}
