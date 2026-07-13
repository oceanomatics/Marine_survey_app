// lib/features/action_items/providers/action_items_provider.dart
//
// TODO.md §4.7 — App-Wide Action Items / Task Tracking. Case-level only for
// this pass (see migration 039's header comment for why admin-level is
// deferred). AI-extraction candidates are never auto-committed — an action
// item created from a correspondence source starts pendingReview: true,
// same human-in-the-loop convention as cue suggestions
// (docs/context_cue_system_review.md §3.5).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

enum ActionItemStatus {
  open('open', 'Open'),
  done('done', 'Done'),
  dismissed('dismissed', 'Dismissed');

  const ActionItemStatus(this.value, this.label);
  final String value;
  final String label;

  static ActionItemStatus fromValue(String? v) => values
      .firstWhere((e) => e.value == v, orElse: () => ActionItemStatus.open);
}

@immutable
class ActionItemModel {
  const ActionItemModel({
    required this.id,
    required this.caseId,
    required this.text,
    this.status = ActionItemStatus.open,
    this.sourceType,
    this.sourceId,
    this.pendingReview = false,
    this.dueDate,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String caseId;
  final String text;
  final ActionItemStatus status;

  /// 'correspondence' | 'manual' | null — where this item came from. Not
  /// hard-coded to a single source table, so a future source (documents,
  /// context cues) can reuse the same column pair.
  final String? sourceType;
  final String? sourceId;

  /// True for an AI-surfaced candidate not yet confirmed by a surveyor —
  /// shown separately in the UI, never counted as a live open task.
  final bool pendingReview;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? completedAt;

  factory ActionItemModel.fromJson(Map<String, dynamic> j) => ActionItemModel(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        text: j['text'] as String,
        status: ActionItemStatus.fromValue(j['status'] as String?),
        sourceType: j['source_type'] as String?,
        sourceId: j['source_id'] as String?,
        pendingReview: j['pending_review'] as bool? ?? false,
        dueDate: j['due_date'] != null
            ? DateTime.tryParse(j['due_date'] as String)
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)
            : null,
      );

  ActionItemModel copyWith({
    String? text,
    ActionItemStatus? status,
    bool? pendingReview,
    DateTime? completedAt,
  }) =>
      ActionItemModel(
        id: id,
        caseId: caseId,
        text: text ?? this.text,
        status: status ?? this.status,
        sourceType: sourceType,
        sourceId: sourceId,
        pendingReview: pendingReview ?? this.pendingReview,
        dueDate: dueDate,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

final actionItemsProvider = AsyncNotifierProviderFamily<ActionItemsNotifier,
    List<ActionItemModel>, String>(
  ActionItemsNotifier.new,
);

class ActionItemsNotifier
    extends FamilyAsyncNotifier<List<ActionItemModel>, String> {
  @override
  Future<List<ActionItemModel>> build(String caseId) => _fetch(caseId);

  Future<List<ActionItemModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('action_items')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ActionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Manual entry — a surveyor typing a task directly, never pendingReview
  /// (there's no AI suggestion to confirm; they wrote it themselves).
  Future<void> addManual(String caseId, String text, {DateTime? dueDate}) async {
    final data = await SupabaseService.client
        .from('action_items')
        .insert({
          'case_id': caseId,
          'text': text,
          'source_type': 'manual',
          if (dueDate != null)
            'due_date': dueDate.toIso8601String().split('T').first,
        })
        .select()
        .single();
    final item = ActionItemModel.fromJson(data);
    state = AsyncData([item, ...(state.value ?? [])]);
  }

  /// §3.14/§4.7: creates a pending-review candidate from a correspondence
  /// item's already-extracted `actions` — the surveyor confirms it via
  /// [confirm] before it counts as a live task. [sourceId] is the
  /// correspondence row's id, so the same action string is never offered
  /// twice (see [alreadySuggested]).
  Future<void> addSuggested(
    String caseId,
    String text, {
    required String sourceId,
  }) async {
    final data = await SupabaseService.client
        .from('action_items')
        .insert({
          'case_id': caseId,
          'text': text,
          'source_type': 'correspondence',
          'source_id': sourceId,
          'pending_review': true,
        })
        .select()
        .single();
    final item = ActionItemModel.fromJson(data);
    state = AsyncData([item, ...(state.value ?? [])]);
  }

  /// True if an action item already exists for this exact source_id/text
  /// pair — guards addSuggested() call sites against re-offering the same
  /// extracted string on every screen open.
  bool alreadySuggested(String sourceId, String text) =>
      (state.value ?? []).any(
          (i) => i.sourceId == sourceId && i.text == text);

  /// Confirms a pendingReview candidate — the human-in-the-loop step that
  /// turns an AI suggestion into a real tracked task.
  Future<void> confirm(String id) async {
    await SupabaseService.client
        .from('action_items')
        .update({'pending_review': false}).eq('id', id);
    _patch(id, (i) => i.copyWith(pendingReview: false));
  }

  Future<void> setStatus(String id, ActionItemStatus status) async {
    final now = DateTime.now();
    await SupabaseService.client.from('action_items').update({
      'status': status.value,
      'completed_at': status == ActionItemStatus.open
          ? null
          : now.toIso8601String(),
    }).eq('id', id);
    _patch(id, (i) => i.copyWith(
        status: status,
        completedAt: status == ActionItemStatus.open ? null : now));
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('action_items').delete().eq('id', id);
    state = AsyncData((state.value ?? []).where((i) => i.id != id).toList());
  }

  void _patch(String id, ActionItemModel Function(ActionItemModel) update) {
    final current = state.value ?? [];
    state = AsyncData(
        current.map((i) => i.id == id ? update(i) : i).toList());
  }
}
