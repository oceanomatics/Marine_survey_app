// lib/features/survey/providers/damage_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum RepairType {
  temporary('temporary', 'Temporary'),
  permanent('permanent', 'Permanent'),
  partPermanent('part_permanent', 'Part Permanent'),
  deferred('deferred', 'Deferred');

  const RepairType(this.value, this.label);
  final String value;
  final String label;

  static RepairType fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => RepairType.permanent);
}

enum RepairStatus {
  notStarted('not_started', 'Not Started'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  deferred('deferred', 'Deferred');

  const RepairStatus(this.value, this.label);
  final String value;
  final String label;

  static RepairStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => RepairStatus.notStarted);
}

// ── Occurrence model ───────────────────────────────────────────────────────

@immutable
class OccurrenceModel {
  const OccurrenceModel({
    required this.occurrenceId,
    required this.caseId,
    required this.occurrenceNo,
    this.dateTime,
    this.location,
    this.title,
    this.briefDescription,
    this.backgroundNarrative,
    this.chronology,
    this.allegationType,
    this.causeNarrative,
    this.ismReported,
    this.createdAt,
  });

  final String occurrenceId;
  final String caseId;
  final int occurrenceNo;
  final DateTime? dateTime;
  final String? location;
  final String? title;
  final String? briefDescription;
  final String? backgroundNarrative;
  final String? chronology;
  final String? allegationType;
  final String? causeNarrative;
  final bool? ismReported;
  final DateTime? createdAt;

  factory OccurrenceModel.fromJson(Map<String, dynamic> j) => OccurrenceModel(
        occurrenceId:      j['occurrence_id'] as String,
        caseId:            j['case_id'] as String,
        occurrenceNo:      j['occurrence_no'] as int? ?? 1,
        dateTime:          j['date_time'] != null
            ? DateTime.tryParse(j['date_time'] as String)
            : null,
        location:          j['location'] as String?,
        title:             j['title'] as String?,
        briefDescription:  j['brief_description'] as String?,
        backgroundNarrative: j['background_narrative'] as String?,
        chronology:        j['chronology'] as String?,
        allegationType:    j['allegation_type'] as String?,
        causeNarrative:    j['cause_narrative'] as String?,
        ismReported:       j['ism_reported'] as bool?,
        createdAt:         j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':       caseId,
        'occurrence_no': occurrenceNo,
        if (dateTime != null) 'date_time': dateTime!.toIso8601String(),
        if (location != null)          'location':           location,
        if (title != null)             'title':              title,
        if (briefDescription != null)  'brief_description':  briefDescription,
        if (backgroundNarrative != null)
          'background_narrative': backgroundNarrative,
        if (chronology != null)        'chronology':         chronology,
        if (allegationType != null)    'allegation_type':    allegationType,
        if (causeNarrative != null)    'cause_narrative':    causeNarrative,
        if (ismReported != null)       'ism_reported':       ismReported,
      };
}

// ── Damage item model ──────────────────────────────────────────────────────

@immutable
class DamageItemModel {
  const DamageItemModel({
    required this.damageId,
    required this.occurrenceId,
    required this.caseId,
    required this.componentName,
    this.machineryId,
    this.locationOnVessel,
    this.damageDescription,
    this.conditionFound,
    this.repairType,
    this.repairStatus = RepairStatus.notStarted,
    this.isConcerningAverage = true,
    this.exclusionReason,
    this.sequenceNo = 1,
    this.photoCount = 0,
    this.createdAt,
  });

  final String damageId;
  final String occurrenceId;
  final String caseId;
  final String componentName;
  final String? machineryId;
  final String? locationOnVessel;
  final String? damageDescription;
  final String? conditionFound;
  final RepairType? repairType;
  final RepairStatus repairStatus;
  final bool isConcerningAverage;
  final String? exclusionReason;
  final int sequenceNo;
  final int photoCount;
  final DateTime? createdAt;

  factory DamageItemModel.fromJson(Map<String, dynamic> j) => DamageItemModel(
        damageId:          j['damage_id'] as String,
        occurrenceId:      j['occurrence_id'] as String,
        caseId:            j['case_id'] as String,
        componentName:     j['component_name'] as String,
        machineryId:       j['machinery_id'] as String?,
        locationOnVessel:  j['location_on_vessel'] as String?,
        damageDescription: j['damage_description'] as String?,
        conditionFound:    j['condition_found'] as String?,
        repairType:        j['repair_type'] != null
            ? RepairType.fromValue(j['repair_type'] as String)
            : null,
        repairStatus:      RepairStatus.fromValue(
            j['repair_status'] as String? ?? 'not_started'),
        isConcerningAverage: j['is_concerning_average'] as bool? ?? true,
        exclusionReason:   j['exclusion_reason'] as String?,
        sequenceNo:        j['sequence_no'] as int? ?? 1,
        createdAt:         j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'occurrence_id':   occurrenceId,
        'case_id':         caseId,
        'component_name':  componentName,
        if (machineryId != null)       'machinery_id':        machineryId,
        if (locationOnVessel != null)  'location_on_vessel':  locationOnVessel,
        if (damageDescription != null) 'damage_description':  damageDescription,
        if (conditionFound != null)    'condition_found':     conditionFound,
        if (repairType != null)        'repair_type':         repairType!.value,
        'repair_status':               repairStatus.value,
        'is_concerning_average':       isConcerningAverage,
        if (exclusionReason != null)   'exclusion_reason':    exclusionReason,
        'sequence_no':                 sequenceNo,
      };

