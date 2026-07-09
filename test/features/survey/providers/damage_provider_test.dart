import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';

DamageItemModel _item({
  String componentName = 'Main engine turbocharger',
  List<ConfirmedByRole> confirmedBy = const [],
  String? confirmationMethod,
  String? conditionFound,
  String? damageDescription,
}) =>
    DamageItemModel(
      damageId: 'd1',
      occurrenceId: 'o1',
      caseId: 'c1',
      componentName: componentName,
      confirmedBy: confirmedBy,
      confirmationMethod: confirmationMethod,
      conditionFound: conditionFound,
      damageDescription: damageDescription,
    );

void main() {
  group('composeDamageRowDescription', () {
    test('no confirmation, no condition/description -> just the part, no dangling clauses', () {
      final desc = composeDamageRowDescription(_item());
      expect(desc, 'Main engine turbocharger.');
    });

    test('condition and description only, no confirmation -> woven in with a dash', () {
      final desc = composeDamageRowDescription(_item(
        conditionFound: 'removed for inspection',
        damageDescription: 'signs of fretting',
      ));
      expect(desc,
          'Main engine turbocharger. removed for inspection — signs of fretting.');
    });

    test('surveyor-only confirmation', () {
      final desc = composeDamageRowDescription(_item(
        confirmedBy: const [ConfirmedByRole.undersignedSurveyor],
      ));
      expect(desc,
          'Main engine turbocharger was inspected by the attending surveyor.');
    });

    test('third-party-only confirmation (no surveyor) uses their label directly', () {
      final desc = composeDamageRowDescription(_item(
        confirmedBy: const [ConfirmedByRole.oemEngineer],
      ));
      expect(desc, 'Main engine turbocharger was inspected by OEM Engineer.');
    });

    test('surveyor + specialist confirmation follows the full worked-example shape', () {
      final desc = composeDamageRowDescription(_item(
        confirmedBy: const [
          ConfirmedByRole.undersignedSurveyor,
          ConfirmedByRole.oemEngineer,
        ],
        confirmationMethod: 'OEM report dated 3 July 2026, page 4',
        conditionFound: 'removed for inspection',
        damageDescription: 'signs of fretting',
      ));
      expect(
        desc,
        'Main engine turbocharger was inspected by the attending surveyor. '
        'Further confirmation was indicated in OEM report dated 3 July 2026, '
        'page 4 by OEM Engineer, as it was removed for inspection and showed '
        'signs of fretting.',
      );
    });

    test('surveyor + specialist but no confirmation method omits the "in ..." clause', () {
      final desc = composeDamageRowDescription(_item(
        confirmedBy: const [
          ConfirmedByRole.undersignedSurveyor,
          ConfirmedByRole.classSurveyor,
        ],
      ));
      expect(
        desc,
        'Main engine turbocharger was inspected by the attending surveyor. '
        'Further confirmation was indicated by Class Surveyor.',
      );
    });
  });
}
