// lib/features/survey/providers/damage_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../../cases/providers/cases_provider.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum DamageCategory {
  structuralExternal('structural_external', 'Structural — External'),
  structuralInternal('structural_internal', 'Structural — Internal'),
  mechanical('mechanical', 'Mechanical'),
  electricalElectronics('electrical_electronics', 'Electrical / Electronics'),
  other('other', 'Other');

  const DamageCategory(this.value, this.label);
  final String value;
  final String label;

  static DamageCategory fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => DamageCategory.other);
}

enum RepairType {
  temporary('temporary', 'Temporary'),
  permanent('permanent', 'Permanent'),
  deferred('deferred', 'Deferred');

  const RepairType(this.value, this.label);
  final String value;
  final String label;

  static RepairType fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => RepairType.temporary);
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

// ── H&M cause types ────────────────────────────────────────────────────────

enum HMCauseType {
  grounding('grounding', 'Grounding / Stranding'),
  collision('collision', 'Collision'),
  contact('contact', 'Contact'),
  fire('fire', 'Fire'),
  explosion('explosion', 'Explosion'),
  flooding('flooding', 'Flooding'),
  heavyWeather('heavy_weather', 'Heavy Weather'),
  machineryFailure('machinery_failure', 'Machinery Failure'),
  structuralFailure('structural_failure', 'Structural Failure'),
  crewError('crew_error', 'Crew / Nav. Error'),
  portDamage('port_damage', 'Port / Berth Damage'),
  iceDamage('ice_damage', 'Ice Damage'),
  lightning('lightning', 'Lightning Strike'),
  malicious('malicious', 'Malicious Damage'),
  other('other', 'Other');

  const HMCauseType(this.value, this.label);
  final String value;
  final String label;

  static HMCauseType? fromValue(String? v) {
    if (v == null) return null;
    try {
      return values.firstWhere((e) => e.value == v);
    } catch (_) {
      return null;
    }
  }
}

// ── Occurrence model ───────────────────────────────────────────────────────

@immutable
class OccurrenceModel {
  const OccurrenceModel({
    required this.occurrenceId,
    required this.caseId,
    required this.occurrenceNo,
    this.isPrimary = false,
    this.dateTime,
    this.location,
    this.title,
    this.briefDescription,
    this.backgroundNarrative,
    this.chronology,
    this.causeType,
    this.allegationType,
    this.causeAgreement,
    this.causeNarrative,
    this.ismReported,
    this.createdAt,
  });

  final String occurrenceId;
  final String caseId;
  final int occurrenceNo;
  final bool isPrimary;
  final DateTime? dateTime;
  final String? location;
  final String? title;
  final String? briefDescription;
  final String? backgroundNarrative;
  final String? chronology;
  final String? causeType;
  final String? allegationType;
  final String? causeAgreement;
  final String? causeNarrative;
  final bool? ismReported;
  final DateTime? createdAt;

