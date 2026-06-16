// lib/features/capture/providers/quick_capture_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/claude_api.dart';

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

  /// Route an item to its destination
  Future<void> routeCapture({
    required String captureId,
    required RoutedTo destination,
    String? linkedId,
  }) async {
    await SupabaseService.client
        .from('quick_captures')
        .update({
          'status':    'routed',
          'routed_to': destination.value,
          if (linkedId != null) 'linked_id': linkedId,
        })
        .eq('capture_id', captureId);

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
    for (final item in current.pending) {
      final suggestion = await getSuggestion(item.content);
      await routeCapture(
          captureId: item.captureId, destination: suggestion);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
