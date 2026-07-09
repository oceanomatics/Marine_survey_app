// lib/features/survey/models/repair_period_model.dart

import 'package:flutter/foundation.dart';
import '../providers/damage_provider.dart';

enum PortContext {
  planned('planned', 'Planned Port Call'),
  diversion('diversion', 'Vessel Had to Divert');

  const PortContext(this.value, this.label);
  final String value;
  final String label;

  static PortContext fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => PortContext.planned);
}

// ── Repair phase (preliminary / temporary / permanent) ─────────────────────
//
// Previously-flagged gap (docs/context_cue_system_review.md §3.1/§4/§6):
// "no existing structured preliminary/temporary/permanent repair-phase
// concept in the data model" — confirmed needed 8 July 2026
// (docs/TODO.md Phase 0.1 row 25 / §3.9). Describes the repair period
// itself (e.g. "these are the temporary repairs done en route"), distinct
// from RepairType which records the outcome of an individual damage item
// within a period. Optional — a period can exist with no phase set yet.
enum RepairPhase {
  preliminary('preliminary', 'Preliminary'),
  temporary('temporary', 'Temporary'),
  permanent('permanent', 'Permanent');

  const RepairPhase(this.value, this.label);
  final String value;
  final String label;

  static RepairPhase? fromValue(String? v) {
    if (v == null) return null;
    try {
      return values.firstWhere((e) => e.value == v);
    } catch (_) {
      return null;
    }
  }
}

// ── Repair time entry (dry-dock + alongside days per row) ──────────────────

@immutable
class RepairTimeEntry {
  const RepairTimeEntry({this.drydockDays, this.alongsideDays});
  final double? drydockDays;
  final double? alongsideDays;

  bool get isEmpty => drydockDays == null && alongsideDays == null;

  factory RepairTimeEntry.fromJson(Map<String, dynamic> j) => RepairTimeEntry(
        drydockDays: (j['drydock'] as num?)?.toDouble(),
        alongsideDays: (j['alongside'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (drydockDays != null) 'drydock': drydockDays,
        if (alongsideDays != null) 'alongside': alongsideDays,
      };
}

// ── Budget estimate ────────────────────────────────────────────────────────

enum BudgetItemStatus {
  estimated('estimated', 'Estimated'),
  quoted('quoted', 'Quoted'),
  incurred('incurred', 'Incurred');

  const BudgetItemStatus(this.value, this.label);
  final String value;
  final String label;

  static BudgetItemStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => BudgetItemStatus.estimated);
}

@immutable
class BudgetItem {
  const BudgetItem({
    required this.itemId,
    required this.description,
    required this.amount,
    required this.currency,
    this.status = BudgetItemStatus.estimated,
  });

  final String itemId;
  final String description;
  final double amount;
  final String currency;
  final BudgetItemStatus status;

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        itemId: j['id'] as String,
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'USD',
        status: BudgetItemStatus.fromValue(j['status'] as String? ?? 'estimated'),
      );

  Map<String, dynamic> toJson() => {
        'id': itemId,
        'description': description,
        'amount': amount,
        'currency': currency,
        'status': status.value,
      };

  BudgetItem copyWith({
    String? description,
    double? amount,
    String? currency,
    BudgetItemStatus? status,
  }) =>
      BudgetItem(
        itemId: itemId,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        status: status ?? this.status,
      );
}

// ── Assignment model ───────────────────────────────────────────────────────

@immutable
class RepairAssignmentModel {
  const RepairAssignmentModel({
    required this.assignmentId,
    required this.periodId,
    required this.damageId,
    required this.outcome,
    this.isConcerningAverage = true,
    this.notes,
  });

  final String assignmentId;
  final String periodId;
  final String damageId;
  final RepairType outcome;
  final bool isConcerningAverage;
  final String? notes;