  factory OccurrenceModel.fromJson(Map<String, dynamic> j) => OccurrenceModel(
        occurrenceId:        j['occurrence_id'] as String,
        caseId:              j['case_id'] as String,
        occurrenceNo:        j['occurrence_no'] as int? ?? 1,
        isPrimary:           j['is_primary'] as bool? ?? false,
        dateTime:            j['date_time'] != null
            ? DateTime.tryParse(j['date_time'] as String)
            : null,
        location:            j['location'] as String?,
        title:               j['title'] as String?,
        briefDescription:    j['brief_description'] as String?,
        backgroundNarrative: j['background_narrative'] as String?,
        chronology:          j['chronology'] as String?,
        causeType:           j['cause_type'] as String?,
        allegationType:      j['allegation_type'] as String?,
        causeAgreement:      j['cause_agreement'] as String?,
        causeNarrative:      j['cause_narrative'] as String?,
        ismReported:         j['ism_reported'] as bool?,
        createdAt:           j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':       caseId,
        'occurrence_no': occurrenceNo,
        'is_primary':    isPrimary,
        if (dateTime != null) 'date_time': dateTime!.toIso8601String(),
        if (location != null)          'location':           location,
        if (title != null)             'title':              title,
        if (briefDescription != null)  'brief_description':  briefDescription,
        if (backgroundNarrative != null)
          'background_narrative': backgroundNarrative,
        if (chronology != null)        'chronology':         chronology,
        if (causeType != null)         'cause_type':         causeType,
        if (allegationType != null)    'allegation_type':    allegationType,
        if (causeAgreement != null)    'cause_agreement':    causeAgreement,
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
    this.damageCategory = DamageCategory.other,
    this.machineryId,
    this.componentId,
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
  final DamageCategory damageCategory;
  final String? machineryId;
  final String? componentId;
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
        damageCategory:    DamageCategory.fromValue(
            j['damage_category'] as String? ?? 'other'),
        machineryId:       j['machinery_id'] as String?,
        componentId:       j['component_id'] as String?,
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
        'damage_category': damageCategory.value,
        if (machineryId != null)       'machinery_id':        machineryId,
        if (componentId != null)       'component_id':        componentId,
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
    DamageCategory? damageCategory,
    String? machineryId,
    String? componentId,
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
        damageCategory:    damageCategory    ?? this.damageCategory,
        machineryId:       machineryId       ?? this.machineryId,
        componentId:       componentId       ?? this.componentId,
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

// ── Repair model ───────────────────────────────────────────────────────────

@immutable
class RepairModel {
  const RepairModel({
    required this.repairId,
    required this.occurrenceId,
    required this.caseId,
    required this.repairType,
    required this.repairStatus,
    this.description,
    this.estimatedCost,
    this.actualCost,
    this.completionDate,
    this.notes,
    this.linkedDamageIds = const [],
    this.sequenceNo = 1,
    this.createdAt,
  });

  final String repairId;
  final String occurrenceId;
  final String caseId;
  final RepairType repairType;
  final RepairStatus repairStatus;
  final String? description;
  final double? estimatedCost;
  final double? actualCost;
  final DateTime? completionDate;
  final String? notes;
  final List<String> linkedDamageIds;
  final int sequenceNo;
  final DateTime? createdAt;

  factory RepairModel.fromJson(
    Map<String, dynamic> j, {
    List<String> linkedDamageIds = const [],
  }) =>
      RepairModel(
        repairId:       j['repair_id'] as String,
        occurrenceId:   j['occurrence_id'] as String,
        caseId:         j['case_id'] as String,
        repairType:     RepairType.fromValue(
            j['repair_type'] as String? ?? 'temporary'),
        repairStatus:   RepairStatus.fromValue(
            j['repair_status'] as String? ?? 'not_started'),
        description:    j['description'] as String?,
        estimatedCost:  (j['estimated_cost'] as num?)?.toDouble(),
        actualCost:     (j['actual_cost'] as num?)?.toDouble(),
        completionDate: j['completion_date'] != null
            ? DateTime.tryParse(j['completion_date'] as String)
            : null,
        notes:          j['notes'] as String?,
        linkedDamageIds: linkedDamageIds,
        sequenceNo:     j['sequence_no'] as int? ?? 1,
        createdAt:      j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'occurrence_id': occurrenceId,
        'case_id':       caseId,
        'repair_type':   repairType.value,
        'repair_status': repairStatus.value,
        if (description != null)    'description':     description,
        if (estimatedCost != null)  'estimated_cost':  estimatedCost,
        if (actualCost != null)     'actual_cost':     actualCost,
        if (completionDate != null)
          'completion_date': completionDate!.toIso8601String().split('T').first,
        if (notes != null) 'notes': notes,
      };
}

// ── Combined state ─────────────────────────────────────────────────────────

@immutable
class DamageState {
  const DamageState({
    required this.occurrences,
    required this.damageItems,
    this.repairs = const [],
  });

  final List<OccurrenceModel> occurrences;
  final List<DamageItemModel> damageItems;
  final List<RepairModel> repairs;

  List<DamageItemModel> itemsForOccurrence(String occurrenceId) =>
      damageItems
          .where((d) => d.occurrenceId == occurrenceId)
          .toList()
        ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));

