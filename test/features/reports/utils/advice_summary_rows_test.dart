import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/utils/advice_summary_rows.dart';

AssembledReportData _assembled({
  Map<String, dynamic> caseData = const {},
  List<Map<String, dynamic>> occurrences = const [],
  List<Map<String, dynamic>> repairPeriods = const [],
}) =>
    AssembledReportData(
      caseData: caseData,
      vessel: null,
      occurrences: occurrences,
      damageItems: const [],
      attendees: const [],
      attendances: const [],
      certificates: const [],
      repairPeriods: repairPeriods,
      clauses: const [],
      outputFormat: 'oceano_services',
      repairDocuments: const [],
      timelineEvents: const [],
      surveyorNotes: const [],
      machinery: const [],
      classConditions: const [],
      detentions: const [],
      caseDocuments: const [],
      requestedDocuments: const [],
      photos: const [],
      aiGenerationLog: const [],
      allReportOutputs: const [],
    );

ReportOutput _output({String? adviceRemarks}) => ReportOutput(
      outputId: 'o1',
      caseId: 'c1',
      outputType: OutputType.advice,
      status: ReportStatus.draft,
      sections: const [],
      adviceRemarks: adviceRemarks,
    );

/// [sections] mirrors `sectionDraftProvider`'s computed state — Description
/// of Damage / Nature of Repairs are sourced from here (14 July 2026), not
/// from the report output, so they always match what the report body
/// actually shows (AI-drafted or deterministic default alike).
Map<SectionType, ReportSection> _sections({
  String? damageContent,
  String? natureContent,
}) =>
    {
      if (damageContent != null)
        SectionType.damageDescription: ReportSection(
          type: SectionType.damageDescription,
          title: 'Extent of Damage',
          content: damageContent,
        ),
      if (natureContent != null)
        SectionType.natureOfRepairs: ReportSection(
          type: SectionType.natureOfRepairs,
          title: 'Nature of the Repairs',
          content: natureContent,
        ),
    };

void main() {
  group('buildAdviceSummaryRows', () {
    test('always returns the full fixed 10-row layout even with no data', () {
      final rows = buildAdviceSummaryRows(_output(), _assembled(), _sections());
      expect(rows, hasLength(10));
      expect(rows.map((r) => r[0]), [
        'UCR / Reference',
        'Assured',
        'Instructing Party',
        'Date and Nature of Casualty',
        'Description of Damage',
        'Nature of Repairs',
        'Status of Repairs',
        'Estimated Cost of Repairs',
        'Survey Fee Reserve',
        'Remarks',
      ]);
    });

    test('UCR / Reference falls back to a [TBD] placeholder when unset', () {
      final rows = buildAdviceSummaryRows(_output(), _assembled(), _sections());
      expect(rows[0][1], '[TBD]');
    });

    test('UCR / Reference uses the case-level claim_reference field', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {'claim_reference': 'CLM-2026-001'}),
        _sections(),
      );
      expect(rows[0][1], 'CLM-2026-001');
    });

    test('Assured / Instructing Party come from case-level fields', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {
          'assured': 'Owner Co Ltd',
          'instructing_party': 'Some Underwriters',
        }),
        _sections(),
      );
      expect(rows[1][1], 'Owner Co Ltd');
      expect(rows[2][1], 'Some Underwriters');
    });

    test('Status of Repairs row title flips to "Sum Approved Without Prejudice" '
        'once repairs are complete', () {
      final notStarted =
          buildAdviceSummaryRows(_output(), _assembled(), _sections());
      expect(notStarted[7][0], 'Estimated Cost of Repairs');

      final complete = buildAdviceSummaryRows(
        _output(),
        _assembled(repairPeriods: [
          {
            'period_id': 'p1', 'case_id': 'c1', 'period_no': 1,
            'start_date': '2026-01-01', 'end_date': '2026-01-10',
          },
        ]),
        _sections(),
      );
      expect(complete[7][0], 'Sum Approved Without Prejudice');
    });

    test('estimated cost is formatted with currency and thousands separator', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {
          'base_currency': 'USD',
          'estimated_repair_cost': 125000.5,
        }),
        _sections(),
      );
      expect(rows[7][1], contains('USD 125,000.50'));
    });

    test('Remarks includes the allegation status and any advice remarks', () {
      final rows = buildAdviceSummaryRows(
        _output(adviceRemarks: 'Follow-up survey recommended.'),
        _assembled(occurrences: [
          {'allegation_type': 'formal_allegation'},
        ]),
        _sections(),
      );
      expect(rows[9][1], contains('Allegation made'));
      expect(rows[9][1], contains('Follow-up survey recommended.'));
    });

    test('follow-up line reflects case-level follow_up_required flag', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {
          'follow_up_required': true,
          'follow_up_detail': 'Recheck shaft alignment',
        }),
        _sections(),
      );
      expect(rows[9][1], contains('Follow-up attendance required: Recheck shaft alignment'));
    });

    test('Description of Damage / Nature of Repairs come from the computed '
        'report sections, not a per-report-output field', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(),
        _sections(
          damageContent: 'Dented shell plating port side.',
          natureContent: 'Renew and fair plating.',
        ),
      );
      expect(rows[4][1], 'Dented shell plating port side.');
      expect(rows[5][1], 'Renew and fair plating.');
    });

    test('Description of Damage / Nature of Repairs fall back to a pending '
        'placeholder when no section content exists yet', () {
      final rows = buildAdviceSummaryRows(_output(), _assembled(), _sections());
      expect(rows[4][1], '[description of damage — pending]');
      expect(rows[5][1], '[nature of repairs — pending]');
    });
  });
}
