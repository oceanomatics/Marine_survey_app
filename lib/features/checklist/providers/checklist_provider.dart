// lib/features/checklist/providers/checklist_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../reports/providers/case_completeness_provider.dart';
import '../../reports/utils/case_completeness.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum ChecklistStage {
  preSurvey('pre_survey', 'Pre-Survey', 'Before boarding'),
  onVessel('on_vessel', 'On Vessel', 'While on board'),
  beforeLeaving('before_leaving', 'Before Leaving', 'Final checks'),
  postSurvey('post_survey', 'Post-Survey', 'Back at office');

  const ChecklistStage(this.value, this.label, this.subtitle);
  final String value;
  final String label;
  final String subtitle;

  static ChecklistStage fromValue(String v) => values
      .firstWhere((e) => e.value == v, orElse: () => ChecklistStage.onVessel);
}

/// §4.4 rework (2026-07-13 live audit): many real checklist items (e.g.
/// Andy's MM09 attendance-advice list) are document/access requests where
/// "did we get/see this" genuinely has three answers, not a binary tick —
/// Yes (done), No (still outstanding, needs follow-up — counts the same as
/// unanswered for progress purposes), N/A (not applicable/not fitted —
/// excluded from progress/stage totals entirely).
enum ChecklistResponse {
  yes('yes', 'Yes'),
  no('no', 'No'),
  na('na', 'N/A');

  const ChecklistResponse(this.value, this.label);
  final String value;
  final String label;

  static ChecklistResponse? fromValue(String? v) {
    if (v == null) return null;
    return values.firstWhere((e) => e.value == v,
        orElse: () => ChecklistResponse.no);
  }
}

// ── Model ─────────────────────────────────────────────────────────────────

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.checklistId,
    required this.caseId,
    required this.stage,
    required this.itemNo,
    required this.itemText,
    this.response,
    this.answeredAt,
    this.linkedSection,
    this.linkedId,
    this.notes,
    this.isCustom = false,
    this.autoTickAttempted = false,
  });

  final String checklistId;
  final String caseId;
  final ChecklistStage stage;
  final int itemNo;
  final String itemText;

  /// Null = not yet answered.
  final ChecklistResponse? response;
  final DateTime? answeredAt;
  final String? linkedSection;
  final String? linkedId;
  final String? notes;
  final bool isCustom;

  /// §4.4: true once the auto-tick evaluator has acted on this item — a
  /// one-shot marker so a surveyor manually un-ticking an auto-ticked item
  /// is never immediately re-ticked by the next pass, even though the
  /// underlying data condition is still true.
  final bool autoTickAttempted;

  bool get completed => response == ChecklistResponse.yes;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        checklistId: j['checklist_id'] as String,
        caseId: j['case_id'] as String,
        stage: ChecklistStage.fromValue(j['stage'] as String? ?? 'on_vessel'),
        itemNo: j['item_no'] as int,
        itemText: j['item_text'] as String,
        response: ChecklistResponse.fromValue(j['response'] as String?),
        answeredAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)
            : null,
        linkedSection: j['linked_section'] as String?,
        linkedId: j['linked_id'] as String?,
        notes: j['notes'] as String?,
        isCustom: j['is_custom'] as bool? ?? false,
        autoTickAttempted: j['auto_tick_attempted'] as bool? ?? false,
      );

  ChecklistItem copyWith(
          {ChecklistResponse? response,
          DateTime? answeredAt,
          String? notes,
          bool? autoTickAttempted}) =>
      ChecklistItem(
        checklistId: checklistId,
        caseId: caseId,
        stage: stage,
        itemNo: itemNo,
        itemText: itemText,
        response: response ?? this.response,
        answeredAt: answeredAt ?? this.answeredAt,
        linkedSection: linkedSection,
        linkedId: linkedId,
        notes: notes ?? this.notes,
        isCustom: isCustom,
        autoTickAttempted: autoTickAttempted ?? this.autoTickAttempted,
      );
}

// ── Grouped checklist state ────────────────────────────────────────────────

@immutable
class ChecklistState {
  const ChecklistState({required this.items});
  final List<ChecklistItem> items;

  List<ChecklistItem> forStage(ChecklistStage stage) =>
      items.where((i) => i.stage == stage).toList()
        ..sort((a, b) => a.itemNo.compareTo(b.itemNo));

  // N/A items are excluded from every total below — they're not part of
  // "is this case ready", they're explicitly not applicable.
  int get totalCount =>
      items.where((i) => i.response != ChecklistResponse.na).length;
  int get completedCount => items.where((i) => i.completed).length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  int stageTotal(ChecklistStage stage) => items
      .where((i) => i.stage == stage && i.response != ChecklistResponse.na)
      .length;
  int stageCompleted(ChecklistStage stage) =>
      items.where((i) => i.stage == stage && i.completed).length;
  double stageProgress(ChecklistStage stage) {
    final total = stageTotal(stage);
    return total == 0 ? 0 : stageCompleted(stage) / total;
  }

