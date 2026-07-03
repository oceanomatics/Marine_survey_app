// lib/features/reports/utils/export_validation.dart
//
// Pre-export validation checklist (TODO.md §1.7 "Export Validation Gate").
// These are soft warnings only — the two hard blocks (dual sign-off,
// unreviewed AI sections) are enforced separately in export_button.dart by
// disabling the button entirely, so this list is never asked to represent
// them as skippable.

import '../providers/report_provider.dart';

class ExportWarning {
  const ExportWarning(this.message);
  final String message;
}

List<ExportWarning> buildExportWarnings(
  ReportOutput output,
  Map<SectionType, ReportSection> sections,
  AssembledReportData assembled,
) {
  final warnings = <ExportWarning>[];

  bool isEmpty(SectionType type) =>
      (sections[type]?.content.trim() ?? '').isEmpty;

  if (!sections.values.every((s) => s.approved)) {
    warnings.add(const ExportWarning(
        'Not all sections have been approved (ACCEPTED / AMENDED / MY OWN).'));
  }

  if (!output.adviceConfirmed) {
    warnings.add(const ExportWarning(
        'Advice Summary (Page 2) has not been marked as confirmed.'));
  }

  if (isEmpty(SectionType.vesselParticulars)) {
    warnings.add(const ExportWarning("Vessel's Particulars section is empty."));
  }

  if (isEmpty(SectionType.occurrence)) {
    warnings.add(const ExportWarning('Occurrence section is empty.'));
  }

  if (isEmpty(SectionType.waiver)) {
    warnings.add(const ExportWarning(
        'Waiver section is empty — check the org config / clause library.'));
  }

  if (assembled.damageItems.isNotEmpty && isEmpty(SectionType.damageDescription)) {
    warnings.add(const ExportWarning(
        'Damage items are recorded but the Damage Description section is empty.'));
  }

  final occ = assembled.occurrences.isNotEmpty ? assembled.occurrences.first : null;
  final allegationType = occ?['allegation_type'] as String?;
  if ((allegationType == 'formal_allegation' || allegationType == 'informal_allegation') &&
      isEmpty(SectionType.causation)) {
    warnings.add(const ExportWarning(
        'An allegation has been recorded but Cause Consideration is empty.'));
  }

  return warnings;
}
