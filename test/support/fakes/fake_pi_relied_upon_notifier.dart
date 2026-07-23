import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_relied_upon_provider.dart';

/// Widget-test double for the P&I Facts & Documents Relied Upon register.
class FakePiReliedUponNotifier extends PiReliedUponNotifier {
  FakePiReliedUponNotifier([this._seed = const []]);
  final List<PiReliedUponModel> _seed;
  int _counter = 0;

  @override
  Future<List<PiReliedUponModel>> build(String caseId) async => _seed;

  @override
  Future<PiReliedUponModel> add(String description,
      {String? reference, String? documentId, int sortOrder = 0}) async {
    final r = PiReliedUponModel(
      id: 'fake-ru-${++_counter}',
      caseId: arg,
      description: description,
      reference: reference,
      documentId: documentId,
      sortOrder: sortOrder,
    );
    state = AsyncData([...(state.value ?? []), r]);
    return r;
  }

  @override
  Future<void> updateFields(String id,
      {String? description, String? reference}) async {
    state = AsyncData((state.value ?? [])
        .map((r) => r.id == id
            ? r.copyWith(description: description, reference: reference)
            : r)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((r) => r.id != id).toList());
  }
}
