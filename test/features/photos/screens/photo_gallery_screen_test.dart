// test/features/photos/screens/photo_gallery_screen_test.dart
//
// Scoped like Document Vault: upload (row 72, needs image_picker) isn't
// attempted — same class of no-test-mode platform-channel blocker hit
// elsewhere this session. Fixtures deliberately carry no localPath/
// driveFileId so DrivePhotoImage always takes its noSourceBuilder path
// (a placeholder icon) rather than attempting a real file/network fetch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/photos/screens/photo_gallery_screen.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';

import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_attendances_notifier.dart';
import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';

const _caseId = 'case-1';

Future<FakePhotoNotifier> _pump(
  WidgetTester tester, {
  List<PhotoModel> photos = const [],
  List<SurveyAttendanceModel> attendances = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakePhotoNotifier(photos);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        photosProvider.overrideWith(() => fake),
        attendancesProvider.overrideWith(() => FakeAttendancesNotifier(attendances)),
        damageProvider.overrideWith(
            () => FakeDamageNotifier(fixtureDamageState(occurrences: []))),
      ],
      child: const MaterialApp(home: PhotoGalleryScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('empty gallery shows the empty state on both tabs', (tester) async {
    await _pump(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('By Visit tab groups photos under their attendance header',
      (tester) async {
    final attendance = SurveyAttendanceModel(
      attendanceId: 'att-1',
      caseId: _caseId,
      attendanceType: AttendanceType.initial,
      attendanceDate: DateTime(2026, 6, 1),
    );
    final photo = PhotoModel(
      id: 'p1',
      caseId: _caseId,
      takenAt: DateTime(2026, 6, 1),
      attendanceId: 'att-1',
    );
    await _pump(tester, photos: [photo], attendances: [attendance]);

    expect(find.text('Initial Attendance'), findsOneWidget);
    expect(find.text('Photos  (1)'), findsOneWidget);
  });

  testWidgets('unassigned photos show under NOT YET ASSIGNED TO A VISIT',
      (tester) async {
    const attendance = SurveyAttendanceModel(
      attendanceId: 'att-1',
      caseId: _caseId,
      attendanceType: AttendanceType.initial,
    );
    final photo = PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    await _pump(tester, photos: [photo], attendances: [attendance]);

    expect(find.text('NOT YET ASSIGNED TO A VISIT'), findsOneWidget);
  });

  testWidgets('By Inspection tab shows unlinked photos under GENERAL / UNLINKED PHOTOS',
      (tester) async {
    final photo = PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    await _pump(tester, photos: [photo]);

    await tester.tap(find.text('By Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('GENERAL / UNLINKED PHOTOS'), findsOneWidget);
  });

  testWidgets('long-pressing a photo shows a delete confirmation, removes it on confirm',
      (tester) async {
    final photo = PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    final fake = await _pump(tester, photos: [photo]);

    await tester.longPress(find.byIcon(Icons.cloud_download_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Delete photo?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.state.value, isEmpty);
  });

  testWidgets('long-press Cancel leaves the photo in place', (tester) async {
    final photo = PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    final fake = await _pump(tester, photos: [photo]);

    await tester.longPress(find.byIcon(Icons.cloud_download_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.state.value, hasLength(1));
  });

  testWidgets('allocation badge shows the short label for a photo with an allocation',
      (tester) async {
    final photo = PhotoModel(
      id: 'p1',
      caseId: _caseId,
      takenAt: DateTime(2026, 6, 1),
      allocation: PhotoAllocation.coverPage,
    );
    await _pump(tester, photos: [photo]);

    expect(find.text('COVER'), findsOneWidget);
  });
}
