// lib/features/checklist/providers/checklist_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
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

// ── Model ─────────────────────────────────────────────────────────────────

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.checklistId,
    required this.caseId,
    required this.stage,
    required this.itemNo,
    required this.itemText,
    required this.completed,
    this.completedAt,
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
  final bool completed;
  final DateTime? completedAt;
  final String? linkedSection;
  final String? linkedId;
  final String? notes;
  final bool isCustom;

  /// §4.4: true once the auto-tick evaluator has acted on this item — a
  /// one-shot marker so a surveyor manually un-ticking an auto-ticked item
  /// is never immediately re-ticked by the next pass, even though the
  /// underlying data condition is still true.
  final bool autoTickAttempted;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        checklistId: j['checklist_id'] as String,
        caseId: j['case_id'] as String,
        stage: ChecklistStage.fromValue(j['stage'] as String? ?? 'on_vessel'),
        itemNo: j['item_no'] as int,
        itemText: j['item_text'] as String,
        completed: j['completed'] as bool? ?? false,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)
            : null,
        linkedSection: j['linked_section'] as String?,
        linkedId: j['linked_id'] as String?,
        notes: j['notes'] as String?,
        isCustom: j['is_custom'] as bool? ?? false,
        autoTickAttempted: j['auto_tick_attempted'] as bool? ?? false,
      );

  ChecklistItem copyWith(
          {bool? completed,
          DateTime? completedAt,
          String? notes,
          bool? autoTickAttempted}) =>
      ChecklistItem(
        checklistId: checklistId,
        caseId: caseId,
        stage: stage,
        itemNo: itemNo,
        itemText: itemText,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
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

  int get totalCount => items.length;
  int get completedCount => items.where((i) => i.completed).length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  int stageTotal(ChecklistStage stage) =>
      items.where((i) => i.stage == stage).length;
  int stageCompleted(ChecklistStage stage) =>
      items.where((i) => i.stage == stage && i.completed).length;
  double stageProgress(ChecklistStage stage) {
    final total = stageTotal(stage);
    return total == 0 ? 0 : stageCompleted(stage) / total;
  }

  // Are all mandatory (non-custom) items in a stage done?
  bool stageComplete(ChecklistStage stage) {
    final stageItems = items.where((i) => i.stage == stage);
    return stageItems.isNotEmpty && stageItems.every((i) => i.completed);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final checklistProvider =
    AsyncNotifierProviderFamily<ChecklistNotifier, ChecklistState, String>(
  ChecklistNotifier.new,
);

class ChecklistNotifier extends FamilyAsyncNotifier<ChecklistState, String> {
  @override
  Future<ChecklistState> build(String caseId) => _fetch(caseId);

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

  /// Toggle a single item completed / not completed
  Future<void> toggleItem(ChecklistItem item) async {
    final nowDone = !item.completed;
    final now = DateTime.now();

    // Optimistic update
    final current = state.value!;
    final updated = current.items.map((i) {
      if (i.checklistId != item.checklistId) return i;
      return i.copyWith(
        completed: nowDone,
        completedAt: nowDone ? now : null,
      );
    }).toList();
    state = AsyncData(ChecklistState(items: updated));

    // Persist
    await SupabaseService.client.from('checklists').update({
      'completed': nowDone,
      'completed_at': nowDone ? now.toIso8601String() : null,
      'completed_by': SupabaseService.userId,
    }).eq('checklist_id', item.checklistId);
  }

  /// Mark all items in a stage as complete
  Future<void> completeStage(ChecklistStage stage) async {
    final now = DateTime.now();
    final current = state.value!;
    final stageIds = current
        .forStage(stage)
        .where((i) => !i.completed)
        .map((i) => i.checklistId)
        .toList();

    if (stageIds.isEmpty) return;

    // Optimistic update
    final updated = current.items.map((i) {
      if (i.stage != stage) return i;
      return i.copyWith(completed: true, completedAt: now);
    }).toList();
    state = AsyncData(ChecklistState(items: updated));

    // Persist — update each
    for (final id in stageIds) {
      await SupabaseService.client.from('checklists').update({
        'completed': true,
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
          'completed': false,
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

  /// §4.4: ticks every incomplete item whose linkedSection's completeness
  /// condition (case_completeness.dart) is now met and hasn't already been
  /// evaluated once (autoTickAttempted) — a one-shot nudge, not a
  /// perpetually-enforced state, so manually un-ticking an auto-ticked item
  /// is never immediately re-ticked by the next pass even though the
  /// underlying data condition is still true. Items with no linkedSection,
  /// or a linkedSection this app has no clean data signal for (e.g.
  /// "attended site"), are untouched — completeFor() returns null for
  /// those, not false, so they're correctly never matched here.
  Future<void> autoTickIfReady(CaseCompleteness completeness) async {
    final current = state.value;
    if (current == null) return;
    final toTick = current.items.where((i) =>
        !i.completed &&
        !i.autoTickAttempted &&
        completeness.completeFor(i.linkedSection ?? '') == true);

    for (final item in toTick) {
      final now = DateTime.now();
      final updated = (state.value ?? current).items.map((i) {
        if (i.checklistId != item.checklistId) return i;
        return i.copyWith(
            completed: true, completedAt: now, autoTickAttempted: true);
      }).toList();
      state = AsyncData(ChecklistState(items: updated));

      await SupabaseService.client.from('checklists').update({
        'completed': true,
        'completed_at': now.toIso8601String(),
        'completed_by': SupabaseService.userId,
        'auto_tick_attempted': true,
      }).eq('checklist_id', item.checklistId);
    }
  }
}
