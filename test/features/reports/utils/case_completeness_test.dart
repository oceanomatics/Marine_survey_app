// §4.3 (13 July 2026): case-wide completeness evaluation.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/utils/case_completeness.dart';

CaseCompleteness _all(bool value) => computeCaseCompleteness(
      hasVesselName: value,
      hasOccurrence: value,
      hasDamageItems: value,
      hasAttendance: value,
      signedOff: value,
      hasCertificates: value,
      hasRepairPeriods: value,
      hasAccounts: value,
      hasDocumentation: value,
      hasReportOutput: value,
    );

void main() {
  group('computeCaseCompleteness', () {
    test('a brand new case (nothing populated) is not fully complete', () {
      final result = _all(false);
      expect(result.isFullyComplete, isFalse);
      expect(result.requiredComplete, 0);
      expect(result.requiredTotal, 5);
    });

    test('everything populated is fully complete', () {
      final result = _all(true);
      expect(result.isFullyComplete, isTrue);
      expect(result.requiredComplete, result.requiredTotal);
    });

    test('optional sections (accounts, documentation, repair periods, '
        'certificates, report output) never block completeness', () {
      final result = computeCaseCompleteness(
        hasVesselName: true,
        hasOccurrence: true,
        hasDamageItems: true,
        hasAttendance: true,
        signedOff: true,
        hasCertificates: false,
        hasRepairPeriods: false,
        hasAccounts: false,
        hasDocumentation: false,
        hasReportOutput: false,
      );
      expect(result.isFullyComplete, isTrue);
    });

    test('missing a single required section (sign-off) is enough to not be '
        'complete, even with everything optional populated', () {
      final result = computeCaseCompleteness(
        hasVesselName: true,
        hasOccurrence: true,
        hasDamageItems: true,
        hasAttendance: true,
        signedOff: false,
        hasCertificates: true,
        hasRepairPeriods: true,
        hasAccounts: true,
        hasDocumentation: true,
        hasReportOutput: true,
      );
      expect(result.isFullyComplete, isFalse);
      expect(result.requiredComplete, 4);
      expect(result.requiredTotal, 5);
    });

    test('sections list includes both required and optional entries, with '
        'the required flag correctly set for the caller to filter on', () {
      final result = _all(true);
      expect(result.sections, hasLength(10));
      expect(result.sections.where((s) => s.required), hasLength(5));
      expect(result.sections.where((s) => !s.required), hasLength(5));
    });
  });

  // §4.4: completeFor() is how ChecklistItem.linkedSection drives auto-tick
  // without that feature reaching into this class's internals.
  group('CaseCompleteness.completeFor', () {
    test('returns the matching section\'s complete flag by key', () {
      final result = computeCaseCompleteness(
        hasVesselName: true,
        hasOccurrence: false,
        hasDamageItems: false,
        hasAttendance: false,
        signedOff: false,
        hasCertificates: false,
        hasRepairPeriods: false,
        hasAccounts: false,
        hasDocumentation: false,
        hasReportOutput: false,
      );
      expect(result.completeFor('vessel_particulars'), isTrue);
      expect(result.completeFor('occurrence'), isFalse);
    });

    test('an existing linkedSection value the checklist already uses for '
        'navigation ("damage_description") resolves to Extent of Damage',
        () {
      final result = computeCaseCompleteness(
        hasVesselName: false,
        hasOccurrence: false,
        hasDamageItems: true,
        hasAttendance: false,
        signedOff: false,
        hasCertificates: false,
        hasRepairPeriods: false,
        hasAccounts: false,
        hasDocumentation: false,
        hasReportOutput: false,
      );
      expect(result.completeFor('damage_description'), isTrue);
    });

    test('an unknown key (e.g. "cover", or "attended_site" with no clean '
        'data signal) returns null — no auto-tick rule, not "incomplete"',
        () {
      final result = _all(true);
      expect(result.completeFor('cover'), isNull);
      expect(result.completeFor('attended_site'), isNull);
    });
  });
}
