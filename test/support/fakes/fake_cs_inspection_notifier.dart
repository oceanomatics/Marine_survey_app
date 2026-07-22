import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_inspection_provider.dart';

/// Widget-test double for the C&S inspection register — replays the real
/// notifier's optimistic updates without touching Supabase.
class FakeCsInspectionNotifier extends CsInspectionNotifier {
  FakeCsInspectionNotifier([this._seed = const []]);
  final List<CsInspectionItemModel> _seed;
  int _counter = 0;

  @override
  Future<List<CsInspectionItemModel>> build(String caseId) async => _seed;

  @override
  Future<CsInspectionItemModel> addItem({
    String? templateItemId,
    String? sectionId,
    CsGrade? grade,
    String? remark,
    int sortOrder = 0,
  }) async {
    final item = CsInspectionItemModel(
      id: 'fake-insp-${++_counter}',
      caseId: arg,
      templateItemId: templateItemId,
      sectionId: sectionId,
      grade: grade,
      remark: remark,
      isNa: grade == CsGrade.na,
      sortOrder: sortOrder,
    );
    state = AsyncData([...(state.value ?? []), item]);
    return item;
  }

  @override
  Future<void> setGrade(String id, CsGrade? grade) async {
    state = AsyncData((state.value ?? [])
        .map((i) => i.id == id
            ? i.copyWith(grade: grade, isNa: grade == CsGrade.na)
            : i)
        .toList());
  }

  @override
  Future<void> setRemark(String id, String remark) async {
    state = AsyncData((state.value ?? [])
        .map((i) => i.id == id ? i.copyWith(remark: remark) : i)
        .toList());
  }

  @override
  Future<void> setNa(String id, bool isNa) async {
    state = AsyncData((state.value ?? [])
        .map((i) => i.id == id
            ? i.copyWith(isNa: isNa, grade: isNa ? CsGrade.na : i.grade)
            : i)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((i) => i.id != id).toList());
  }
}