  // Are all mandatory (non-custom) items in a stage done? Items marked N/A
  // don't count against this — a stage of all-N/A items is vacuously
  // complete (nothing left applicable to do).
  bool stageComplete(ChecklistStage stage) {
    final all = items.where((i) => i.stage == stage);
    if (all.isEmpty) return false;
    final relevant = all.where((i) => i.response != ChecklistResponse.na);
    return relevant.isEmpty || relevant.every((i) => i.completed);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final checklistProvider =
    AsyncNotifierProviderFamily<ChecklistNotifier, ChecklistState, String>(
  ChecklistNotifier.new,
);

class ChecklistNotifier extends FamilyAsyncNotifier<ChecklistState, String> {
  @override
  Future<ChecklistState> build(String caseId) {
    // §4.4 (2026-07-13 review fix): react to completeness changes from
    // this provider's own lifecycle, not from a screen's build() — so
    // auto-tick keeps firing even when the Checklist screen isn't the one
    // mounted/rebuilding. This provider isn't autoDispose, so once built
    // (e.g. the surveyor opens Checklist once) it keeps listening for the
    // rest of the session.
    ref.listen(caseCompletenessProvider(caseId), (previous, next) {
      autoTickIfReady(next);
    });
    return _fetch(caseId);
  }

  Future<ChecklistState> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('checklists')
        .select()
        .eq('case_id', caseId)
        .order('stage')
        .order('item_no');

    final items = (data as List)
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChecklistState(items: items);
  }

  /// Set an item's Yes/No/N-A response.
  Future<void> setResponse(
      ChecklistItem item, ChecklistResponse response) async {
    final now = DateTime.now();

    // Optimistic update
    final current = state.value!;
    final updated = current.items.map((i) {
      if (i.checklistId != item.checklistId) return i;
      return i.copyWith(response: response, answeredAt: now);
    }).toList();
    state = AsyncData(ChecklistState(items: updated));

    // Persist
    await SupabaseService.client.from('checklists').update({
      'response': response.value,
      'completed_at': now.toIso8601String(),
      'completed_by': SupabaseService.userId,
    }).eq('checklist_id', item.checklistId);
  }

  /// Mark every not-yet-answered item in a stage as Yes. Items already
  /// answered (Yes, No, or N/A) are left as the surveyor set them — this is
  /// a bulk nudge for untouched items, not an override of explicit answers.
  Future<void> completeStage(ChecklistStage stage) async {
    final now = DateTime.now();
    final current = state.value!;
    final stageIds = current
        .forStage(stage)
        .where((i) => i.response == null)
        .map((i) => i.checklistId)
        .toList();

    if (stageIds.isEmpty) return;

    // Optimistic update
    final updated = current.items.map((i) {
      if (!stageIds.contains(i.checklistId)) return i;
      return i.copyWith(response: ChecklistResponse.yes, answeredAt: now);
    }).toList();
    state = AsyncData(ChecklistState(items: updated));

    // Persist — update each
    for (final id in stageIds) {
      await SupabaseService.client.from('checklists').update({
        'response': ChecklistResponse.yes.value,
        'completed_at': now.toIso8601String(),
        'completed_by': SupabaseService.userId,
      }).eq('checklist_id', id);
    }
  }

  /// Add a custom item to a stage
  Future<void> addCustomItem({
    required String caseId,
    required ChecklistStage stage,
    required String text,
  }) async {
    final current = state.value!;
    final stageItems = current.forStage(stage);
    final nextNo = stageItems.isEmpty ? 100 : stageItems.last.itemNo + 1;

    final data = await SupabaseService.client
        .from('checklists')
        .insert({
          'case_id': caseId,
          'stage': stage.value,
          'item_no': nextNo,
          'item_text': text,
          'is_custom': true,
        })
        .select()
        .single();

    final newItem = ChecklistItem.fromJson(data);
    state = AsyncData(ChecklistState(items: [...current.items, newItem]));
  }

  /// Update notes on an item
  Future<void> updateNotes(ChecklistItem item, String notes) async {
    await SupabaseService.client
        .from('checklists')
        .update({'notes': notes.isEmpty ? null : notes}).eq(
            'checklist_id', item.checklistId);

    final current = state.value!;
    final updated = current.items.map((i) {
      if (i.checklistId != item.checklistId) return i;
      return i.copyWith(notes: notes.isEmpty ? null : notes);
    }).toList();
    state = AsyncData(ChecklistState(items: updated));
  }

  /// Delete a custom item
  Future<void> deleteCustomItem(String checklistId) async {
    await SupabaseService.client
        .from('checklists')
        .delete()
        .eq('checklist_id', checklistId);

    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items.where((i) => i.checklistId != checklistId).toList(),
    ));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  /// §4.4: ticks every not-yet-answered item whose linkedSection's
  /// completeness condition (case_completeness.dart) is now met and hasn't
  /// already been evaluated once (autoTickAttempted) — a one-shot nudge,
  /// not a perpetually-enforced state, so manually un-ticking an
  /// auto-ticked item is never immediately re-ticked by the next pass even
  /// though the underlying data condition is still true. Items with no
  /// linkedSection, or a linkedSection this app has no clean data signal
  /// for (e.g. "attended site"), are untouched — completeFor() returns
  /// null for those, not false, so they're correctly never matched here.
  /// Items the surveyor already explicitly answered No or N/A are also
  /// left alone — auto-tick only ever fills in a genuinely blank item, it
  /// never overrides an explicit manual answer.
  Future<void> autoTickIfReady(CaseCompleteness completeness) async {
    final current = state.value;
    if (current == null) return;
    final toTick = current.items.where((i) =>
        i.response == null &&
        !i.autoTickAttempted &&
        completeness.completeFor(i.linkedSection ?? '') == true);

    for (final item in toTick) {
      final now = DateTime.now();
      final updated = (state.value ?? current).items.map((i) {
        if (i.checklistId != item.checklistId) return i;
        return i.copyWith(
            response: ChecklistResponse.yes,
            answeredAt: now,
            autoTickAttempted: true);
      }).toList();
      state = AsyncData(ChecklistState(items: updated));

      await SupabaseService.client.from('checklists').update({
        'response': ChecklistResponse.yes.value,
        'completed_at': now.toIso8601String(),
        'completed_by': SupabaseService.userId,
        'auto_tick_attempted': true,
      }).eq('checklist_id', item.checklistId);
    }
  }
}
