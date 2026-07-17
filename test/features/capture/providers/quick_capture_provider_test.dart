// test/features/capture/providers/quick_capture_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/capture/providers/quick_capture_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

import '../../../support/fakes/fake_quick_capture_notifier.dart';

/// Records every add() call instead of touching Supabase/sqflite, so the
/// test can assert exactly what QuickCaptureNotifier.routeCapture() (via
/// its fake) tried to file as a cue.
class _RecordingSurveyorNotesNotifier extends SurveyorNotesNotifier {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<List<SurveyorNote>> build(String caseId) async => const [];

  @override
  Future<SurveyorNote> add({
    required String caseId,
    required String content,
    NatureOfContent? natureOfContent,
    EvidentiaryWeight? evidentiaryWeight,
    CueOrigin? origin,
    CaseSection? caseSection,
    CuePriority priority = CuePriority.normal,
    String? linkedToType,
    String? linkedToId,
    String? source,
    bool pendingReview = false,
    OccurrencePhase? occurrencePhase,
  }) async {
    calls.add({
      'caseId': caseId,
      'content': content,
      'caseSection': caseSection,
      'source': source,
    });
    final note = SurveyorNote(
      id: 'note-${calls.length}',
      caseId: caseId,
      content: content,
      caseSection: caseSection,
      priority: priority,
      source: source,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );
    return note;
  }
}

void main() {
  group('sectionForRoutedTo — cue-routing mapping', () {
    test('damageItem maps to CaseSection.damage', () {
      expect(sectionForRoutedTo(RoutedTo.damageItem), CaseSection.damage);
    });

    test('occurrenceNote maps to CaseSection.occurrence', () {
      expect(sectionForRoutedTo(RoutedTo.occurrenceNote), CaseSection.occurrence);
    });

    test('destinations with no clean section land unallocated (null)', () {
      for (final r in [
        RoutedTo.checklist,
        RoutedTo.docRequest,
        RoutedTo.interviewQuestion,
        RoutedTo.generalNote,
        RoutedTo.discarded,
      ]) {
        expect(sectionForRoutedTo(r), isNull, reason: '$r should be unallocated');
      }
    });
  });

  group('QuickCaptureNotifier.routeCapture — cue creation', () {
    late _RecordingSurveyorNotesNotifier recorder;
    late ProviderContainer container;

    const capture = QuickCaptureModel(
      captureId: 'cap1',
      caseId: 'case1',
      content: 'Ejected connecting rod found in bilge',
      status: CaptureStatus.pending,
    );

    setUp(() {
      recorder = _RecordingSurveyorNotesNotifier();
      container = ProviderContainer(overrides: [
        quickCaptureProvider.overrideWith(
            () => FakeQuickCaptureNotifier(const [capture])),
        surveyorNotesProvider.overrideWith(() => recorder),
      ]);
      addTearDown(container.dispose);
    });

    test('routing to damageItem creates a note scoped to CaseSection.damage', () async {
      await container.read(quickCaptureProvider('case1').future);
      await container.read(quickCaptureProvider('case1').notifier).routeCapture(
            captureId: 'cap1',
            destination: RoutedTo.damageItem,
          );

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single['caseSection'], CaseSection.damage);
      expect(recorder.calls.single['content'], 'Ejected connecting rod found in bilge');
      expect(recorder.calls.single['source'], 'Quick Capture');
    });

    test('routing to generalNote creates an unallocated (null-section) note', () async {
      await container.read(quickCaptureProvider('case1').future);
      await container.read(quickCaptureProvider('case1').notifier).routeCapture(
            captureId: 'cap1',
            destination: RoutedTo.generalNote,
          );

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single['caseSection'], isNull);
    });

    test('routing to discarded does NOT create a note', () async {
      await container.read(quickCaptureProvider('case1').future);
      await container.read(quickCaptureProvider('case1').notifier).routeCapture(
            captureId: 'cap1',
            destination: RoutedTo.discarded,
          );

      expect(recorder.calls, isEmpty);
    });

    test('routed item status flips to routed with the destination recorded', () async {
      await container.read(quickCaptureProvider('case1').future);
      await container.read(quickCaptureProvider('case1').notifier).routeCapture(
            captureId: 'cap1',
            destination: RoutedTo.damageItem,
          );

      final state = container.read(quickCaptureProvider('case1')).value!;
      final item = state.items.single;
      expect(item.status, CaptureStatus.routed);
      expect(item.routedTo, RoutedTo.damageItem);
    });
  });
}
