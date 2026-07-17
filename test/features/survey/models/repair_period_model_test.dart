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

  group('BudgetItem quantity/unit/rate breakdown', () {
    test('round-trips qty/unit/rate through json', () {
      const item = BudgetItem(
        itemId: 'b1',
        description: 'Dry-dock hire',
        amount: 60000,
        currency: 'USD',
        quantity: 5,
        unit: 'day',
        unitRate: 12000,
      );
      final back = BudgetItem.fromJson(item.toJson());
      expect(back.quantity, 5);
      expect(back.unit, 'day');
      expect(back.unitRate, 12000);
      expect(back.amount, 60000);
      expect(back.hasBreakdown, isTrue);
      expect(back.computedAmount, 60000);
    });

    test('lump-sum line (no qty/rate) has no breakdown and omits keys', () {
      const item = BudgetItem(
        itemId: 'b2',
        description: 'Tank cleaning',
        amount: 8000,
        currency: 'USD',
      );
      final json = item.toJson();
      expect(json.containsKey('quantity'), isFalse);
      expect(json.containsKey('unit'), isFalse);
      expect(json.containsKey('unit_rate'), isFalse);
      expect(item.hasBreakdown, isFalse);
      expect(item.computedAmount, isNull);
    });

    test('copyWith can clear quantity via explicit null', () {
      const item = BudgetItem(
        itemId: 'b3',
        description: 'x',
        amount: 100,
        currency: 'USD',
        quantity: 2,
        unitRate: 50,
      );
      final cleared = item.copyWith(quantity: null, unitRate: null);
      expect(cleared.quantity, isNull);
      expect(cleared.unitRate, isNull);
      expect(cleared.hasBreakdown, isFalse);
      // untouched field preserved
      expect(cleared.amount, 100);
    });

    test('legacy json without breakdown keys still parses', () {
      final back = BudgetItem.fromJson(const {
        'id': 'b4',
        'description': 'Old line',
        'amount': 500,
        'currency': 'EUR',
        'status': 'quoted',
      });
      expect(back.quantity, isNull);
      expect(back.hasBreakdown, isFalse);
      expect(back.status, BudgetItemStatus.quoted);
    });
  });

  group('RepairCostPreset catalogue', () {
    test('catalogue is non-empty and covers every group', () {
      expect(kRepairCostPresets, isNotEmpty);
      for (final g in CostPresetGroup.values) {
        expect(kRepairCostPresets.any((p) => p.group == g), isTrue,
            reason: 'group $g should have at least one preset');
      }
    });

    test('rate-bearing preset builds an editable line with computed amount', () {
      final preset = kRepairCostPresets
          .firstWhere((p) => p.description == 'Dry-dock hire');
      final item = preset.toBudgetItem(currency: 'AUD', itemId: 'x');
      expect(item.currency, 'AUD');
      expect(item.unit, preset.unit);
      expect(item.unitRate, preset.typicalRate);
      expect(item.quantity, preset.defaultQuantity);
      expect(item.amount, preset.typicalRate! * preset.defaultQuantity);
    });

    test('quote-only preset (null rate) builds a zero-amount line', () {
      final preset = kRepairCostPresets.firstWhere((p) => p.typicalRate == null);
      final item = preset.toBudgetItem(currency: 'USD');
      expect(item.amount, 0);
      expect(item.unitRate, isNull);
      expect(item.hasBreakdown, isFalse);
    });
  });

  group('SeaTrial', () {
    test('round-trips all fields through json', () {
      final trial = SeaTrial(
        date: DateTime(2026, 7, 14),
        durationHours: 3.5,
        location: 'Off Fremantle',
        parameters: const [
          SeaTrialParameter(label: 'Engine load', value: '85 %'),
          SeaTrialParameter(label: 'Speed', value: '14.2 kn'),
        ],
        satisfactory: true,
        notes: 'No abnormal vibration.',
      );
      final back = SeaTrial.fromJson(trial.toJson());
      expect(back.date, DateTime(2026, 7, 14));
      expect(back.durationHours, 3.5);
      expect(back.location, 'Off Fremantle');
      expect(back.parameters.length, 2);
      expect(back.parameters.first.label, 'Engine load');
      expect(back.parameters.first.value, '85 %');
      expect(back.satisfactory, isTrue);
      expect(back.notes, 'No abnormal vibration.');
    });

    test('empty trial reports isEmpty and serialises to bare map', () {
      const trial = SeaTrial();
      expect(trial.isEmpty, isTrue);
      expect(trial.toJson(), isEmpty);
    });

    test('a single non-empty field makes it non-empty', () {
      const trial = SeaTrial(satisfactory: false);
      expect(trial.isEmpty, isFalse);
      expect(trial.toJson()['satisfactory'], isFalse);
    });

    test('date serialises as ISO yyyy-MM-dd', () {
      final trial = SeaTrial(date: DateTime(2026, 3, 5));
      expect(trial.toJson()['date'], '2026-03-05');
    });

    test('copyWith clears satisfactory via explicit null', () {
      const trial = SeaTrial(satisfactory: true);
      expect(trial.copyWith(satisfactory: null).satisfactory, isNull);
    });
  });

  group('RepairPeriodModel sea trial wiring', () {
    test('parses sea_trial from json and includes it in insert json', () {
      final period = RepairPeriodModel.fromJson(const {
        'period_id': 'p1',
        'case_id': 'c1',
        'period_no': 1,
        'sea_trial': {
          'date': '2026-07-14',
          'duration_hours': 2,
          'satisfactory': true,
          'parameters': [
            {'label': 'RPM', 'value': '750 rpm'}
          ],
        },
      });
      expect(period.seaTrial, isNotNull);
      expect(period.seaTrial!.satisfactory, isTrue);
      expect(period.seaTrial!.parameters.single.label, 'RPM');

      final insert = period.toInsertJson();
      expect(insert['sea_trial'], isA<Map<String, dynamic>>());
      expect(
          (insert['sea_trial'] as Map<String, dynamic>)['satisfactory'], isTrue);
    });

    test('no sea trial -> field null and omitted from insert json', () {
      final period = RepairPeriodModel.fromJson(const {
        'period_id': 'p1',
        'case_id': 'c1',
        'period_no': 1,
      });
      expect(period.seaTrial, isNull);
      expect(period.toInsertJson().containsKey('sea_trial'), isFalse);
    });

    test('copyWith replaces sea trial', () {
      final period = RepairPeriodModel.fromJson(const {
        'period_id': 'p1',
        'case_id': 'c1',
        'period_no': 1,
      });
      final updated =
          period.copyWith(seaTrial: const SeaTrial(satisfactory: false));
      expect(updated.seaTrial!.satisfactory, isFalse);
      // original untouched
      expect(period.seaTrial, isNull);
    });
  });
}
