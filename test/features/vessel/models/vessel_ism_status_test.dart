import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';

void main() {
  group('VesselModel ISM status', () {
    test('fromJson parses ism_status', () {
      final v = VesselModel.fromJson(const {
        'vessel_id': 'v1',
        'name': 'MV Test',
        'ism_status': 'non_compliant',
        'isps_status': 'compliant',
      });
      expect(v.ismStatus, IspsStatus.nonCompliant);
      expect(v.ispsStatus, IspsStatus.compliant);
    });

    test('ism_status is null when absent', () {
      final v = VesselModel.fromJson(const {
        'vessel_id': 'v1',
        'name': 'MV Test',
      });
      expect(v.ismStatus, isNull);
    });

    test('toJson serialises ism_status', () {
      const v = VesselModel(
        vesselId: 'v1',
        name: 'MV Test',
        ismStatus: IspsStatus.compliant,
      );
      expect(v.toJson()['ism_status'], 'compliant');
    });

    test('applyExtraction preserves ism_status (statutory not overwritten)', () {
      const v = VesselModel(
        vesselId: 'v1',
        name: 'MV Test',
        ismStatus: IspsStatus.compliant,
      );
      final merged = v.applyExtraction(const {'imo_number': '9123456'});
      expect(merged.ismStatus, IspsStatus.compliant);
      expect(merged.imoNumber, '9123456');
    });
  });
}
