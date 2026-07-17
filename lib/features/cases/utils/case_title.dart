// lib/features/cases/utils/case_title.dart
//
// Single source of truth for the composite case title:
//   "JobNo – Vessel – SurveyType – Occurrence brief"
//
// Any component may be blank; blanks are skipped. The occurrence brief is
// always re-appended when present, so editing an earlier component (e.g.
// re-casing the vessel name) never drops the occurrence suffix.

/// Builds the composite case title from its components, joining the non-empty
/// parts with an en-dash. Each argument is trimmed; empty parts are omitted.
///
/// Returns an empty string only when every component is blank.
String buildCaseTitle({
  String? jobNo,
  String? vesselName,
  String? caseTypeLabel,
  String? occurrenceTitle,
}) {
  final parts = [
    jobNo?.trim() ?? '',
    vesselName?.trim() ?? '',
    caseTypeLabel?.trim() ?? '',
    occurrenceTitle?.trim() ?? '',
  ].where((p) => p.isNotEmpty);
  return parts.join(' – ');
}
