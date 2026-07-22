import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_recommendation_provider.dart';

/// Widget-test double for the C&S recommendations register.
class FakeCsRecommendationNotifier extends CsRecommendationNotifier {
  FakeCsRecommendationNotifier([this._seed = const []]);
  final List<CsRecommendationModel> _seed;
  int _counter = 0;

  @override
  Future<List<CsRecommendationModel>> build(String caseId) async => _seed;

  @override
  Future<CsRecommendationModel> add(String text,
      {String? refNo, String? sourceItemId}) async {
    final rec = CsRecommendationModel(
      id: 'fake-rec-${++_counter}',
      caseId: arg,
      text: text,
      refNo: refNo,
      sourceItemId: sourceItemId,
    );
    state = AsyncData([...(state.value ?? []), rec]);
    return rec;
  }

  @override
  Future<CsRecommendationModel> addFromItem(CsInspectionItemModel item,
          {String? text}) =>
      add(text ?? item.remark ?? '', sourceItemId: item.id);

  @override
  Future<void> updateText(String id, String text) async {
    state = AsyncData((state.value ?? [])
        .map((r) => r.id == id ? r.copyWith(text: text) : r)
        .toList());
  }

  @override
  Future<void> setStatus(String id, CsRecommendationStatus status) async {
    state = AsyncData((state.value ?? [])
        .map((r) => r.id == id
            ? r.copyWith(
                status: status,
                closeDate:
                    status == CsRecommendationStatus.closed ? DateTime.now() : null)
            : r)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((r) => r.id != id).toList());
  }
}
