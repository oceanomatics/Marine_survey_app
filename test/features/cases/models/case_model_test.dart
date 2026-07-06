import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';

VesselModel _baseVessel({
  String? name,
  String? imoNumber,
  String? officialNumber,
  ClassStatus? classStatus,
}) =>
    VesselModel(
      vesselId: 'v1',
      name: name ?? 'MV Existing',
      imoNumber: imoNumber,
      officialNumber: officialNumber,
      classStatus: classStatus,
    );

void main() {
  group('VesselModel.applyExtraction (AI import smart-merge)', () {
    test('overwrites a field when the extraction provides a new value', () {
      final vessel = _baseVessel(imoNumber: null);
      final merged = vessel.applyExtraction(const {'imo_number': '9123456'});
      expect(merged.imoNumber, '9123456');
    });

    test('keeps the existing value when the extraction has no value for a field', () {
      final vessel = _baseVessel(imoNumber: '9123456');
      final merged = vessel.applyExtraction({'vessel_name': 'MV Renamed'});
      expect(merged.imoNumber, '9123456');
      expect(merged.name, 'MV Renamed');
    });

    test('numeric fields coerce num to double via extraction', () {
      const vessel = VesselModel(vesselId: 'v1', name: 'MV Existing');
      final merged = vessel.applyExtraction(const {'gross_tonnage': 1234});
      expect(merged.grossTonnage, 1234.0);
    });

    test('statutory fields are never overwritten by AI extraction, even if present in the payload', () {
      final vessel = _baseVessel(
        officialNumber: 'OFF-001',
        classStatus: ClassStatus.classed,
      );
      final merged = vessel.applyExtraction({
        'official_number': 'HACKED-999',
        'class_status': 'suspended',
      });
      expect(merged.officialNumber, 'OFF-001');
      expect(merged.classStatus, ClassStatus.classed);
    });

    test('vesselId is always preserved regardless of extraction content', () {
      final vessel = _baseVessel();
      final merged = vessel.applyExtraction({'vessel_id': 'someone-elses-id'});
      expect(merged.vesselId, 'v1');
    });
  });

  group('CaseModel.hasPlaceholderFileNo', () {
    CaseModel caseWith(String technicalFileNo) => CaseModel(
          caseId: 'c1',
          technicalFileNo: technicalFileNo,
          caseType: CaseType.hm,
          status: CaseStatus.open,
        );

    test('true for TMP- prefixed placeholder', () {
      expect(caseWith('TMP-abc123').hasPlaceholderFileNo, isTrue);
    });

    test('true for TBC literal', () {
      expect(caseWith('TBC').hasPlaceholderFileNo, isTrue);
    });

    test('true for empty string', () {
      expect(caseWith('').hasPlaceholderFileNo, isTrue);
    });

    test('false for a real technical file number', () {
      expect(caseWith('AU-M53-056789').hasPlaceholderFileNo, isFalse);
    });
  });

  group('CaseModel.driveFolderName', () {
    CaseModel baseCase({
      String technicalFileNo = 'AU-M53-056789',
      String? vesselName,
      DateTime? dateOfFirstAttendance,
      DateTime? instructionDate,
      DateTime? createdAt,
    }) =>
        CaseModel(
          caseId: 'c1',
          technicalFileNo: technicalFileNo,
          caseType: CaseType.hm,
          status: CaseStatus.open,
          vesselName: vesselName,
          dateOfFirstAttendance: dateOfFirstAttendance,
          instructionDate: instructionDate,
          createdAt: createdAt,
        );

    test('full case: "Year - TechNo - Vessel"', () {
      final c = baseCase(
        vesselName: 'MV Star',
        dateOfFirstAttendance: DateTime(2026, 3, 1),
      );
      expect(c.driveFolderName, '2026 - AU-M53-056789 - MV Star');
    });

    test('omits technical file number while it is still a placeholder', () {
      final c = baseCase(
        technicalFileNo: 'TMP-xyz',
        vesselName: 'MV Star',
        dateOfFirstAttendance: DateTime(2026, 3, 1),
      );
      expect(c.driveFolderName, '2026 - MV Star');
    });

    test('omits vessel name while unset', () {
      final c = baseCase(dateOfFirstAttendance: DateTime(2026, 3, 1));
      expect(c.driveFolderName, '2026 - AU-M53-056789');
    });

    test('omits vessel name when it is only whitespace', () {
      final c = baseCase(
        vesselName: '   ',
        dateOfFirstAttendance: DateTime(2026, 3, 1),
      );
      expect(c.driveFolderName, '2026 - AU-M53-056789');
    });

    test('year falls back through dateOfFirstAttendance -> instructionDate -> createdAt', () {
      final c = baseCase(
        instructionDate: DateTime(2025, 6, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      expect(c.driveFolderName, startsWith('2025 -'));
    });

    test('placeholder file no. and unset vessel name leaves only the year', () {
      final c = baseCase(
        technicalFileNo: 'TBC',
        dateOfFirstAttendance: DateTime(2026, 3, 1),
      );
      expect(c.driveFolderName, '2026');
    });
  });
}
