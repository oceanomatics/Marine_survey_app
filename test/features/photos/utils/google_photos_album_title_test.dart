import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/photos/utils/google_photos_album_title.dart';

void main() {
  group('googlePhotosAlbumTitle', () {
    test('composes date — vessel — Attendance N', () {
      final title = googlePhotosAlbumTitle(
        visitDate: DateTime(2026, 6, 28),
        vesselName: 'MV Surveyor',
        attendanceNumber: 1,
      );
      expect(title, '2026-06-28 — MV Surveyor — Attendance 1');
    });

    test('zero-pads month and day', () {
      final title = googlePhotosAlbumTitle(
        visitDate: DateTime(2026, 1, 3),
        vesselName: 'MV Test',
        attendanceNumber: 12,
      );
      expect(title, '2026-01-03 — MV Test — Attendance 12');
    });

    test('omits vessel segment when blank', () {
      final title = googlePhotosAlbumTitle(
        visitDate: DateTime(2026, 6, 28),
        vesselName: '   ',
        attendanceNumber: 2,
      );
      expect(title, '2026-06-28 — Attendance 2');
    });

    test('omits the date segment when the visit has no date', () {
      final title = googlePhotosAlbumTitle(
        visitDate: null,
        vesselName: 'MV Surveyor',
        attendanceNumber: 1,
      );
      expect(title, 'MV Surveyor — Attendance 1');
    });

    test('falls back to "Unassigned photos" when not tied to a visit', () {
      final title = googlePhotosAlbumTitle(
        visitDate: null,
        vesselName: 'MV Surveyor',
        attendanceNumber: null,
      );
      expect(title, 'MV Surveyor — Unassigned photos');
    });
  });
}
