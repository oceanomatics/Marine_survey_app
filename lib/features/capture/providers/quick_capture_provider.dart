// lib/features/capture/providers/quick_capture_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart' show CaseSection;
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum CaptureStatus {
  pending('pending', 'Pending'),
  routed('routed', 'Routed'),
  discarded('discarded', 'Discarded');

  const CaptureStatus(this.value, this.label);
  final String value;
  final String label;

  static CaptureStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => CaptureStatus.pending);
}

enum RoutedTo {
  damageItem('damage_item', 'Damage Item', '🔧'),
  checklist('checklist', 'Checklist', '📋'),
  docRequest('doc_request', 'Document Request', '📄'),
  interviewQuestion('interview_question', 'Interview Question', '🎤'),
  occurrenceNote('occurrence_note', 'Occurrence Note', '📝'),
  generalNote('general_note', 'General Note', '💬'),
  discarded('discarded', 'Discard', '🗑️');

  const RoutedTo(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static RoutedTo fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => RoutedTo.generalNote);
}

// ── Model ─────────────────────────────────────────────────────────────────

@immutable
class QuickCaptureModel {
  const QuickCaptureModel({
    required this.captureId,
    required this.caseId,
    required this.content,
    required this.status,
    this.capturedAt,
    this.captureType = 'text',
    this.routedTo,
    this.linkedId,
    this.aiSuggestion,
  });

  final String captureId;
  final String caseId;
  final String content;
  final CaptureStatus status;
  final DateTime? capturedAt;
  final String captureType;
  final RoutedTo? routedTo;
  final String? linkedId;
  final RoutedTo? aiSuggestion; // Claude's routing suggestion

  bool get isPending => status == CaptureStatus.pending;

  factory QuickCaptureModel.fromJson(Map<String, dynamic> j) =>
      QuickCaptureModel(
        captureId:   j['capture_id'] as String,
        caseId:      j['case_id'] as String,
        content:     j['content'] as String,
        status:      CaptureStatus.fromValue(
            j['status'] as String? ?? 'pending'),
        capturedAt:  j['captured_at'] != null
            ? DateTime.tryParse(j['captured_at'] as String)
            : null,
        captureType: j['capture_type'] as String? ?? 'text',
        routedTo:    j['routed_to'] != null
            ? RoutedTo.fromValue(j['routed_to'] as String)
            : null,
        linkedId:    j['linked_id'] as String?,
      );
}

// ── State ─────────────────────────────────────────────────────────────────

@immutable
class QuickCaptureState {
  const QuickCaptureState({required this.items});

  final List<QuickCaptureModel> items;

  List<QuickCaptureModel> get pending =>
      items.where((i) => i.isPending).toList();
  List<QuickCaptureModel> get routed =>
      items.where((i) => i.status == CaptureStatus.routed).toList();
  int get pendingCount => pending.length;
}

/// Which CaseSection a routed destination maps to for the real cue it
/// creates — see [QuickCaptureNotifier.routeCapture]. Destinations with no
/// clean cue-system home (checklist/doc request/interview question/general
/// note) map to `null` (unallocated) rather than being force-fit into the
/// wrong section; the surveyor re-tags from there via the existing Advice
/// to Owner "Unallocated" tab, same as any other untagged cue. Top-level
/// (not a private notifier method) so it's independently unit-testable and
/// the test fake can call the exact same function instead of a duplicate.
CaseSection? sectionForRoutedTo(RoutedTo r) => switch (r) {
      RoutedTo.damageItem     => CaseSection.damage,
      RoutedTo.occurrenceNote => CaseSection.occurrence,
      _                       => null,
    };

// ── Provider ───────────────────────────────────────────────────────────────

final quickCaptureProvider = AsyncNotifierProviderFamily<
    QuickCaptureNotifier, QuickCaptureState, String>(
  QuickCaptureNotifier.new,
);