  factory RepairAssignmentModel.fromJson(Map<String, dynamic> j) =>
      RepairAssignmentModel(
        assignmentId: j['assignment_id'] as String,
        periodId: j['period_id'] as String,
        damageId: j['damage_id'] as String,
        outcome: RepairType.fromValue(j['outcome'] as String),
        isConcerningAverage: j['is_concerning_average'] as bool? ?? true,
        notes: j['notes'] as String?,
      );
}

// ── Period model ───────────────────────────────────────────────────────────

@immutable
class RepairPeriodModel {
  const RepairPeriodModel({
    required this.periodId,
    required this.caseId,
    required this.periodNo,
    this.title,
    this.startDate,
    this.endDate,
    this.location,
    this.portContext = PortContext.planned,
    this.repairPhase,
    this.notes,
    this.assignments = const [],
    this.createdAt,
    this.repairTimes = const {},
    this.budgetItems = const [],
    this.budgetDisplayCurrency = 'USD',
    this.budgetBaseCurrency = 'USD',
    this.budgetExchangeRate,
    this.budgetRateDate,
    this.servicesProvided = const [],
    this.servicesProvidedNotes,
    this.hotWorkStatus,
    this.hotWorkNotes,
  });

  final String periodId;
  final String caseId;
  final int periodNo;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final PortContext portContext;
  /// Preliminary / temporary / permanent — see [RepairPhase]. Nullable;
  /// not every period has this set.
  final RepairPhase? repairPhase;
  final String? notes;
  final List<RepairAssignmentModel> assignments;
  final DateTime? createdAt;

  // Key format: "occ_N" for occurrence N, "owners" for owner's work.
  final Map<String, RepairTimeEntry> repairTimes;

  final List<BudgetItem> budgetItems;
  final String budgetDisplayCurrency;
  final String budgetBaseCurrency;
  final double? budgetExchangeRate;
  final DateTime? budgetRateDate;

  /// Clause F-2: services provided (multi-select checklist keys).
  final List<String> servicesProvided;
  final String? servicesProvidedNotes;
  /// Clause F-5: hot work / gas freeing status — 'certs_valid' /
  /// 'certs_not_sighted' / null (not conducted).
  final String? hotWorkStatus;
  final String? hotWorkNotes;

  String get displayTitle => title ?? 'Repair Period $periodNo';

  /// Drydock days across all occurrence-related repair time entries
  /// (keys prefixed `"occ_"`) — excludes the owner's-account entry.
  double get drydockDaysTotal => repairTimes.entries
      .where((e) => e.key.startsWith('occ_'))
      .fold(0.0, (sum, e) => sum + (e.value.drydockDays ?? 0));

  /// Alongside/afloat days across all occurrence-related repair time
  /// entries — excludes the owner's-account entry.
  double get alongsideDaysTotal => repairTimes.entries
      .where((e) => e.key.startsWith('occ_'))
      .fold(0.0, (sum, e) => sum + (e.value.alongsideDays ?? 0));

  /// Total days (drydock + alongside) attributed to the owner's account
  /// (the `"owners"` repair time entry) — feeds the WNCA row.
  double get ownerDaysTotal {
    final owners = repairTimes['owners'];
    if (owners == null) return 0;
    return (owners.drydockDays ?? 0) + (owners.alongsideDays ?? 0);
  }