  List<DamageItemModel> itemsForOccurrenceAndCategory(
          String occurrenceId, DamageCategory cat) =>
      damageItems
          .where((d) =>
              d.occurrenceId == occurrenceId && d.damageCategory == cat)
          .toList()
        ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));

  List<RepairModel> repairsForOccurrence(String occurrenceId) =>
      repairs
          .where((r) => r.occurrenceId == occurrenceId)
          .toList()
        ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));

  int get totalDamageItems => damageItems.length;
  int get averageItems =>
      damageItems.where((d) => d.isConcerningAverage).length;
  int get ownerItems =>
      damageItems.where((d) => !d.isConcerningAverage).length;

  OccurrenceModel? get primaryOccurrence =>
      occurrences.where((o) => o.isPrimary).firstOrNull;
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

    final occurrences = (occData as List)
        .map((e) => OccurrenceModel.fromJson(e as Map<String, dynamic>))
        .toList();

    List<DamageItemModel> damageItems = [];
    List<RepairModel> repairs = [];

    if (occurrences.isNotEmpty) {
      final occIds = occurrences.map((o) => o.occurrenceId).toList();

      final dmgData = await SupabaseService.client
          .from('damage_items')
          .select()
          .inFilter('occurrence_id', occIds)
          .order('sequence_no');
      damageItems = (dmgData as List)
          .map((e) => DamageItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Load repairs — wrapped so app doesn't crash before migrations run
      try {
        final repairRaw = await SupabaseService.client
            .from('repairs')
            .select()
            .eq('case_id', caseId)
            .order('created_at');
        final repairList = repairRaw as List;

        if (repairList.isNotEmpty) {
          final repairIds = repairList
              .map((r) => (r as Map<String, dynamic>)['repair_id'] as String)
              .toList();

          final linkRaw = await SupabaseService.client
              .from('repair_damage_links')
              .select()
              .inFilter('repair_id', repairIds);

          final linkMap = <String, List<String>>{};
          for (final link in linkRaw as List) {
            final m = link as Map<String, dynamic>;
            linkMap
                .putIfAbsent(m['repair_id'] as String, () => [])
                .add(m['damage_id'] as String);
          }

          repairs = repairList.map((e) {
            final row = e as Map<String, dynamic>;
            final rid = row['repair_id'] as String;
            return RepairModel.fromJson(row,
                linkedDamageIds: linkMap[rid] ?? []);
          }).toList();
        }
      } catch (e) {
        debugPrint('[DamageNotifier] repairs fetch skipped: $e');
      }
    }

    return DamageState(
      occurrences: occurrences,
      damageItems: damageItems,
      repairs: repairs,
    );
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
          'case_id':        caseId,
          'occurrence_no':  nextNo,
          'title':          title,
          if (dateTime != null) 'date_time': dateTime.toIso8601String(),
          if (location != null)          'location':         location,
          if (briefDescription != null)
            'brief_description': briefDescription,
          'allegation_type': 'tbc',
        })
        .select()
        .single();

    final occ = OccurrenceModel.fromJson(data);

    // Sync case title when the first occurrence is created with a title.
    if (current.occurrences.isEmpty && title.isNotEmpty) {
      await _syncCaseTitleFromOccurrence(occ);
    }

    state = AsyncData(DamageState(
      occurrences: [...current.occurrences, occ],
      damageItems: current.damageItems,
      repairs: current.repairs,
    ));
    return occ;
  }

  Future<void> updateOccurrence(OccurrenceModel occ) async {
    debugPrint('[DamageNotifier.updateOccurrence] START id=${occ.occurrenceId}');
    // Explicit null values for causation fields so Supabase clears them on the
    // row rather than leaving old values in place (toInsertJson omits nulls).
    final payload = occ.toInsertJson()
      ..['cause_type']      = occ.causeType
      ..['cause_agreement'] = occ.causeAgreement
      ..['cause_narrative'] = occ.causeNarrative
      ..['allegation_type'] = occ.allegationType;

    debugPrint('[DamageNotifier.updateOccurrence] payload keys: ${payload.keys.toList()}');
    debugPrint('[DamageNotifier.updateOccurrence] state type: ${state.runtimeType}, hasValue: ${state.hasValue}');

    await SupabaseService.client
        .from('occurrences')
        .update(payload)
        .eq('occurrence_id', occ.occurrenceId);

    debugPrint('[DamageNotifier.updateOccurrence] Supabase update done');

    // Update local state directly — avoids the AsyncLoading flash that
    // refresh() would trigger, so the causation card updates immediately.
    final current = state.value;
    if (current == null) {
      debugPrint('[DamageNotifier.updateOccurrence] ERROR: state.value is null (state=${state.runtimeType})');
      throw StateError('Provider state unavailable during update (state=${state.runtimeType})');
    }
    state = AsyncData(DamageState(
      occurrences: current.occurrences
          .map((o) => o.occurrenceId == occ.occurrenceId ? occ : o)
          .toList(),
      damageItems: current.damageItems,
      repairs: current.repairs,
    ));
    debugPrint('[DamageNotifier.updateOccurrence] local state updated');

    // Sync case title when the primary (or only) occurrence is updated.
    final isOnlyOccurrence = current.occurrences.length == 1;
    if ((occ.isPrimary || isOnlyOccurrence) &&
        occ.title != null &&
        occ.title!.isNotEmpty) {
      await _syncCaseTitleFromOccurrence(occ);
    }
    debugPrint('[DamageNotifier.updateOccurrence] DONE');
  }

  Future<void> _syncCaseTitleFromOccurrence(OccurrenceModel occ) async {
    try {
      final caseRow = await SupabaseService.client
          .from('cases')
          .select('job_number, case_type, vessels(name)')
          .eq('case_id', arg)
          .single();
      final jobNo   = caseRow['job_number'] as String? ?? '';
      final vName   = (caseRow['vessels'] as Map?)?['name'] as String? ?? '';
      final ctLabel = _caseTypeLabel(caseRow['case_type'] as String? ?? '');
      final occTitle = occ.title ?? '';
      final parts = [
        if (jobNo.isNotEmpty)    jobNo,
        if (vName.isNotEmpty)    vName,
        if (ctLabel.isNotEmpty)  ctLabel,
        if (occTitle.isNotEmpty) occTitle,
      ];
      if (parts.isNotEmpty) {
        await SupabaseService.client
            .from('cases')
            .update({'title': parts.join(' – ')})
            .eq('case_id', arg);
        ref.invalidate(casesProvider);
      }
    } catch (e) {
      debugPrint('[DamageNotifier] _syncCaseTitleFromOccurrence: $e');
    }
  }

  Future<void> setPrimaryOccurrence(String occurrenceId) async {
    final current = state.value!;

    // 1. Clear all primaries for this case, then set the chosen one.
    await SupabaseService.client
        .from('occurrences')
        .update({'is_primary': false})
        .eq('case_id', arg);
    await SupabaseService.client
        .from('occurrences')
        .update({'is_primary': true})
        .eq('occurrence_id', occurrenceId);

    // 2. Keep the case title in sync (jobNo – vessel – caseType – occTitle).
    try {
      final primary =
          current.occurrences.firstWhere((o) => o.occurrenceId == occurrenceId);
      final caseRow = await SupabaseService.client
          .from('cases')
          .select('job_number, case_type, vessels(name)')
          .eq('case_id', arg)
          .single();
      final jobNo   = caseRow['job_number'] as String? ?? '';
      final vName   = (caseRow['vessels'] as Map?)?['name'] as String? ?? '';
      final ctLabel = _caseTypeLabel(caseRow['case_type'] as String? ?? '');
      final occTitle = primary.title ?? '';
      final parts = [
        if (jobNo.isNotEmpty)    jobNo,
        if (vName.isNotEmpty)    vName,
        if (ctLabel.isNotEmpty)  ctLabel,
        if (occTitle.isNotEmpty) occTitle,
      ];
      if (parts.isNotEmpty) {
        await SupabaseService.client
            .from('cases')
            .update({'title': parts.join(' – ')})
            .eq('case_id', arg);
      }
    } catch (e) {
      debugPrint('[DamageNotifier] setPrimaryOccurrence title sync: $e');
    }

    // 3. Update local state immediately so UI reflects change without refetch.
    state = AsyncData(DamageState(
      occurrences: current.occurrences
          .map((o) => OccurrenceModel(
                occurrenceId:        o.occurrenceId,
                caseId:              o.caseId,
                occurrenceNo:        o.occurrenceNo,
                isPrimary:           o.occurrenceId == occurrenceId,
                dateTime:            o.dateTime,
                location:            o.location,
                title:               o.title,
                briefDescription:    o.briefDescription,
                backgroundNarrative: o.backgroundNarrative,
                chronology:          o.chronology,
                causeType:           o.causeType,
                allegationType:      o.allegationType,
                causeAgreement:      o.causeAgreement,
                causeNarrative:      o.causeNarrative,
                ismReported:         o.ismReported,
                createdAt:           o.createdAt,
              ))
          .toList(),
      damageItems: current.damageItems,
      repairs:     current.repairs,
    ));
  }

  static String _caseTypeLabel(String v) => const {
        'hm': 'H&M', 'pi': 'P&I', 'cs': 'C&S',
        'dp_trials': 'DP Trials', 'deficiency': 'Deficiency',
        'consulting': 'Consulting',
      }[v] ?? v.toUpperCase();

  Future<void> deleteOccurrence(String occurrenceId) async {
    final current = state.value!;

    // Cascade in dependency order so FK constraints are not violated.
    final dmgIds = current.damageItems
        .where((d) => d.occurrenceId == occurrenceId)
        .map((d) => d.damageId)
        .toList();

    if (dmgIds.isNotEmpty) {
      try {
        await SupabaseService.client
            .from('repair_damage_links')
            .delete()
            .inFilter('damage_id', dmgIds);
      } catch (e) {
        debugPrint('[DamageNotifier] repair_damage_links cleanup: $e');
      }
    }

    try {
      await SupabaseService.client
          .from('repairs')
          .delete()
          .eq('occurrence_id', occurrenceId);
    } catch (e) {
      debugPrint('[DamageNotifier] repairs cleanup: $e');
    }

    await SupabaseService.client
        .from('damage_items')
        .delete()
        .eq('occurrence_id', occurrenceId);

    await SupabaseService.client
        .from('occurrences')
        .delete()
        .eq('occurrence_id', occurrenceId);

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
      repairs: current.repairs,
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
      repairs: current.repairs,
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
      damageItems:
          current.damageItems.where((d) => d.damageId != damageId).toList(),
      repairs: current.repairs,
    ));
  }

  // ── Repairs ──────────────────────────────────────────────────────────────

  Future<RepairModel> addRepair(RepairModel repair) async {
    final current = state.value!;

    final insertData = repair.toInsertJson();

    final data = await SupabaseService.client
        .from('repairs')
        .insert(insertData)
        .select()
        .single();

    final repairId = data['repair_id'] as String;

    if (repair.linkedDamageIds.isNotEmpty) {
      await SupabaseService.client.from('repair_damage_links').insert(
        repair.linkedDamageIds
            .map((id) => {'repair_id': repairId, 'damage_id': id})
            .toList(),
      );
    }

    final created = RepairModel.fromJson(data,
        linkedDamageIds: repair.linkedDamageIds);
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs: [...current.repairs, created],
    ));
    return created;
  }

  Future<void> updateRepair(RepairModel repair) async {
    await SupabaseService.client
        .from('repairs')
        .update(repair.toInsertJson())
        .eq('repair_id', repair.repairId);

    await SupabaseService.client
        .from('repair_damage_links')
        .delete()
        .eq('repair_id', repair.repairId);

    if (repair.linkedDamageIds.isNotEmpty) {
      await SupabaseService.client.from('repair_damage_links').insert(
        repair.linkedDamageIds
            .map((id) =>
                {'repair_id': repair.repairId, 'damage_id': id})
            .toList(),
      );
    }

    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs: current.repairs
          .map((r) => r.repairId == repair.repairId ? repair : r)
          .toList(),
    ));
  }

  Future<void> deleteRepair(String repairId) async {
    await SupabaseService.client
        .from('repairs')
        .delete()
        .eq('repair_id', repairId);

    final current = state.value!;
    state = AsyncData(DamageState(
      occurrences: current.occurrences,
      damageItems: current.damageItems,
      repairs:
          current.repairs.where((r) => r.repairId != repairId).toList(),
    ));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
