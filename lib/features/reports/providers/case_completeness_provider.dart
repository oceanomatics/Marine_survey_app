// lib/features/reports/providers/case_completeness_provider.dart
//
// Single shared source of truth for CaseCompleteness (§4.3/§4.4) — watches
// every underlying provider once and computes it, instead of Case Home and
// the Checklist screen each duplicating the same watch list + call to
// computeCaseCompleteness() (found during the 2026-07-13 review: the two
// call sites had drifted into near-verbatim copies of each other).
//
// ChecklistNotifier listens to this from its build() (not from a screen's
// build()) so auto-tick reacts whenever completeness changes anywhere in
// the app, not only while the Checklist screen happens to be mounted.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/accounts_provider.dart';
import '../../attendances/providers/attendances_provider.dart';
import '../../background/providers/background_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../survey/providers/damage_provider.dart';
import '../../survey/providers/repair_period_provider.dart';
import '../../vessel/providers/certificates_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../utils/case_completeness.dart';
import 'report_provider.dart';

final caseCompletenessProvider =
    Provider.family<CaseCompleteness, String>((ref, caseId) {
  final survey = ref.watch(caseProvider(caseId)).value;
  final damage = ref.watch(damageProvider(caseId)).value;
  final visits = ref.watch(attendancesProvider(caseId)).value ?? [];
  final repairPeriods = ref.watch(repairPeriodsProvider(caseId)).value ?? [];
  final repairDocs = ref.watch(repairDocumentsProvider(caseId)).value ?? [];
  final certs = ref.watch(certificatesProvider(caseId)).value ?? [];
  final outputs = ref.watch(reportOutputsProvider(caseId)).value ?? [];
  final vessel = ref.watch(vesselForCaseProvider(caseId)).value;
  final documents = ref.watch(documentProvider(caseId)).value ?? [];
  final background = ref.watch(backgroundProvider(caseId)).value;

  return computeCaseCompleteness(
    hasVesselName: (vessel?.name ?? '').trim().isNotEmpty,
    hasOccurrence: (damage?.occurrences.isNotEmpty ?? false),
    hasDamageItems: (damage?.totalDamageItems ?? 0) > 0,
    hasAttendance: visits.isNotEmpty,
    signedOff:
        (survey?.signedOffAttending ?? false) && (survey?.signedOffReviewing ?? false),
    hasCertificates: certs.isNotEmpty,
    hasRepairPeriods: repairPeriods.isNotEmpty,
    hasAccounts: repairDocs.isNotEmpty,
    hasDocumentation: documents.isNotEmpty,
    hasReportOutput: outputs.isNotEmpty,
    hasBackground: (background?.content ?? '').trim().isNotEmpty,
  );
});
