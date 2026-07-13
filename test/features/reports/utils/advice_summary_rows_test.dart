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
      caseDocuments: const [],
      requestedDocuments: const [],
      photos: const [],
      aiGenerationLog: const [],
      allReportOutputs: const [],
    );

ReportOutput _output({
  String? adviceRemarks,
  String? adviceDescriptionOfDamage,
  String? adviceNatureOfRepairs,
}) =>
    ReportOutput(
      outputId: 'o1',
      caseId: 'c1',
      outputType: OutputType.advice,
      status: ReportStatus.draft,
      sections: const [],
      adviceRemarks: adviceRemarks,
      adviceDescriptionOfDamage: adviceDescriptionOfDamage,
      adviceNatureOfRepairs: adviceNatureOfRepairs,
    );

void main() {
  group('buildAdviceSummaryRows', () {
    test('always returns the full fixed 8-row layout even with no data', () {
      final rows = buildAdviceSummaryRows(_output(), _assembled());
      expect(rows, hasLength(8));
      expect(rows.map((r) => r[0]), [
        'UCR / Reference',
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
      final rows = buildAdviceSummaryRows(_output(), _assembled());
      expect(rows[0][1], '[TBD]');
    });

    test('UCR / Reference uses the case-level claim_reference field', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {'claim_reference': 'CLM-2026-001'}),
      );
      expect(rows[0][1], 'CLM-2026-001');
    });

    test('Status of Repairs row title flips to "Sum Approved Without Prejudice" '
        'once repairs are complete', () {
      final notStarted = buildAdviceSummaryRows(_output(), _assembled());
      expect(notStarted[5][0], 'Estimated Cost of Repairs');

      final complete = buildAdviceSummaryRows(
        _output(),
        _assembled(repairPeriods: [
          {
            'period_id': 'p1', 'case_id': 'c1', 'period_no': 1,
            'start_date': '2026-01-01', 'end_date': '2026-01-10',
          },
        ]),
      );
      expect(complete[5][0], 'Sum Approved Without Prejudice');
    });

    test('estimated cost is formatted with currency and thousands separator', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {
          'base_currency': 'USD',
          'estimated_repair_cost': 125000.5,
        }),
      );
      expect(rows[5][1], contains('USD 125,000.50'));
    });

    test('Remarks includes the allegation status and any advice remarks', () {
      final rows = buildAdviceSummaryRows(
        _output(adviceRemarks: 'Follow-up survey recommended.'),
        _assembled(occurrences: [
          {'allegation_type': 'formal_allegation'},
        ]),
      );
      expect(rows[7][1], contains('Allegation made'));
      expect(rows[7][1], contains('Follow-up survey recommended.'));
    });

    test('follow-up line reflects case-level follow_up_required flag', () {
      final rows = buildAdviceSummaryRows(
        _output(),
        _assembled(caseData: {
          'follow_up_required': true,
          'follow_up_detail': 'Recheck shaft alignment',
        }),
      );
      expect(rows[7][1], contains('Follow-up attendance required: Recheck shaft alignment'));
    });

    test('Description of Damage / Nature of Repairs come from the report output, not the case', () {
      final rows = buildAdviceSummaryRows(
        _output(
          adviceDescriptionOfDamage: 'Dented shell plating port side.',
          adviceNatureOfRepairs: 'Renew and fair plating.',
        ),
        _assembled(),
      );
      expect(rows[2][1], 'Dented shell plating port side.');
      expect(rows[3][1], 'Renew and fair plating.');
    });
  });
}
