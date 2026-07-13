// §2.4 (13 July 2026): PhotoModel gains Annexure E photo register fields
// (spec §4.8) — location_component, direction_context, significance_to_claim.
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';

Map<String, dynamic> _baseMap({Map<String, dynamic>? overrides}) => {
      'id': 'photo-1',
      'case_id': 'case-1',
      'local_path': '/tmp/photo.jpg',
      'taken_at': '2026-01-15T00:00:00.000',
      ...?overrides,
    };

void main() {
  group('PhotoModel.fromMap — register fields (§2.4)', () {
    test('null by default (pre-migration photos)', () {
      final p = PhotoModel.fromMap(_baseMap());
      expect(p.locationComponent, isNull);
      expect(p.directionContext, isNull);
      expect(p.significanceToClaim, isNull);
    });

    test('reads all three when set', () {
      final p = PhotoModel.fromMap(_baseMap(overrides: {
        'location_component': 'Port main engine',
        'direction_context': 'Looking aft',
        'significance_to_claim': 'Shows fracture',
      }));
      expect(p.locationComponent, 'Port main engine');
      expect(p.directionContext, 'Looking aft');
      expect(p.significanceToClaim, 'Shows fracture');
    });
  });

  group('PhotoModel.copyWith — register fields', () {
    test('can be set from null', () {
      final p = PhotoModel.fromMap(_baseMap());
      final updated = p.copyWith(locationComponent: 'Port main engine');
      expect(updated.locationComponent, 'Port main engine');
    });

    test('can be explicitly cleared back to null', () {
      final p = PhotoModel.fromMap(
          _baseMap(overrides: {'location_component': 'Port main engine'}));
      final updated = p.copyWith(locationComponent: null);
      expect(updated.locationComponent, isNull);
    });

    test('omitting a field preserves its existing value', () {
      final p = PhotoModel.fromMap(_baseMap(overrides: {
        'location_component': 'Port main engine',
        'direction_context': 'Looking aft',
      }));
      final updated = p.copyWith(significanceToClaim: 'Shows fracture');
      expect(updated.locationComponent, 'Port main engine');
      expect(updated.directionContext, 'Looking aft');
      expect(updated.significanceToClaim, 'Shows fracture');
    });
  });
}
