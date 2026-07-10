import 'package:flutter_riverpod/flutter_riverpod.dart';
// Widget-test double for DamageNotifier (Occurrence / Damage Register /
// Repair Periods screens all read this same provider) — skips
// SupabaseService.client and replays the same optimistic-update /
// renumber-and-set-primary shape as the real notifier (damage_provider.dart)
// without touching the network.
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';

class FakeDamageNotifier extends DamageNotifier {
  FakeDamageNotifier(this._seed);
  final DamageState _seed;
  int _occCounter = 0;
  int _dmgCounter = 0;
  int _repairCounter = 0;

  @override
  Future<DamageState> build(String caseId) async => _seed;

  // ── Occurrences ────────────────────────────────────────────────────────

  @override
  Future<OccurrenceModel> createOccurrence({
    required String caseId,
    required String title,
    DateTime? dateTime,
    String? location,
    String? briefDescription,
    String? vesselStatusAtCasualty,
    String? aftermathStatus,
    String? aftermathPort,
  }) async {
    final current = state.value!;
    final occ = OccurrenceModel(
      occurrenceId: 'fake-occ-${++_occCounter}',
      caseId: caseId,
      occurrenceNo: current.occurrences.length + 1,
      isPrimary: current.occurrences.isEmpty,
      title: title,
      dateTime: dateTime,
      location: location,
      briefDescription: briefDescription,
      vesselStatusAtCasualty: vesselStatusAtCasualty,
      aftermathStatus: aftermathStatus,
      aftermathPort: aftermathPort,
      createdAt: DateTime.now(),
    );
    state = AsyncData(DamageState(
      occurrences: [...current.occurrences, occ],
      damageItems: current.damageItems,
      repairs: current.repairs,
    ));
    return occ;
  }

  @override
  Future<void> updateOccurrence(OccurrenceModel occ) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences
          .map((o) => o.occurrenceId == occ.occurrenceId ? occ : o)
          .toList(),
      damageItems: current.damageItems,
      repairs: current.repairs,
    ));
  }

  @override
  Future<void> setPrimaryOccurrence(String occurrenceId) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences
          .map((o) => _withPrimary(o, o.occurrenceId == occurrenceId))
          .toList(),
      damageItems: current.damageItems,
      repairs: current.repairs,
    ));
  }

  static OccurrenceModel _withPrimary(OccurrenceModel o, bool isPrimary) =>
      OccurrenceModel(
        occurrenceId: o.occurrenceId,
        caseId: o.caseId,
        occurrenceNo: o.occurrenceNo,
        isPrimary: isPrimary,
        dateTime: o.dateTime,
        location: o.location,
        title: o.title,
        briefDescription: o.briefDescription,
        backgroundNarrative: o.backgroundNarrative,
        chronology: o.chronology,
        causeType: o.causeType,
        allegationType: o.allegationType,
        causeAgreement: o.causeAgreement,
        causeNarrative: o.causeNarrative,
        ismReported: o.ismReported,
        createdAt: o.createdAt,
        vesselStatusAtCasualty: o.vesselStatusAtCasualty,
        aftermathStatus: o.aftermathStatus,
        aftermathPort: o.aftermathPort,
        ownersStatedCause: o.ownersStatedCause,
        ownersStatedCauseSource: o.ownersStatedCauseSource,
        thirdPartyFindings: o.thirdPartyFindings,
        surveyorsAssessment: o.surveyorsAssessment,
        certaintyLevel: o.certaintyLevel,
      );

  @override
  Future<void> deleteOccurrence(String occurrenceId) async {
    final current = state.value!;
    final remainingDamage = current.damageItems
        .where((d) => d.occurrenceId != occurrenceId)
        .toList();
    state = AsyncData(DamageState(
      occurrences:
          current.occurrences.where((o) => o.occurrenceId != occurrenceId).toList(),
      damageItems: remainingDamage,
      repairs:
          current.repairs.where((r) => r.occurrenceId != occurrenceId).toList(),
    ));
  }

  // ── Damage items ─────────────────────────────────────────────────────────

  @override
  Future<DamageItemModel> addDamageItem(DamageItemModel item) async {
    final current = state.value!;
    final existing = current.itemsForOccurrence(item.occurrenceId);
    final nextSeq = existing.isEmpty ? 1 : existing.last.sequenceNo + 1;
    final created = item._withIdAndSeq('fake-dmg-${++_dmgCounter}', nextSeq);
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: [...current.damageItems, created],
      repairs: current.repairs,
    ));
    return created;
  }

  @override
  Future<void> updateDamageItem(DamageItemModel item) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems
          .map((d) => d.damageId == item.damageId ? item : d)
          .toList(),
      repairs: current.repairs,
    ));
  }

  @override
  Future<void> deleteDamageItem(String damageId) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems:
          current.damageItems.where((d) => d.damageId != damageId).toList(),
      repairs: current.repairs,
    ));
  }

  // ── Repairs ──────────────────────────────────────────────────────────────

  @override
  Future<RepairModel> addRepair(RepairModel repair) async {
    final current = state.value!;
    final created = RepairModel(
      repairId: 'fake-repair-${++_repairCounter}',
      occurrenceId: repair.occurrenceId,
      caseId: repair.caseId,
      repairType: repair.repairType,
      repairStatus: repair.repairStatus,
      description: repair.description,
      estimatedCost: repair.estimatedCost,
      actualCost: repair.actualCost,
      completionDate: repair.completionDate,
      notes: repair.notes,
      linkedDamageIds: repair.linkedDamageIds,
    );
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs: [...current.repairs, created],
    ));
    return created;
  }

  @override
  Future<void> updateRepair(RepairModel repair) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs: current.repairs
          .map((r) => r.repairId == repair.repairId ? repair : r)
          .toList(),
    ));
  }

  @override
  Future<void> deleteRepair(String repairId) async {
    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs: current.repairs.where((r) => r.repairId != repairId).toList(),
    ));
  }

  @override
  Future<void> refresh() async {}
}

// Small private helper so the fake doesn't need to hand-roll every field of
// the immutable DamageItemModel just to assign an id/sequence number.
extension _DamageWithId on DamageItemModel {
  DamageItemModel _withIdAndSeq(String id, int seq) => DamageItemModel(
        damageId: id,
        occurrenceId: occurrenceId,
        caseId: caseId,
        componentName: componentName,
        damageCategory: damageCategory,
        machineryId: machineryId,
        componentId: componentId,
        locationOnVessel: locationOnVessel,
        damageDescription: damageDescription,
        conditionFound: conditionFound,
        repairType: repairType,
        repairStatus: repairStatus,
        isConcerningAverage: isConcerningAverage,
        exclusionReason: exclusionReason,
        sequenceNo: seq,
        photoCount: photoCount,
        conditionStatus: conditionStatus,
        confirmedBy: confirmedBy,
        confirmationDate: confirmationDate,
        confirmationMethod: confirmationMethod,
        averageStatus: averageStatus,
        averagePartialDetail: averagePartialDetail,
        createdAt: DateTime.now(),
      );
}