  RepairPeriodModel copyWith({
    Object? title = _sentinel,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    Object? location = _sentinel,
    PortContext? portContext,
    Object? repairPhase = _sentinel,
    Object? notes = _sentinel,
    List<RepairAssignmentModel>? assignments,
    Map<String, RepairTimeEntry>? repairTimes,
    List<BudgetItem>? budgetItems,
    String? budgetDisplayCurrency,
    String? budgetBaseCurrency,
    Object? budgetExchangeRate = _sentinel,
    Object? budgetRateDate = _sentinel,
    List<String>? servicesProvided,
    Object? servicesProvidedNotes = _sentinel,
    Object? hotWorkStatus = _sentinel,
    Object? hotWorkNotes = _sentinel,
  }) =>
      RepairPeriodModel(
        periodId: periodId,
        caseId: caseId,
        periodNo: periodNo,
        title: title == _sentinel ? this.title : title as String?,
        startDate:
            startDate == _sentinel ? this.startDate : startDate as DateTime?,
        endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
        location: location == _sentinel ? this.location : location as String?,
        portContext: portContext ?? this.portContext,
        repairPhase: repairPhase == _sentinel
            ? this.repairPhase
            : repairPhase as RepairPhase?,
        notes: notes == _sentinel ? this.notes : notes as String?,
        assignments: assignments ?? this.assignments,
        createdAt: createdAt,
        repairTimes: repairTimes ?? this.repairTimes,
        budgetItems: budgetItems ?? this.budgetItems,
        budgetDisplayCurrency:
            budgetDisplayCurrency ?? this.budgetDisplayCurrency,
        budgetBaseCurrency: budgetBaseCurrency ?? this.budgetBaseCurrency,
        budgetExchangeRate: budgetExchangeRate == _sentinel
            ? this.budgetExchangeRate
            : budgetExchangeRate as double?,
        budgetRateDate: budgetRateDate == _sentinel
            ? this.budgetRateDate
            : budgetRateDate as DateTime?,
        servicesProvided: servicesProvided ?? this.servicesProvided,
        servicesProvidedNotes: servicesProvidedNotes == _sentinel
            ? this.servicesProvidedNotes
            : servicesProvidedNotes as String?,
        hotWorkStatus: hotWorkStatus == _sentinel
            ? this.hotWorkStatus
            : hotWorkStatus as String?,
        hotWorkNotes: hotWorkNotes == _sentinel
            ? this.hotWorkNotes
            : hotWorkNotes as String?,
      );

  factory RepairPeriodModel.fromJson(
    Map<String, dynamic> j, {
    List<RepairAssignmentModel> assignments = const [],
  }) {
    final budgetMeta =
        j['budget_meta'] as Map<String, dynamic>? ?? const {};
    return RepairPeriodModel(
      periodId: j['period_id'] as String,
      caseId: j['case_id'] as String,
      periodNo: j['period_no'] as int? ?? 1,
      title: j['title'] as String?,
      startDate: j['start_date'] != null
          ? DateTime.tryParse(j['start_date'] as String)
          : null,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      location: j['location'] as String?,
      portContext:
          PortContext.fromValue(j['port_context'] as String? ?? 'planned'),
      repairPhase: RepairPhase.fromValue(j['repair_phase'] as String?),
      notes: j['notes'] as String?,
      assignments: assignments,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      repairTimes: _parseRepairTimes(j['repair_times']),
      budgetItems: _parseBudgetItems(j['budget_items']),
      budgetDisplayCurrency:
          budgetMeta['display_currency'] as String? ?? 'USD',
      budgetBaseCurrency:
          budgetMeta['base_currency'] as String? ?? 'USD',
      budgetExchangeRate:
          (budgetMeta['exchange_rate'] as num?)?.toDouble(),
      budgetRateDate: budgetMeta['rate_date'] != null
          ? DateTime.tryParse(budgetMeta['rate_date'] as String)
          : null,
      servicesProvided:
          (j['services_provided'] as List?)?.cast<String>() ?? const [],
      servicesProvidedNotes: j['services_provided_notes'] as String?,
      hotWorkStatus: j['hot_work_status'] as String?,
      hotWorkNotes: j['hot_work_notes'] as String?,
    );
  }

  static Map<String, RepairTimeEntry> _parseRepairTimes(dynamic v) {
    if (v == null) return {};
    final m = v as Map<String, dynamic>;
    return m.map((k, e) =>
        MapEntry(k, RepairTimeEntry.fromJson(e as Map<String, dynamic>)));
  }

