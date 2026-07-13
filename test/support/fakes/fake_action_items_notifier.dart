import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/action_items/providers/action_items_provider.dart';

/// Widget-test double — replays the same optimistic-update shape as the
/// real notifier without touching Supabase. See fake_checklist_notifier.dart
/// for why every mutation must reassign `state` (Riverpod change detection)
/// but ONLY when something actually changed (an unconditional reassignment
/// on every call is fine here since none of these are called reactively
/// from a post-frame callback the way checklist auto-tick is — no infinite
/// -loop risk — but kept minimal regardless).
class FakeActionItemsNotifier extends ActionItemsNotifier {
  FakeActionItemsNotifier([this._seed = const []]);
  final List<ActionItemModel> _seed;
  int _counter = 0;

  @override
  Future<List<ActionItemModel>> build(String caseId) async => _seed;

  @override
  Future<void> addManual(String caseId, String text, {DateTime? dueDate}) async {
    final item = ActionItemModel(
      id: 'fake-item-${++_counter}',
      caseId: caseId,
      text: text,
      sourceType: 'manual',
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    state = AsyncData([item, ...(state.value ?? [])]);
  }

  @override
  Future<void> addSuggested(String caseId, String text,
      {required String sourceId}) async {
    final item = ActionItemModel(
      id: 'fake-item-${++_counter}',
      caseId: caseId,
      text: text,
      sourceType: 'correspondence',
      sourceId: sourceId,
      pendingReview: true,
      createdAt: DateTime.now(),
    );
    state = AsyncData([item, ...(state.value ?? [])]);
  }

  @override
  bool alreadySuggested(String sourceId, String text) =>
      (state.value ?? []).any(
          (i) => i.sourceId == sourceId && i.text == text);

  @override
  Future<void> confirm(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((i) => i.id == id ? i.copyWith(pendingReview: false) : i)
        .toList());
  }

  @override
  Future<void> setStatus(String id, ActionItemStatus status) async {
    final current = state.value ?? [];
    state = AsyncData(current
        .map((i) => i.id == id
            ? i.copyWith(
                status: status,
                completedAt:
                    status == ActionItemStatus.open ? null : DateTime.now())
            : i)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((i) => i.id != id).toList());
  }
}
