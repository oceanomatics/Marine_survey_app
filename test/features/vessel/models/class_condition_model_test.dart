import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/vessel/models/class_condition_model.dart';

void main() {
  group('ClassConditionModel', () {
    test('fromJson parses issued_date, status and duration', () {
      final c = ClassConditionModel.fromJson(const {
        'condition_id': 'c1',
        'vessel_id': 'v1',
        'reference': 'MC-2024-001',
        'description': 'Renew wasted plating in way of frame 42.',
        'issued_date': '2024-03-01',
        'expiry_date': '2024-09-01',
        'duration': '6 months',
        'status': 'closed',
        'occurrence_related': true,
        'occurrence_id': 'o9',
      });

      expect(c.issuedDate, DateTime(2024, 3, 1));
      expect(c.expiryDate, DateTime(2024, 9, 1));
      expect(c.duration, '6 months');
      expect(c.status, 'closed');
      expect(c.isClosed, isTrue);
      expect(c.occurrenceRelated, isTrue);
      expect(c.occurrenceId, 'o9');
    });

    test('status defaults to open when absent', () {
      final c = ClassConditionModel.fromJson(const {
        'condition_id': 'c2',
        'vessel_id': 'v1',
      });
      expect(c.status, 'open');
      expect(c.isClosed, isFalse);
      expect(c.issuedDate, isNull);
    });

    test('toJson round-trips issued_date + status', () {
      final c = ClassConditionModel(
        conditionId: 'c3',
        vesselId: 'v1',
        issuedDate: DateTime(2025, 1, 15),
        expiryDate: DateTime(2025, 7, 15),
        status: 'closed',
      );
      final j = c.toJson();
      expect(j['issued_date'], '2025-01-15');
      expect(j['expiry_date'], '2025-07-15');
      expect(j['status'], 'closed');
    });

    test('copyWith preserves untouched fields and overrides given ones', () {
      final c = ClassConditionModel(
        conditionId: 'c4',
        vesselId: 'v1',
        status: 'open',
        issuedDate: DateTime(2024, 2, 2),
      );
      final updated = c.copyWith(status: 'closed');
      expect(updated.status, 'closed');
      expect(updated.issuedDate, DateTime(2024, 2, 2));
      expect(updated.conditionId, 'c4');
    });
  });
}
