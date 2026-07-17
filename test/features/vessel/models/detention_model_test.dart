import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/vessel/models/detention_model.dart';

void main() {
  group('DetentionModel', () {
    test('fromJson parses all fields', () {
      final d = DetentionModel.fromJson(const {
        'detention_id': 'd1',
        'vessel_id': 'v1',
        'detained_date': '2023-05-10',
        'released_date': '2023-05-14',
        'port': 'Newcastle, AU',
        'authority': 'AMSA (Tokyo MoU)',
        'reason': 'Deficient lifesaving appliances',
        'resolved': true,
      });

      expect(d.detentionId, 'd1');
      expect(d.detainedDate, DateTime(2023, 5, 10));
      expect(d.releasedDate, DateTime(2023, 5, 14));
      expect(d.port, 'Newcastle, AU');
      expect(d.authority, 'AMSA (Tokyo MoU)');
      expect(d.reason, 'Deficient lifesaving appliances');
      expect(d.resolved, isTrue);
    });

    test('resolved defaults to false and optional dates may be null', () {
      final d = DetentionModel.fromJson(const {
        'detention_id': 'd2',
        'vessel_id': 'v1',
        'detained_date': '2024-01-01',
      });
      expect(d.resolved, isFalse);
      expect(d.releasedDate, isNull);
      expect(d.port, isNull);
    });

    test('toJson only includes populated optional fields', () {
      final d = DetentionModel(
        detentionId: 'd3',
        vesselId: 'v1',
        detainedDate: DateTime(2022, 12, 1),
        resolved: false,
      );
      final j = d.toJson();
      expect(j['vessel_id'], 'v1');
      expect(j['detained_date'], '2022-12-01');
      expect(j['resolved'], false);
      expect(j.containsKey('released_date'), isFalse);
      expect(j.containsKey('port'), isFalse);
    });
  });
}
