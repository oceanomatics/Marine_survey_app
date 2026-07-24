// Widget-test double for SurveyorNotesNotifier — skips SupabaseService.client
// and sqflite entirely so any screen embedding ContextCuesPanel can be pumped
// with ProviderScope overrides and no network/auth/DB setup. Mirrors the
// pattern in fake_checklist_notifier.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

class FakeSurveyorNotesNotifier extends SurveyorNotesNotifier {
  FakeSurveyorNotesNotifier([this._seed = const []]);
  final List<SurveyorNote> _seed;
  int _counter = 0;

  @override
  Future<List<SurveyorNote>> build(String caseId) async => _seed;

  @override
  Future<SurveyorNote> add({
    required String caseId,
    required String content,
    NatureOfContent? natureOfContent,
    EvidentiaryWeight? evidentiaryWeight,
    CueOrigin? origin,
    CaseSection? caseSection,
    OccurrencePhase? occurrencePhase,
    CuePriority priority = CuePriority.normal,
    String? linkedToType,
    String? linkedToId,
    String? source,
    DateTime? contentDate,
    bool pendingReview = false,
  }) async {
    final now = DateTime.now();
    final note = SurveyorNote(
      id: 'fake-note-${++_counter}',
      caseId: caseId,
      content: content,
      natureOfContent: natureOfContent,
      evidentiaryWeight: evidentiaryWeight,
      origin: origin,
      caseSection: caseSection,
      occurrencePhase: occurrencePhase,
      priority: priority,
      lostRelevanceAt: priority == CuePriority.ignored ? now : null,
      linkedToType: linkedToType,
      linkedToId: linkedToId,
      source: source,
      contentDate: contentDate,
      pendingReview: pendingReview,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? [];
    state = AsyncData([note, ...current]);
    return note;
  }

  @override
  Future<void> editNote(
    String noteId, {
    required String content,
    NatureOfContent? natureOfContent,
    EvidentiaryWeight? evidentiaryWeight,
    CueOrigin? origin,
    CaseSection? caseSection,
    OccurrencePhase? occurrencePhase,
    CuePriority? priority,
    String? linkedToType,
    String? linkedToId,
  }) async {
    final current = state.value ?? [];
    final note = current.firstWhere((n) => n.id == noteId);
    final newPriority = priority ?? note.priority;
    DateTime? lostRelevanceAt = note.lostRelevanceAt;
    if (newPriority == CuePriority.ignored && note.priority != CuePriority.ignored) {
      lostRelevanceAt = DateTime.now();
    } else if (newPriority != CuePriority.ignored && note.priority == CuePriority.ignored) {
      lostRelevanceAt = null;
    }
    final updated = SurveyorNote(
      id: note.id,
      caseId: note.caseId,
      content: content,
      natureOfContent: natureOfContent ?? note.natureOfContent,
      evidentiaryWeight: evidentiaryWeight ?? note.evidentiaryWeight,
      origin: origin ?? note.origin,
      caseSection: caseSection,
      occurrencePhase: occurrencePhase ?? note.occurrencePhase,
      priority: newPriority,
      lostRelevanceAt: lostRelevanceAt,
      linkedToType: linkedToType ?? note.linkedToType,
      linkedToId: linkedToId ?? note.linkedToId,
      source: note.source,
      pendingReview: false,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    state =
        AsyncData(current.map((n) => n.id == noteId ? updated : n).toList());
  }

  @override
  Future<void> confirmAllocation(String noteId) async {
    final current = state.value ?? [];
    final note = current.firstWhere((n) => n.id == noteId);
    final updated = note.copyWith(pendingReview: false);
    state =
        AsyncData(current.map((n) => n.id == noteId ? updated : n).toList());
  }

  @override
  Future<void> delete(String noteId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((n) => n.id != noteId).toList());
  }
}