  static List<BudgetItem> _parseBudgetItems(dynamic v) {
    if (v == null) return [];
    return (v as List)
        .map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> get _budgetMetaJson => {
        'display_currency': budgetDisplayCurrency,
        'base_currency': budgetBaseCurrency,
        if (budgetExchangeRate != null) 'exchange_rate': budgetExchangeRate,
        if (budgetRateDate != null)
          'rate_date': budgetRateDate!.toIso8601String().substring(0, 10),
      };

  Map<String, dynamic> toInsertJson() => {
        'case_id': caseId,
        'period_no': periodNo,
        'port_context': portContext.value,
        if (repairPhase != null) 'repair_phase': repairPhase!.value,
        if (title != null) 'title': title,
        if (startDate != null) 'start_date': _fmt(startDate!),
        if (endDate != null) 'end_date': _fmt(endDate!),
        if (location != null) 'location': location,
        if (notes != null) 'notes': notes,
        if (repairTimes.isNotEmpty)
          'repair_times': repairTimes.map((k, v) => MapEntry(k, v.toJson())),
        if (budgetItems.isNotEmpty)
          'budget_items': budgetItems.map((e) => e.toJson()).toList(),
        'budget_meta': _budgetMetaJson,
        if (servicesProvided.isNotEmpty) 'services_provided': servicesProvided,
        if (servicesProvidedNotes != null)
          'services_provided_notes': servicesProvidedNotes,
        if (hotWorkStatus != null) 'hot_work_status': hotWorkStatus,
        if (hotWorkNotes != null) 'hot_work_notes': hotWorkNotes,
      };

  /// Like [toInsertJson] but always includes the editable header fields
  /// (title/dates/location/port context/repair phase/notes/services/hot
  /// work) even when null, so an update can actually *clear* a field the
  /// surveyor emptied out — `toInsertJson()` omits null keys entirely,
  /// which is correct for a fresh insert (let DB defaults apply) but wrong
  /// for an edit, where "field left blank" should persist as cleared. Used
  /// by `RepairPeriodsNotifier.updatePeriod` (docs/TODO.md §3.9 —
  /// "fields become read-only after the period is created").
  Map<String, dynamic> toUpdateJson() => {
        'period_no': periodNo,
        'port_context': portContext.value,
        'repair_phase': repairPhase?.value,
        'title': title,
        'start_date': startDate != null ? _fmt(startDate!) : null,
        'end_date': endDate != null ? _fmt(endDate!) : null,
        'location': location,
        'notes': notes,
        'services_provided': servicesProvided,
        'services_provided_notes': servicesProvidedNotes,
        'hot_work_status': hotWorkStatus,
        'hot_work_notes': hotWorkNotes,
      };

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const Object _sentinel = Object();

// ── Status of Repairs — derived from repair periods ────────────────────────
//
// Relocated from the report builder's Advice Summary card (was a manual
// dropdown, `report_outputs.advice_status_of_repairs`) per surveyor
// direction (4 July 2026): "status of repairs can be deducted from the
// repair periods." Matches the spec's option set (docs/report_builder_
// editor_notes.md, Executive Summary "Status of Repairs" field) as closely
// as pure date derivation allows — "Awaiting [text]" and "Deferred to
// [date]" aren't derivable from dates alone, so they're intentionally not
// produced here; a period with no end date reads as Ongoing instead, which
// is the closest honest derived state.
enum DerivedRepairStatus {
  notCommenced('Not yet commenced'),
  ongoing('Ongoing'),
  complete('Complete');

  const DerivedRepairStatus(this.label);
  final String label;
}

DerivedRepairStatus deriveRepairStatus(List<RepairPeriodModel> periods) {
  if (periods.isEmpty) return DerivedRepairStatus.notCommenced;
  final hasStarted = periods.any((p) => p.startDate != null);
  if (!hasStarted) return DerivedRepairStatus.notCommenced;
  // Ongoing if any period has started but has no end date yet.
  final anyOpen = periods.any((p) => p.startDate != null && p.endDate == null);
  if (anyOpen) return DerivedRepairStatus.ongoing;
  return DerivedRepairStatus.complete;
}
