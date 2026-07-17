// test/features/photos/screens/photo_gallery_screen_test.dart
//
// Scoped like Document Vault: upload (needs image_picker) and the Google
// Photos Picker import (needs a browser + live session) aren't attempted —
// same class of no-test-mode platform-channel blocker hit elsewhere. Fixtures
// deliberately carry no localPath/driveFileId so DrivePhotoImage always takes
// its noSourceBuilder path (a placeholder icon) rather than a real fetch.
//
// Grouping reworked 17 Jul 2026: the old By Visit / By Inspection tabs are
// gone; photos now split into "My Photos" (surveyor's own) vs "Third-Party
// Photos" (source != takenBySurveyor). Cloud badges reflect Drive backup
// state (driveFileId), not the dropped Google-Photos sync.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/photos/screens/photo_gallery_screen.dart';
import 'package:marine_survey_app/features/photos/models/photo_model.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';

import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_attendances_notifier.dart';

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
        attendancesProvider
            .overrideWith(() => FakeAttendancesNotifier(attendances)),
      ],
      child: const MaterialApp(home: PhotoGalleryScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('empty gallery shows the empty state', (tester) async {
    await _pump(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('own photos group under My Photos with their attendance header',
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

    expect(find.text('My Photos'), findsOneWidget);
    expect(find.text('Initial Attendance'), findsOneWidget);
    expect(find.text('Photos  (1)'), findsOneWidget);
  });

  testWidgets('unassigned own photos show under NOT YET ASSIGNED TO A VISIT',
      (tester) async {
    const attendance = SurveyAttendanceModel(
      attendanceId: 'att-1',
      caseId: _caseId,
      attendanceType: AttendanceType.initial,
    );
    final photo =
        PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    await _pump(tester, photos: [photo], attendances: [attendance]);

    expect(find.text('NOT YET ASSIGNED TO A VISIT'), findsOneWidget);
  });

  testWidgets('third-party photos group under Third-Party Photos by source',
      (tester) async {
    final photo = PhotoModel(
      id: 'p1',
      caseId: _caseId,
      takenAt: DateTime(2026, 6, 1),
      photoSource: PhotoSource.providedByContractor,
    );
    await _pump(tester, photos: [photo]);

    expect(find.text('Third-Party Photos'), findsOneWidget);
    expect(find.text('PROVIDED BY CONTRACTOR'), findsOneWidget);
  });

  testWidgets('photo without a Drive copy shows the not-backed-up badge',
      (tester) async {
    final photo =
        PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    await _pump(tester, photos: [photo]);

    // driveFileId == null → cloud_off badge on the tile.
    expect(find.byIcon(Icons.cloud_off_outlined), findsWidgets);
  });

  testWidgets(
      'long-pressing a photo shows a delete confirmation, removes it on confirm',
      (tester) async {
    final photo =
        PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    final fake = await _pump(tester, photos: [photo]);

    await tester.longPress(find.byIcon(Icons.cloud_download_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete photo?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.state.value, isEmpty);
  });

  testWidgets('long-press Cancel leaves the photo in place', (tester) async {
    final photo =
        PhotoModel(id: 'p1', caseId: _caseId, takenAt: DateTime(2026, 6, 1));
    final fake = await _pump(tester, photos: [photo]);

    await tester.longPress(find.byIcon(Icons.cloud_download_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.state.value, hasLength(1));
  });

  testWidgets(
      'allocation badge shows the short label for a photo with an allocation',
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
