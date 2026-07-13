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
  Future<void> setResponse(
      ChecklistItem item, ChecklistResponse response) async {
    final now = DateTime.now();
    final current = state.value!;
    state = AsyncData(ChecklistState(
      items: current.items
          .map((i) => i.checklistId == item.checklistId
              ? i.copyWith(response: response, answeredAt: now)
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
          .map((i) => i.stage == stage && i.response == null
              ? i.copyWith(response: ChecklistResponse.yes, answeredAt: now)
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
  // in-memory — this fires from this fake's own build() via
  // ref.listen(caseCompletenessProvider(...)), same as the real notifier,
  // so it must never fall through to the real Supabase-backed
  // implementation in a widget test. Critically, it must also never
  // reassign `state` when nothing actually changed — an unconditional
  // `state = AsyncData(...)` here would be a new object reference every
  // time the listened-to provider recomputes even when no item's
  // eligibility changed, which Riverpod treats as a genuine change and
  // triggers another completeness recompute... an infinite loop that only
  // shows up as "pumpAndSettle timed out", not a clean crash (caught the
  // hard way authoring this test).
  @override
  Future<void> autoTickIfReady(CaseCompleteness completeness) async {
    final current = state.value!;
    final now = DateTime.now();
    var changed = false;
    final items = current.items.map((i) {
      if (i.response != null || i.autoTickAttempted) return i;
      if (completeness.completeFor(i.linkedSection ?? '') == true) {
        changed = true;
        return i.copyWith(
            response: ChecklistResponse.yes,
            answeredAt: now,
            autoTickAttempted: true);
      }
      return i;
    }).toList();
    if (changed) {
      state = AsyncData(ChecklistState(items: items));
    }
  }
}
