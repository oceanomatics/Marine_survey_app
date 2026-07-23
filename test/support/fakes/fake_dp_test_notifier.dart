import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/dp/models/dp_models.dart';
import 'package:marine_survey_app/features/dp/providers/dp_test_provider.dart';

/// Widget-test double for the DP trials test register.
class FakeDpTestNotifier extends DpTestNotifier {
  FakeDpTestNotifier([this._seed = const []]);
  final List<DpTestModel> _seed;
  int _counter = 0;

  @override
  Future<List<DpTestModel>> build(String caseId) async => _seed;

  @override
  Future<DpTestModel> add(String testName, {int? testNo, String? system}) async {
    final t = DpTestModel(
      testId: 'fake-dp-${++_counter}',
      caseId: arg,
      testName: testName,
      testNo: testNo,
      system: system,
    );
    state = AsyncData([...(state.value ?? []), t]);
    return t;
  }

  @override
  Future<void> setResult(String testId, DpTestResult? result) async =>
      _patch(testId, (t) => t.copyWith(result: result));

  @override
  Future<void> setFindingCategory(
          String testId, DpFindingCategory? category) async =>
      _patch(testId, (t) => t.copyWith(findingCategory: category));

  @override
  Future<void> setObservations(String testId, String observations) async =>
      _patch(testId, (t) => t.copyWith(observations: observations));

  @override
  Future<void> setWcfTested(String testId, bool value) async =>
      _patch(testId, (t) => t.copyWith(wcfTested: value));

  @override
  Future<void> setCarriedForward(String testId, bool value) async =>
      _patch(testId, (t) => t.copyWith(carriedForward: value));

  @override
  Future<void> delete(String testId) async {
    state =
        AsyncData((state.value ?? []).where((t) => t.testId != testId).toList());
  }

  void _patch(String testId, DpTestModel Function(DpTestModel) update) {
    state = AsyncData((state.value ?? [])
        .map((t) => t.testId == testId ? update(t) : t)
        .toList());
  }
}
