// Widget-test double for ChecklistNotifier — skips SupabaseService.client
// entirely so ChecklistScreen can be pumped with ProviderScope overrides and
// no network/auth setup. Mutation methods replay the same optimistic-update
// logic as the real notifier (see checklist_provider.dart) but never persist,
// which is exactly the boundary a widget test should sit at: it proves the
// screen reacts correctly to state changes, not that Supabase writes succeed
// (that remains a Manual/Integ concern — see TEST_SHEET.md).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/checklist/providers/checklist_provider.dart';

class FakeChecklistNotifier extends ChecklistNotifier {
  FakeChecklistNotifier(this._seed);
  final List<ChecklistItem> _seed;

  @override
  Future<ChecklistState> build(String caseId) async =>
      ChecklistState(items: _seed);

  @override
  Future<void> toggleItem(ChecklistItem item) async {
    final nowDone = !item.completed;
    final now = DateTime.now();
    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items
          .map((i) => i.checklistId == item.checklistId
              ? i.copyWith(completed: nowDone, completedAt: nowDone ? now : null)
              : i)
          .toList(),
    ));
  }

  @override
  Future<void> completeStage(ChecklistStage stage) async {
    final now = DateTime.now();
    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items
          .map((i) => i.stage == stage
              ? i.copyWith(completed: true, completedAt: now)
              : i)
          .toList(),
    ));
  }

  @override
  Future<void> addCustomItem({
    required String caseId,
    required ChecklistStage stage,
    required String text,
  }) async {
    final current = state.value!;
    final stageItems = current.forStage(stage);
    final nextNo = stageItems.isEmpty ? 100 : stageItems.last.itemNo + 1;
    final newItem = ChecklistItem(
      checklistId: 'fake-${current.items.length + 1}',
      caseId: caseId,
      stage: stage,
      itemNo: nextNo,
      itemText: text,
      completed: false,
      isCustom: true,
    );
    state = AsyncData(ChecklistState(items: [...current.items, newItem]));
  }

  @override
  Future<void> updateNotes(ChecklistItem item, String notes) async {
    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items
          .map((i) => i.checklistId == item.checklistId
              ? i.copyWith(notes: notes.isEmpty ? null : notes)
              : i)
          .toList(),
    ));
  }

  @override
  Future<void> deleteCustomItem(String checklistId) async {
    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items.where((i) => i.checklistId != checklistId).toList(),
    ));
  }
}
