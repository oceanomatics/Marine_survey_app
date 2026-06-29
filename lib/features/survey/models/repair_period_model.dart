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

// ── Work not concerning average item ──────────────────────────────────────

@immutable
class NotAverageItem {
  const NotAverageItem({required this.itemId, required this.text});
  final String itemId;
  final String text;

  factory NotAverageItem.fromJson(Map<String, dynamic> j) => NotAverageItem(
        itemId: j['id'] as String,
        text: j['text'] as String,
      );

  Map<String, dynamic> toJson() => {'id': itemId, 'text': text};
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
    this.notes,
    this.assignments = const [],
    this.createdAt,
    this.repairTimes = const {},
    this.notAverageItems = const [],
    this.budgetItems = const [],
    this.budgetDisplayCurrency = 'USD',
    this.budgetBaseCurrency = 'USD',
    this.budgetExchangeRate,
    this.budgetRateDate,
  });

  final String periodId;
  final String caseId;
  final int periodNo;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final PortContext portContext;
  final String? notes;
  final List<RepairAssignmentModel> assignments;
  final DateTime? createdAt;

  // Key format: "occ_N" for occurrence N, "owners" for owner's work.
  final Map<String, RepairTimeEntry> repairTimes;
  final List<NotAverageItem> notAverageItems;

  final List<BudgetItem> budgetItems;
  final String budgetDisplayCurrency;
  final String budgetBaseCurrency;
  final double? budgetExchangeRate;
  final DateTime? budgetRateDate;

  String get displayTitle => title ?? 'Repair Period $periodNo';

  RepairPeriodModel copyWith({
    Map<String, RepairTimeEntry>? repairTimes,
    List<NotAverageItem>? notAverageItems,
    List<BudgetItem>? budgetItems,
    String? budgetDisplayCurrency,
    String? budgetBaseCurrency,
    Object? budgetExchangeRate = _sentinel,
    Object? budgetRateDate = _sentinel,
  }) =>
      RepairPeriodModel(
        periodId: periodId,
        caseId: caseId,
        periodNo: periodNo,
        title: title,
        startDate: startDate,
        endDate: endDate,
        location: location,
        portContext: portContext,
        notes: notes,
        assignments: assignments,
        createdAt: createdAt,
        repairTimes: repairTimes ?? this.repairTimes,
        notAverageItems: notAverageItems ?? this.notAverageItems,
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
      notes: j['notes'] as String?,
      assignments: assignments,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      repairTimes: _parseRepairTimes(j['repair_times']),
      notAverageItems: _parseNotAverageItems(j['not_average_items']),
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
    );
  }

  static Map<String, RepairTimeEntry> _parseRepairTimes(dynamic v) {
    if (v == null) return {};
    final m = v as Map<String, dynamic>;
    return m.map((k, e) =>
        MapEntry(k, RepairTimeEntry.fromJson(e as Map<String, dynamic>)));
  }

  static List<NotAverageItem> _parseNotAverageItems(dynamic v) {
    if (v == null) return [];
    return (v as List)
        .map((e) => NotAverageItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
        if (title != null) 'title': title,
        if (startDate != null) 'start_date': _fmt(startDate!),
        if (endDate != null) 'end_date': _fmt(endDate!),
        if (location != null) 'location': location,
        if (notes != null) 'notes': notes,
        if (repairTimes.isNotEmpty)
          'repair_times': repairTimes.map((k, v) => MapEntry(k, v.toJson())),
        if (notAverageItems.isNotEmpty)
          'not_average_items': notAverageItems.map((e) => e.toJson()).toList(),
        if (budgetItems.isNotEmpty)
          'budget_items': budgetItems.map((e) => e.toJson()).toList(),
        'budget_meta': _budgetMetaJson,
      };

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const Object _sentinel = Object();
