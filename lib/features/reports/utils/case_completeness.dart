// lib/features/reports/utils/case_completeness.dart
//
// TODO.md §4.3 — General Survey Status / Completeness Evaluation. No
// completeness/health-score concept existed anywhere before this (confirmed
// via repo grep) — the closest thing, the Export Validation Gate (§1.7,
// export_validation.dart), only fires at export time and only checks
// report-builder-relevant sections against the *assembled* report data
// (an expensive multi-table fetch). This is deliberately lighter-weight and
// case-wide: a pure function over booleans/counts the caller already has on
// hand (Case Home already watches every provider this needs for its own
// section cards — see case_home_screen.dart's `_PseudoReport`), so it can
// render live without triggering a separate fetch.
//
// "Minimum required info per section" is a first-pass definition, not a
// spec-derived one — five sections a report cannot be meaningfully
// considered ready without (vessel identity, what happened, what was
// damaged, who attended, dual sign-off). Everything else is tracked and
// shown but doesn't count against the headline figure, since an early-stage
// case legitimately has no invoices/documents/repair periods yet. Revisit
// this required/optional split with the surveyor if it doesn't match how
// they actually think about "is this case ready."

class SectionCompleteness {
  const SectionCompleteness({
    required this.key,
    required this.label,
    required this.complete,
    required this.required,
  });

  /// Stable identifier — matches ChecklistItem.linkedSection's vocabulary
  /// (§4.4) so a checklist item can name which completeness signal
  /// auto-ticks it, without coupling to the display [label].
  final String key;
  final String label;
  final bool complete;

  /// Counted toward [CaseCompleteness.requiredTotal]/[requiredComplete].
  /// False sections are still reported (for a full breakdown) but don't
  /// affect the headline figure.
  final bool required;
}

class CaseCompleteness {
  const CaseCompleteness(this.sections);

  final List<SectionCompleteness> sections;

  /// §4.4: looks up a section's completeness by its stable [key] — null
  /// when no section has that key, meaning "no auto-tick rule", not
  /// "incomplete". Used to drive ChecklistItem auto-ticking without that
  /// feature needing to know this class's internal section list.
  bool? completeFor(String key) =>
      sections.where((s) => s.key == key).firstOrNull?.complete;

  List<SectionCompleteness> get requiredSections =>
      sections.where((s) => s.required).toList();

  int get requiredTotal => requiredSections.length;

  int get requiredComplete =>
      requiredSections.where((s) => s.complete).length;

  bool get isFullyComplete =>
      requiredTotal > 0 && requiredComplete == requiredTotal;
}

CaseCompleteness computeCaseCompleteness({
  required bool hasVesselName,
  required bool hasOccurrence,
  required bool hasDamageItems,
  required bool hasAttendance,
  required bool signedOff,
  required bool hasCertificates,
  required bool hasRepairPeriods,
  required bool hasAccounts,
  required bool hasDocumentation,
  required bool hasReportOutput,
  required bool hasBackground,
}) {
  return CaseCompleteness([
    // Keys marked "existing" already appear as ChecklistItem.linkedSection
    // navigation targets (checklist_screen.dart) — reused verbatim so those
    // items get auto-tick for free once §4.4 wires this up, no renaming.
    SectionCompleteness(
        key: 'vessel_particulars', // existing
        label: "Vessel's Particulars",
        complete: hasVesselName,
        required: true),
    SectionCompleteness(
        key: 'occurrence',
        label: 'Occurrence',
        complete: hasOccurrence,
        required: true),
    SectionCompleteness(
        key: 'damage_description', // existing
        label: 'Extent of Damage',
        complete: hasDamageItems,
        required: true),
    SectionCompleteness(
        key: 'attendance',
        label: 'Attendance & Representatives',
        complete: hasAttendance,
        required: true),
    SectionCompleteness(
        key: 'sign_off',
        label: 'Dual Sign-Off',
        complete: signedOff,
        required: true),
    SectionCompleteness(
        key: 'certificates',
        label: 'Certificates & Class',
        complete: hasCertificates,
        required: false),
    SectionCompleteness(
        key: 'repair_periods',
        label: 'Repair Periods',
        complete: hasRepairPeriods,
        required: false),
    SectionCompleteness(
        key: 'accounts',
        label: 'Accounts',
        complete: hasAccounts,
        required: false),
    SectionCompleteness(
        key: 'documentation',
        label: 'Documentation',
        complete: hasDocumentation,
        required: false),
    SectionCompleteness(
        key: 'report_output',
        label: 'Report Generated',
        complete: hasReportOutput,
        required: false),
    SectionCompleteness(
        key: 'background', // existing — checklist_templates seeds items here
        label: 'Background',
        complete: hasBackground,
        required: false),
  ]);
}
