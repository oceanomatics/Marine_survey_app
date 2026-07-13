import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/utils/export_validation.dart';

ReportSection _section(SectionType type, String content, {bool approved = true}) =>
    ReportSection(
      type: type,
      title: type.toString(),
      content: content,
      surveyorReview: approved ? SurveyorReview.reviewedAccepted : null,
    );

/// A fully-compliant baseline: every gate the function checks is satisfied,
/// so [buildExportWarnings] should return no warnings. Individual tests
/// override just the one condition under test.
Map<SectionType, ReportSection> _completeSections() => {
      SectionType.vesselParticulars: _section(SectionType.vesselParticulars, 'Vessel details.'),
      SectionType.occurrence: _section(SectionType.occurrence, 'Reportedly ran aground.'),
      SectionType.waiver: _section(SectionType.waiver, 'Standard waiver text.'),
      SectionType.damageDescription: _section(SectionType.damageDescription, 'Dented plating.'),
      SectionType.causation: _section(SectionType.causation, 'Grounding due to navigational error.'),
    };

ReportOutput _output({bool adviceConfirmed = true}) => ReportOutput(
      outputId: 'o1',
      caseId: 'c1',
      outputType: OutputType.advice,
      status: ReportStatus.draft,
      sections: const [],
      adviceConfirmed: adviceConfirmed,
    );

AssembledReportData _assembled({
  List<Map<String, dynamic>> damageItems = const [],
  List<Map<String, dynamic>> occurrences = const [],
}) =>
    AssembledReportData(
      caseData: const {},
      vessel: null,
      occurrences: occurrences,
      damageItems: damageItems,
      attendees: const [],
      attendances: const [],
      certificates: const [],
      repairPeriods: const [],
      clauses: const [],
      outputFormat: 'oceano_services',
      repairDocuments: const [],
      timelineEvents: const [],
      surveyorNotes: const [],
      machinery: const [],
      classConditions: const [],
      caseDocuments: const [],
      requestedDocuments: const [],
      photos: const [],
      aiGenerationLog: const [],
      allReportOutputs: const [],
    );

void main() {
  group('buildExportWarnings', () {
    test('a fully-compliant report produces no warnings', () {
      final warnings = buildExportWarnings(_output(), _completeSections(), _assembled());
      expect(warnings, isEmpty);
    });

    test('flags when not every section has been approved', () {
      final sections = _completeSections();
      sections[SectionType.vesselParticulars] =
          _section(SectionType.vesselParticulars, 'Vessel details.', approved: false);
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), contains(contains('approved')));
    });

    test('flags when the Advice Summary has not been confirmed', () {
      final warnings =
          buildExportWarnings(_output(adviceConfirmed: false), _completeSections(), _assembled());
      expect(warnings.map((w) => w.message), contains(contains('Advice Summary')));
    });

    test('flags an empty Vessel\'s Particulars section', () {
      final sections = _completeSections();
      sections.remove(SectionType.vesselParticulars);
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), contains(contains("Vessel's Particulars")));
    });

    test('flags an empty Occurrence section', () {
      final sections = _completeSections();
      sections.remove(SectionType.occurrence);
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), contains(contains('Occurrence section')));
    });

    test('flags an empty Waiver section', () {
      final sections = _completeSections();
      sections.remove(SectionType.waiver);
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), contains(contains('Waiver')));
    });

    test('flags recorded damage items with no Damage Description narrative', () {
      final sections = _completeSections();
      sections.remove(SectionType.damageDescription);
      final warnings = buildExportWarnings(
        _output(),
        sections,
        _assembled(damageItems: [
          {'damage_id': 'd1'},
        ]),
      );
      expect(warnings.map((w) => w.message), contains(contains('Damage Description')));
    });

    test('does not flag Damage Description when there are no damage items at all', () {
      final sections = _completeSections();
      sections.remove(SectionType.damageDescription);
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), isNot(contains(contains('Damage Description'))));
    });

    test('flags a formal allegation with no Cause Consideration narrative', () {
      final sections = _completeSections();
      sections.remove(SectionType.causation);
      final warnings = buildExportWarnings(
        _output(),
        sections,
        _assembled(occurrences: [
          {'allegation_type': 'formal_allegation'},
        ]),
      );
      expect(warnings.map((w) => w.message), contains(contains('Cause Consideration')));
    });

    test('does not flag Cause Consideration when there is no allegation', () {
      final sections = _completeSections();
      sections.remove(SectionType.causation);
      final warnings = buildExportWarnings(
        _output(),
        sections,
        _assembled(occurrences: [
          {'allegation_type': 'no_formal_allegation'},
        ]),
      );
      expect(warnings.map((w) => w.message), isNot(contains(contains('Cause Consideration'))));
    });

    test('flags sections caught by the writing style rulebook', () {
      final sections = _completeSections();
      sections[SectionType.occurrence] =
          _section(SectionType.occurrence, 'The hull was apparently damaged.');
      final warnings = buildExportWarnings(_output(), sections, _assembled());
      expect(warnings.map((w) => w.message), contains(contains('writing style rulebook')));
    });
  });
}
