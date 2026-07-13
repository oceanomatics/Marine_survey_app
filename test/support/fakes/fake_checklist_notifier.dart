// Widget-test double for ChecklistNotifier — skips SupabaseService.client
// entirely so ChecklistScreen can be pumped with ProviderScope overrides and
// no network/auth setup. Mutation methods replay the same optimistic-update
// logic as the real notifier (see checklist_provider.dart) but never persist,
// which is exactly the boundary a widget test should sit at: it proves the
// screen reacts correctly to state changes, not that Supabase writes succeed
// (that remains a Manual/Integ concern — see TEST_SHEET.md).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/checklist/providers/checklist_provider.dart';
import 'package:marine_survey_app/features/reports/providers/case_completeness_provider.dart';
import 'package:marine_survey_app/features/reports/utils/case_completeness.dart';

class FakeChecklistNotifier extends ChecklistNotifier {
  FakeChecklistNotifier(this._seed);
  final List<ChecklistItem> _seed;

  @override
  Future<ChecklistState> build(String caseId) async {
    // Mirrors the real notifier's build() (checklist_provider.dart) — auto-
    // tick is driven by listening to caseCompletenessProvider from here,
    // not from ChecklistScreen's build(), so the widget tests exercising
    // auto-tick need this fake to actually wire the listener up too.
    ref.listen(caseCompletenessProvider(caseId), (previous, next) {
      autoTickIfReady(next);
    });
    return ChecklistState(items: _seed);
  }

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

  // §4.4: same one-shot-nudge semantics as the real notifier, replayed
  // in-memory — this is the method ChecklistScreen calls reactively from a
  // post-frame callback on every build, so it must never fall through to
  // the real Supabase-backed implementation in a widget test. Critically,
  // it must also match the real notifier's behaviour of never reassigning
  // `state` when nothing actually changed: ChecklistScreen re-registers this
  // same post-frame callback on every rebuild, so an unconditional
  // `state = AsyncData(...)` here — even to an equivalent value — is a new
  // object reference every time, which Riverpod treats as a genuine change
  // and rebuilds the screen again, which calls this again... an infinite
  // loop that only shows up as "pumpAndSettle timed out", not a clean crash
  // (caught the hard way authoring this test).
  @override
  Future<void> autoTickIfReady(CaseCompleteness completeness) async {
    final current = state.value!;
    final now = DateTime.now();
    var changed = false;
    final items = current.items.map((i) {
      if (i.completed || i.autoTickAttempted) return i;
      if (completeness.completeFor(i.linkedSection ?? '') == true) {
        changed = true;
        return i.copyWith(
            completed: true, completedAt: now, autoTickAttempted: true);
      }
      return i;
    }).toList();
    if (changed) {
      state = AsyncData(ChecklistState(items: items));
    }
  }
}
