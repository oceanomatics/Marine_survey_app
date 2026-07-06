import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';

RepairPeriodModel _period({String? startDate, String? endDate}) =>
    RepairPeriodModel.fromJson({
      'period_id': 'p1',
      'case_id': 'c1',
      'period_no': 1,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });

void main() {
  group('deriveRepairStatus', () {
    test('no periods at all -> Not yet commenced', () {
      expect(deriveRepairStatus(const []), DerivedRepairStatus.notCommenced);
    });

    test('periods exist but none has a start date -> Not yet commenced', () {
      final periods = [_period(), _period()];
      expect(deriveRepairStatus(periods), DerivedRepairStatus.notCommenced);
    });

    test('a period has started but has no end date -> Ongoing', () {
      final periods = [_period(startDate: '2026-06-01')];
      expect(deriveRepairStatus(periods), DerivedRepairStatus.ongoing);
    });

    test('one period complete, one still open -> Ongoing overall', () {
      final periods = [
        _period(startDate: '2026-06-01', endDate: '2026-06-10'),
        _period(startDate: '2026-06-15'),
      ];
      expect(deriveRepairStatus(periods), DerivedRepairStatus.ongoing);
    });

    test('every started period has an end date -> Complete', () {
      final periods = [
        _period(startDate: '2026-06-01', endDate: '2026-06-10'),
        _period(startDate: '2026-06-12', endDate: '2026-06-20'),
      ];
      expect(deriveRepairStatus(periods), DerivedRepairStatus.complete);
    });
  });
}
