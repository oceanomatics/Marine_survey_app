// Widget-test double for CostEstimateItemsNotifier — skips
// SupabaseService.client entirely but replays the same optimistic-update
// logic as the real one. Mirrors fake_repair_documents_notifier.dart etc.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/accounts/models/accounts_models.dart';
import 'package:marine_survey_app/features/accounts/providers/accounts_provider.dart';

class FakeCostEstimateItemsNotifier extends CostEstimateItemsNotifier {
  FakeCostEstimateItemsNotifier([this._seed = const []]);
  final List<CostEstimateItemModel> _seed;
  int _counter = 0;

  @override
  Future<List<CostEstimateItemModel>> build(String caseId) async => _seed;

  @override
  Future<void> addItem({
    CostEstimateCategory category = CostEstimateCategory.generalExpenses,
    String? description,
    double amount = 0,
  }) async {
    final current = state.value ?? [];
    final item = CostEstimateItemModel(
      id: 'fake-cei-${++_counter}',
      caseId: arg,
      category: category,
      description: description,
      amount: amount,
      sortOrder: current.length,
    );
    state = AsyncData([...current, item]);
  }

  @override
  Future<void> updateItem(CostEstimateItemModel item) async {
    final current = state.value ?? [];
    state = AsyncData(current.map((i) => i.id == item.id ? item : i).toList());
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((i) => i.id != itemId).toList());
  }
}
