import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/vessel/models/class_condition_model.dart';
import 'package:marine_survey_app/features/vessel/providers/class_conditions_provider.dart';

class FakeClassConditionsNotifier extends ClassConditionsNotifier {
  FakeClassConditionsNotifier(this._seed);
  final List<ClassConditionModel> _seed;
  int _counter = 0;

  @override
  Future<List<ClassConditionModel>> build(String vesselId) async => _seed;

  @override
  Future<void> add({
    required String vesselId,
    String? reference,
    String? description,
    DateTime? expiryDate,
    String? duration,
    bool occurrenceRelated = false,
    String? occurrenceId,
  }) async {
    final created = ClassConditionModel(
      conditionId: 'fake-cond-${++_counter}',
      vesselId: vesselId,
      reference: reference,
      description: description,
      expiryDate: expiryDate,
      duration: duration,
      occurrenceRelated: occurrenceRelated,
      occurrenceId: occurrenceId,
    );
    state = AsyncData([...state.value ?? [], created]);
  }

  @override
  Future<void> updateCondition(
    String conditionId, {
    String? reference,
    String? description,
    DateTime? expiryDate,
    String? duration,
    bool? occurrenceRelated,
    String? occurrenceId,
  }) async {
    final current = state.value ?? [];
    state = AsyncData(current.map((c) {
      if (c.conditionId != conditionId) return c;
      return c.copyWith(
        reference: reference,
        description: description,
        expiryDate: expiryDate,
        duration: duration,
        occurrenceRelated: occurrenceRelated,
        occurrenceId: occurrenceId,
      );
    }).toList());
  }

  @override
  Future<void> delete(String conditionId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((c) => c.conditionId != conditionId).toList());
  }
}