  DamageItemModel copyWith({
    String? componentName,
    String? machineryId,
    String? locationOnVessel,
    String? damageDescription,
    String? conditionFound,
    RepairType? repairType,
    RepairStatus? repairStatus,
    bool? isConcerningAverage,
    String? exclusionReason,
  }) =>
      DamageItemModel(
        damageId:          damageId,
        occurrenceId:      occurrenceId,
        caseId:            caseId,
        componentName:     componentName     ?? this.componentName,
        machineryId:       machineryId       ?? this.machineryId,
        locationOnVessel:  locationOnVessel  ?? this.locationOnVessel,
        damageDescription: damageDescription ?? this.damageDescription,
        conditionFound:    conditionFound    ?? this.conditionFound,
        repairType:        repairType        ?? this.repairType,
        repairStatus:      repairStatus      ?? this.repairStatus,
        isConcerningAverage: isConcerningAverage ?? this.isConcerningAverage,
        exclusionReason:   exclusionReason   ?? this.exclusionReason,
        sequenceNo:        sequenceNo,
        photoCount:        photoCount,
        createdAt:         createdAt,
      );
}

// ── Combined state ─────────────────────────────────────────────────────────

@immutable
class DamageState {
  const DamageState({
    required this.occurrences,
    required this.damageItems,
  });

  final List<OccurrenceModel> occurrences;
  final List<DamageItemModel> damageItems;

  List<DamageItemModel> itemsForOccurrence(String occurrenceId) =>
      damageItems
          .where((d) => d.occurrenceId == occurrenceId)
          .toList()
        ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));

  int get totalDamageItems => damageItems.length;
  int get averageItems =>
      damageItems.where((d) => d.isConcerningAverage).length;
  int get ownerItems =>
      damageItems.where((d) => !d.isConcerningAverage).length;
}

// ── Provider ───────────────────────────────────────────────────────────────

final damageProvider =
    AsyncNotifierProviderFamily<DamageNotifier, DamageState, String>(
  DamageNotifier.new,
);

class DamageNotifier extends FamilyAsyncNotifier<DamageState, String> {
  @override
  Future<DamageState> build(String caseId) => _fetch(caseId);

  Future<DamageState> _fetch(String caseId) async {
    final occData = await SupabaseService.client
        .from('occurrences')
        .select()
        .eq('case_id', caseId)
        .order('occurrence_no');

    final occurrences =
        (occData as List).map((e) => OccurrenceModel.fromJson(e as Map<String, dynamic>)).toList();

    List<DamageItemModel> damageItems = [];
    if (occurrences.isNotEmpty) {
      final occIds = occurrences.map((o) => o.occurrenceId).toList();
      final dmgData = await SupabaseService.client
          .from('damage_items')
          .select()
          .inFilter('occurrence_id', occIds)
          .order('sequence_no');
      damageItems =
          (dmgData as List).map((e) => DamageItemModel.fromJson(e as Map<String, dynamic>)).toList();
    }

    return DamageState(
        occurrences: occurrences, damageItems: damageItems);
  }

  // ── Occurrences ──────────────────────────────────────────────────────────

  Future<OccurrenceModel> createOccurrence({
    required String caseId,
    required String title,
    DateTime? dateTime,
    String? location,
    String? briefDescription,
  }) async {
    final current = state.value!;
    final nextNo = current.occurrences.isEmpty
        ? 1
        : current.occurrences.last.occurrenceNo + 1;

    final data = await SupabaseService.client
        .from('occurrences')
        .insert({
          'case_id':           caseId,
          'occurrence_no':     nextNo,
          'title':             title,
          if (dateTime != null)
            'date_time': dateTime.toIso8601String(),
          if (location != null)          'location':          location,
          if (briefDescription != null)
            'brief_description': briefDescription,
          'allegation_type': 'tbc',
        })
        .select()
        .single();

    final occ = OccurrenceModel.fromJson(data);
    state = AsyncData(DamageState(
      occurrences: [...current.occurrences, occ],
      damageItems: current.damageItems,
    ));
    return occ;
  }

  Future<void> updateOccurrence(OccurrenceModel occ) async {
    await SupabaseService.client
        .from('occurrences')
        .update(occ.toInsertJson())
        .eq('occurrence_id', occ.occurrenceId);
    await refresh();
  }

  // ── Damage items ─────────────────────────────────────────────────────────

  Future<DamageItemModel> addDamageItem(DamageItemModel item) async {
    final current = state.value!;
    final existing = current.itemsForOccurrence(item.occurrenceId);
    final nextSeq = existing.isEmpty ? 1 : existing.last.sequenceNo + 1;

    final insertData = item.toInsertJson();
    insertData['sequence_no'] = nextSeq;

    final data = await SupabaseService.client
        .from('damage_items')
        .insert(insertData)
        .select()
        .single();

    final created = DamageItemModel.fromJson(data);
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: [...current.damageItems, created],
    ));
    return created;
  }

  Future<void> updateDamageItem(DamageItemModel item) async {
    await SupabaseService.client
        .from('damage_items')
        .update(item.toInsertJson())
        .eq('damage_id', item.damageId);

    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems
          .map((d) => d.damageId == item.damageId ? item : d)
          .toList(),
    ));
  }

  Future<void> deleteDamageItem(String damageId) async {
    await SupabaseService.client
        .from('damage_items')
        .delete()
        .eq('damage_id', damageId);

    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems
          .where((d) => d.damageId != damageId)
          .toList(),
    ));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
