// Widget-test double for NatureOfRepairsNotifier — skips
// SupabaseService.client entirely, replaying each setter's effect locally.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/models/nature_of_repairs_model.dart';
import 'package:marine_survey_app/features/survey/providers/nature_of_repairs_provider.dart';

class FakeNatureOfRepairsNotifier extends NatureOfRepairsNotifier {
  FakeNatureOfRepairsNotifier([this._seed]);
  final NatureOfRepairs? _seed;
  int _counter = 0;

  @override
  Future<NatureOfRepairs> build(String caseId) async =>
      _seed ?? NatureOfRepairs.empty(caseId);

  NatureOfRepairs get _current => state.value ?? NatureOfRepairs.empty(arg);

  @override
  Future<void> setDrydocking(bool required, String? comment) async {
    state = AsyncData(_rebuild(
        drydockingRequired: required, drydockingComment: comment));
  }

  @override
  Future<void> setAssuredPlan(bool value, String? comment) async {
    state = AsyncData(_rebuild(
        assuredPlanFormulated: value, assuredPlanComment: comment));
  }

  @override
  Future<void> setFurtherInspections(bool value, String? comment) async {
    state = AsyncData(_rebuild(
        furtherInspectionsPlanned: value, furtherInspectionsComment: comment));
  }

  @override
  Future<void> setPartsLeadTime(bool value, String? comment) async {
    state = AsyncData(
        _rebuild(partsLongLeadTime: value, partsLeadTimeComment: comment));
  }

  @override
  Future<void> setForeseeableDifficulties(bool value, String? comment) async {
    state = AsyncData(_rebuild(
        foreseeableDifficulties: value,
        foreseeableDifficultiesComment: comment));
  }

  @override
  Future<void> addSequenceItem(String text) async {
    final updated = [
      ..._current.sequenceItems,
      RepairSequenceItem(itemId: 'fake-item-${++_counter}', text: text),
    ];
    state = AsyncData(_rebuild(sequenceItems: updated));
  }

  @override
  Future<void> removeSequenceItem(String itemId) async {
    final updated =
        _current.sequenceItems.where((i) => i.itemId != itemId).toList();
    state = AsyncData(_rebuild(sequenceItems: updated));
  }

  @override
  Future<void> reorderSequenceItems(int oldIndex, int newIndex) async {
    state = AsyncData(_rebuild(
        sequenceItems:
            reorderedList(_current.sequenceItems, oldIndex, newIndex)));
  }

  NatureOfRepairs _rebuild({
    bool? drydockingRequired,
    String? drydockingComment,
    bool? assuredPlanFormulated,
    String? assuredPlanComment,
    bool? furtherInspectionsPlanned,
    String? furtherInspectionsComment,
    bool? partsLongLeadTime,
    String? partsLeadTimeComment,
    bool? foreseeableDifficulties,
    String? foreseeableDifficultiesComment,
    List<RepairSequenceItem>? sequenceItems,
  }) {
    final c = _current;
    return NatureOfRepairs(
      caseId: c.caseId,
      drydockingRequired: drydockingRequired ?? c.drydockingRequired,
      drydockingComment: drydockingComment ?? c.drydockingComment,
      assuredPlanFormulated: assuredPlanFormulated ?? c.assuredPlanFormulated,
      assuredPlanComment: assuredPlanComment ?? c.assuredPlanComment,
      furtherInspectionsPlanned:
          furtherInspectionsPlanned ?? c.furtherInspectionsPlanned,
      furtherInspectionsComment:
          furtherInspectionsComment ?? c.furtherInspectionsComment,
      partsLongLeadTime: partsLongLeadTime ?? c.partsLongLeadTime,
      partsLeadTimeComment: partsLeadTimeComment ?? c.partsLeadTimeComment,
      foreseeableDifficulties:
          foreseeableDifficulties ?? c.foreseeableDifficulties,
      foreseeableDifficultiesComment:
          foreseeableDifficultiesComment ?? c.foreseeableDifficultiesComment,
      sequenceItems: sequenceItems ?? c.sequenceItems,
      updatedAt: DateTime.now(),
    );
  }
}
