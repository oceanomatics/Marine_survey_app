import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/utils/page2_legal_text.dart';

ReportOutput _output({
  required OutputType outputType,
  int sequenceNo = 1,
  String? supersedesVersion,
}) =>
    ReportOutput(
      outputId: 'o1',
      caseId: 'c1',
      outputType: outputType,
      status: ReportStatus.draft,
      sections: const [],
      sequenceNo: sequenceNo,
      supersedesVersion: supersedesVersion,
    );

void main() {
  group('buildVersionSupersedesStatement', () {
    test('first-ever report (no supersedesVersion) returns null', () {
      expect(
          buildVersionSupersedesStatement(
              _output(outputType: OutputType.preliminary)),
          isNull);
    });

    test('Final report supersedes-all statement', () {
      final text = buildVersionSupersedesStatement(_output(
        outputType: OutputType.final_,
        sequenceNo: 3,
        supersedesVersion: 'R002',
      ));
      expect(
          text,
          'This Final Report (R003) supersedes all prior preliminary, '
          'advice, and progress reports issued in respect of this '
          'casualty.');
    });

    test('preliminary report supplements statement', () {
      final text = buildVersionSupersedesStatement(_output(
        outputType: OutputType.preliminary,
        sequenceNo: 2,
        supersedesVersion: 'R001',
      ));
      expect(
          text,
          'This report (R002) supplements Report R001 issued previously '
          'in respect of this casualty.');
    });

    test('advice report supplements statement', () {
      final text = buildVersionSupersedesStatement(_output(
        outputType: OutputType.advice,
        sequenceNo: 2,
        supersedesVersion: 'R001',
      ));
      expect(
          text,
          'This report (R002) supplements Report R001 issued previously '
          'in respect of this casualty.');
    });
  });
}
