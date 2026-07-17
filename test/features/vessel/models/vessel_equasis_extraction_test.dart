import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';

/// Feature 2 (Equasis autopopulate): the map returned by
/// ClaudeApi.extractEquasisText() uses keys that VesselModel.applyExtraction()
/// must recognise, so pasted Equasis text lands in the right columns. These
/// tests lock that mapping down without touching the network.
void main() {
  group('VesselModel.applyExtraction — Equasis-sourced fields', () {
    const blank = VesselModel(vesselId: 'v1', name: 'TBC');

    test('fills physical particulars from an Equasis-shaped map', () {
      final merged = blank.applyExtraction(const {
        'vessel_name': 'MINRES ODIN',
        'imo_number': '9876543',
        'flag': 'Panama',
        'class_society': 'DNV',
        'gross_tonnage': 25482,
        'net_tonnage': 12000,
        'deadweight': 41000,
        'year_built': 2015,
        'build_yard': 'Hyundai Heavy Industries',
        'build_country': 'South Korea',
        'owners': 'MinRes Shipping Ltd',
        'operators': 'Odin Ship Management',
      });

      expect(merged.name, 'MINRES ODIN');
      expect(merged.imoNumber, '9876543');
      expect(merged.flag, 'Panama');
      expect(merged.classSociety, 'DNV');
      expect(merged.grossTonnage, 25482);
      expect(merged.netTonnage, 12000);
      expect(merged.deadweight, 41000);
      expect(merged.yearBuilt, 2015);
      expect(merged.buildYard, 'Hyundai Heavy Industries');
      expect(merged.buildCountry, 'South Korea');
      expect(merged.owners, 'MinRes Shipping Ltd');
      expect(merged.operators, 'Odin Ship Management');
    });

    test('fills registered_owner / pi_club / ism_status when currently empty',
        () {
      final merged = blank.applyExtraction(const {
        'registered_owner': 'Odin Owning Co',
        'pi_club': 'Gard',
        'ism_status': 'compliant',
      });
      expect(merged.registeredOwner, 'Odin Owning Co');
      expect(merged.piClub, 'Gard');
      expect(merged.ismStatus, IspsStatus.compliant);
    });

    test('a fresh physical value overwrites an existing one (flag/GT/class)',
        () {
      const existing = VesselModel(
        vesselId: 'v1',
        name: 'MINRES ODIN',
        flag: 'Liberia',
        classSociety: 'BV',
        grossTonnage: 100,
      );
      final merged = existing.applyExtraction(const {
        'flag': 'Panama',
        'class_society': 'DNV',
        'gross_tonnage': 25482,
      });
      expect(merged.flag, 'Panama');
      expect(merged.classSociety, 'DNV');
      expect(merged.grossTonnage, 25482);
    });

    test('a confirmed pi_club / ism_status is NOT overwritten (statutory)', () {
      const existing = VesselModel(
        vesselId: 'v1',
        name: 'MINRES ODIN',
        piClub: 'Skuld',
        ismStatus: IspsStatus.compliant,
      );
      final merged = existing.applyExtraction(const {
        'pi_club': 'Gard',
        'ism_status': 'non_compliant',
      });
      expect(merged.piClub, 'Skuld');
      expect(merged.ismStatus, IspsStatus.compliant);
    });
  });
}
