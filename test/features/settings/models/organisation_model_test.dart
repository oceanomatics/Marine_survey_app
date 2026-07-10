import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/settings/models/organisation_model.dart';

OrganisationModel _org(Map<String, dynamic> extra) => OrganisationModel.fromJson({
      'id': 'org-1',
      'name': 'Acme Marine Surveyors',
      ...extra,
    });

void main() {
  group('OrganisationModel multi-logo', () {
    test('parses logo_storage_paths array from json', () {
      final org = _org({
        'logo_storage_paths': ['org-1/a.png', 'org-1/b.png'],
      });
      expect(org.logoStoragePaths, ['org-1/a.png', 'org-1/b.png']);
    });

    test('defaults to empty list when column absent', () {
      final org = _org({});
      expect(org.logoStoragePaths, isEmpty);
    });

    test('primaryLogoPath is the first array entry', () {
      final org = _org({
        'logo_storage_paths': ['org-1/primary.png', 'org-1/co-brand.png'],
      });
      expect(org.primaryLogoPath, 'org-1/primary.png');
    });

    test('primaryLogoPath falls back to legacy single column', () {
      final org = _org({'logo_storage_path': 'org-1/legacy.png'});
      expect(org.logoStoragePaths, isEmpty);
      expect(org.primaryLogoPath, 'org-1/legacy.png');
    });

    test('array takes precedence over legacy single column', () {
      final org = _org({
        'logo_storage_path': 'org-1/legacy.png',
        'logo_storage_paths': ['org-1/new.png'],
      });
      expect(org.primaryLogoPath, 'org-1/new.png');
    });

    test('toJson always includes both logo fields, mirroring element 0', () {
      final org = _org({
        'logo_storage_paths': ['org-1/primary.png', 'org-1/second.png'],
      });
      final json = org.toJson();
      expect(json['logo_storage_paths'], ['org-1/primary.png', 'org-1/second.png']);
      expect(json['logo_storage_path'], 'org-1/primary.png');
    });

    test('toJson writes null single logo and empty array when no logos', () {
      final org = _org({});
      final json = org.toJson();
      // Present (not omitted) so a removal actually clears the column.
      expect(json.containsKey('logo_storage_paths'), isTrue);
      expect(json.containsKey('logo_storage_path'), isTrue);
      expect(json['logo_storage_paths'], isEmpty);
      expect(json['logo_storage_path'], isNull);
    });

    test('copyWith replaces the logo list (incl. clearing to empty)', () {
      final org = _org({
        'logo_storage_paths': ['org-1/a.png'],
      });
      final cleared = org.copyWith(logoStoragePaths: const []);
      expect(cleared.logoStoragePaths, isEmpty);
      expect(cleared.primaryLogoPath, isNull);

      final added = org.copyWith(
        logoStoragePaths: [...org.logoStoragePaths, 'org-1/b.png'],
      );
      expect(added.logoStoragePaths, ['org-1/a.png', 'org-1/b.png']);
    });
  });
}
