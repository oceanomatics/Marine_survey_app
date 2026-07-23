import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/dp/models/dp_models.dart';

void main() {
  group('DP enums round-trip DB values', () {
    test('DpTestResult.fromValue', () {
      expect(DpTestResult.fromValue('not_tested'), DpTestResult.notTested);
      expect(DpTestResult.fromValue('pass'), DpTestResult.pass);
      expect(DpTestResult.fromValue(null), isNull);
      expect(DpTestResult.fromValue('bogus'), isNull);
    });

    test('DpFindingCategory.fromValue', () {
      expect(DpFindingCategory.fromValue('critical'),
          DpFindingCategory.critical);
      expect(DpFindingCategory.fromValue('observation'),
          DpFindingCategory.observation);
      expect(DpFindingCategory.fromValue(null), isNull);
    });
  });

  group('DpTestModel', () {
    test('fromJson maps test_id PK + enums + flags', () {
      final m = DpTestModel.fromJson(const {
        'test_id': 't1',
        'case_id': 'c1',
        'test_no': 26,
        'test_name': 'Network storm KM networks',
        'system': 'ICMS',
        'result': 'pass',
        'finding_category': 'observation',
        'wcf_tested': true,
        'carried_forward': false,
      });
      expect(m.testId, 't1');
      expect(m.testNo, 26);
      expect(m.result, DpTestResult.pass);
      expect(m.findingCategory, DpFindingCategory.observation);
      expect(m.wcfTested, true);
      expect(m.carriedForward, false);
    });

    test('copyWith preserves testId/caseId', () {
      const base = DpTestModel(testId: 't', caseId: 'c', testNo: 1);
      final edited = base.copyWith(result: DpTestResult.fail);
      expect(edited.testId, 't');
      expect(edited.caseId, 'c');
      expect(edited.testNo, 1);
      expect(edited.result, DpTestResult.fail);
    });
  });
}