class QuickCaptureNotifier
    extends FamilyAsyncNotifier<QuickCaptureState, String> {
  @override
  Future<QuickCaptureState> build(String caseId) => _fetch(caseId);

  Future<QuickCaptureState> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('quick_captures')
        .select()
        .eq('case_id', caseId)
        .order('captured_at', ascending: false);

    final items =
        (data as List).map((e) => QuickCaptureModel.fromJson(e as Map<String, dynamic>)).toList();
    return QuickCaptureState(items: items);
  }

  /// Save a new capture from the quick capture sheet
  Future<QuickCaptureModel> addCapture({
    required String caseId,
    required String content,
    String captureType = 'text',
  }) async {
    final data = await SupabaseService.client
        .from('quick_captures')
        .insert({
          'case_id':      caseId,
          'content':      content,
          'capture_type': captureType,
          'status':       'pending',
          'captured_at':  DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final capture = QuickCaptureModel.fromJson(data);
    final current = state.value!;
    state = AsyncData(QuickCaptureState(
        items: [capture, ...current.items]));
    return capture;
  }

  /// Ask Claude to suggest where this item should be routed
  Future<RoutedTo> getSuggestion(String content) async {
    try {
      final result = await ClaudeApi.routeVoiceNote(content);
      final routedToStr = result['routed_to'] as String? ?? 'general_note';
      return RoutedTo.fromValue(routedToStr);
    } catch (_) {
      return RoutedTo.generalNote;
    }
  }

  /// Route an item to its destination.
  ///
  /// 14 July 2026 walkthrough — this used to only flip `status`/`routed_to`
  /// on the `quick_captures` row itself; nothing downstream (cues, report
  /// drafting) ever saw the content, so "routing" didn't actually connect
  /// to anything. It now also creates the real `SurveyorNote` cue the rest
  /// of the app reads from — capturing at a high, undifferentiated level
  /// still works (destinations with no clean section land unallocated
  /// instead of forcing a choice), but the content is no longer stranded
  /// once triaged.
  Future<void> routeCapture({
    required String captureId,
    required RoutedTo destination,
    String? linkedId,
  }) async {
    final current0 = state.value!;
    final capture = current0.items.firstWhere((i) => i.captureId == captureId);

    await SupabaseService.client
        .from('quick_captures')
        .update({
          'status':    'routed',
          'routed_to': destination.value,
          if (linkedId != null) 'linked_id': linkedId,
        })
        .eq('capture_id', captureId);

    if (destination != RoutedTo.discarded) {
      await ref.read(surveyorNotesProvider(capture.caseId).notifier).add(
            caseId: capture.caseId,
            content: capture.content,
            caseSection: sectionForRoutedTo(destination),
            source: 'Quick Capture',
          );
    }

    final current = state.value!;
    state = AsyncData(QuickCaptureState(
      items: current.items.map((i) {
        if (i.captureId != captureId) return i;
        return QuickCaptureModel(
          captureId:   i.captureId,
          caseId:      i.caseId,
          content:     i.content,
          status:      CaptureStatus.routed,
          capturedAt:  i.capturedAt,
          captureType: i.captureType,
          routedTo:    destination,
          linkedId:    linkedId,
        );
      }).toList(),
    ));
  }

  /// Discard an item
  Future<void> discardCapture(String captureId) async {
    await SupabaseService.client
        .from('quick_captures')
        .update({'status': 'discarded', 'routed_to': 'discarded'})
        .eq('capture_id', captureId);

    final current = state.value!;
    state = AsyncData(QuickCaptureState(
      items: current.items.map((i) {
        if (i.captureId != captureId) return i;
        return QuickCaptureModel(
          captureId:   i.captureId,
          caseId:      i.caseId,
          content:     i.content,
          status:      CaptureStatus.discarded,
          capturedAt:  i.capturedAt,
          captureType: i.captureType,
          routedTo:    RoutedTo.discarded,
        );
      }).toList(),
    ));
  }

  /// Route all pending items at once using Claude suggestions
  Future<void> routeAllWithAI() async {
    final current = state.value!;
    final pending = current.pending;
    if (pending.isEmpty) return;
    // One task for the whole batch, not one per item — reads better in the
    // AI Activity panel ("Routing 5 cues") than N flickering entries for a
    // single "Route All" tap.
    await ref.read(aiTasksProvider.notifier).run(
          label: 'Routing ${pending.length} capture'
              '${pending.length == 1 ? '' : 's'}',
          caseId: arg,
          estimate: Duration(seconds: 6 * pending.length),
          action: () async {
            for (final item in pending) {
              final suggestion = await getSuggestion(item.content);
              await routeCapture(
                  captureId: item.captureId, destination: suggestion);
            }
          },
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
