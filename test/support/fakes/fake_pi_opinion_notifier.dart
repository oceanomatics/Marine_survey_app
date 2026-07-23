import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_opinion_provider.dart';

/// Widget-test double for the P&I Opinion register.
class FakePiOpinionNotifier extends PiOpinionNotifier {
  FakePiOpinionNotifier([this._seed = const []]);
  final List<PiOpinionModel> _seed;
  int _counter = 0;

  @override
  Future<List<PiOpinionModel>> build(String caseId) async => _seed;

  @override
  Future<PiOpinionModel> add(String opinionText,
      {String? heading, String? basis, int sortOrder = 0}) async {
    final o = PiOpinionModel(
      id: 'fake-op-${++_counter}',
      caseId: arg,
      opinionText: opinionText,
      heading: heading,
      basis: basis,
      sortOrder: sortOrder,
    );
    state = AsyncData([...(state.value ?? []), o]);
    return o;
  }

  @override
  Future<void> updateFields(String id,
      {String? opinionText,
      String? heading,
      String? basis,
      String? qualifierNote}) async {
    state = AsyncData((state.value ?? [])
        .map((o) => o.id == id
            ? o.copyWith(
                opinionText: opinionText,
                heading: heading,
                basis: basis,
                qualifierNote: qualifierNote)
            : o)
        .toList());
  }

  @override
  Future<void> setQualifiers(String id,
      {bool? outsideExpertise, bool? notConcluded}) async {
    state = AsyncData((state.value ?? [])
        .map((o) => o.id == id
            ? o.copyWith(
                outsideExpertise: outsideExpertise, notConcluded: notConcluded)
            : o)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((o) => o.id != id).toList());
  }
}
