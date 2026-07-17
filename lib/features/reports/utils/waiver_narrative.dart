// lib/features/reports/utils/waiver_narrative.dart
//
// report_builder_house_style_mods.md item 10 (R8/R9): the Waiver / Limitation
// of Liability section is auto-generated from the "ticks" of the relevant
// sections using the legal-clauses library (docs/legal_clauses.md), rather
// than being a single static clause or free org text. A report's limitation
// basis is not one fixed sentence — it depends on the actual state of the
// case: whether a formal allegation of cause has been made (Clause E-2, the
// Without-Prejudice reservation), whether the report is preliminary (may be
// supplemented), whether statutory certificates were sighted, and whether the
// cost figures are still subject to adjustment. Each such condition
// contributes one sentence; the base limitation clause is always present.
//
// Pure function, no Riverpod/Supabase — the caller resolves the DB-driven
// clause texts (org override -> clause_library -> hardcoded fallback) and
// passes them in, so this stays deterministic and unit-testable exactly like
// certification_narrative.dart.

/// Inputs that select which limitation sentences apply — each maps to a
/// "tick" already captured elsewhere in the app (allegation type, report
/// output type, certificate statuses, cost-estimate status).
class WaiverInputs {
  const WaiverInputs({
    required this.baseText,
    this.noFormalAllegation = false,
    this.isPreliminary = false,
    this.certificatesNotSighted = false,
    this.costsSubjectToAdjustment = false,
    this.withoutPrejudiceClause,
  });

  /// Base limitation clause — resolved by the caller from org `waiver_text`,
  /// the `without_prejudice` clause_library row, or the hardcoded fallback.
  final String baseText;

  /// Clause E-2 tick: no formal written allegation of cause has been made,
  /// so findings are noted Without Prejudice to Underwriters' liability.
  final bool noFormalAllegation;

  /// The report is a Preliminary/Advice output (not Final) — reserve the
  /// right to supplement or amend as further information becomes available.
  final bool isPreliminary;

  /// One or more statutory certificates were not made available for review.
  final bool certificatesNotSighted;

  /// Repair cost figures are still being compiled / are estimates, so the
  /// approved sums remain subject to adjustment.
  final bool costsSubjectToAdjustment;

  /// The full verbatim Clause E-2 text, when available from clause_library
  /// (`allegation_none`). Used in place of the built-in short reservation
  /// sentence when [noFormalAllegation] is set. Optional.
  final String? withoutPrejudiceClause;
}

/// Composes the Waiver / Limitation of Liability section text from [inputs].
/// The base limitation clause always leads; conditional sentences are then
/// appended in a fixed order for each applicable "tick".
String composeWaiverNarrative(WaiverInputs inputs) {
  final parts = <String>[];

  final base = inputs.baseText.trim();
  if (base.isNotEmpty) parts.add(base);

  if (inputs.noFormalAllegation) {
    final wp = inputs.withoutPrejudiceClause?.trim();
    if (wp != null && wp.isNotEmpty) {
      parts.add(wp);
    } else {
      parts.add('No formal written allegation of cause has been made in '
          'respect of this damage. Accordingly, the damage now found and '
          'reported upon is noted Without Prejudice to Underwriters\' '
          'liability.');
    }
  }

  if (inputs.isPreliminary) {
    parts.add('This report is issued on a preliminary basis and the '
        'Undersigned Surveyor reserves the right to supplement or amend it '
        'should further information become available.');
  }

  if (inputs.certificatesNotSighted) {
    parts.add('Where statutory certificates were not made available for '
        'review, no opinion is expressed as to their currency or validity.');
  }

  if (inputs.costsSubjectToAdjustment) {
    parts.add('Any costs and repair times noted herein are subject to '
        'adjustment in the usual manner and to the production of final '
        'supporting accounts.');
  }

  return parts.join('\n\n');
}
