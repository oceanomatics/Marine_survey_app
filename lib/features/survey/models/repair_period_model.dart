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
    this.quantity,
    this.unit,
    this.unitRate,
  });

  final String itemId;
  final String description;
  final double amount;
  final String currency;
  final BudgetItemStatus status;

  /// Optional quantity/unit/unit-rate breakdown — populated when a line is
  /// built from a cost preset (e.g. 5 × "day" @ 12,000) or when the surveyor
  /// enters a rate-based line. When both [quantity] and [unitRate] are set,
  /// [amount] is expected to equal their product ([computedAmount]), but
  /// [amount] always remains the authoritative stored value so a hand-typed
  /// lump sum still works with these left null.
  final double? quantity;
  final String? unit;
  final double? unitRate;

  /// True when this line carries a qty × rate breakdown to display.
  bool get hasBreakdown => quantity != null && unitRate != null;

  /// quantity × unitRate when both are present, else null.
  double? get computedAmount =>
      hasBreakdown ? quantity! * unitRate! : null;

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        itemId: j['id'] as String,
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'USD',
        status: BudgetItemStatus.fromValue(j['status'] as String? ?? 'estimated'),
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: j['unit'] as String?,
        unitRate: (j['unit_rate'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': itemId,
        'description': description,
        'amount': amount,
        'currency': currency,
        'status': status.value,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (unitRate != null) 'unit_rate': unitRate,
      };

  BudgetItem copyWith({
    String? description,
    double? amount,
    String? currency,
    BudgetItemStatus? status,
    Object? quantity = _sentinel,
    Object? unit = _sentinel,
    Object? unitRate = _sentinel,
  }) =>
      BudgetItem(
        itemId: itemId,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        status: status ?? this.status,
        quantity:
            quantity == _sentinel ? this.quantity : quantity as double?,
        unit: unit == _sentinel ? this.unit : unit as String?,
        unitRate:
            unitRate == _sentinel ? this.unitRate : unitRate as double?,
      );
}

// ── Repair cost presets ─────────────────────────────────────────────────────
//
// Starter catalogue for the budget estimate (16 July 2026 sweep — surveyor
// asked "could we suggest a list of cost for the cost estimate"). Each preset
// is only a *starting point*: picking one pre-fills the description, unit and
// a typical unit rate, but every field stays fully editable and the quantity
// is the surveyor's to set. Rates are deliberately round, order-of-magnitude
// figures in USD; they are not a price list and are expected to be overwritten
// per yard/quote.

enum CostPresetGroup {
  docking('Docking & Access'),
  structural('Structural / Steel'),
  machinery('Machinery'),
  coatings('Coatings'),
  attendance('Class & Attendance'),
  services('Yard Services');

  const CostPresetGroup(this.label);
  final String label;
}

@immutable
class RepairCostPreset {
  const RepairCostPreset({
    required this.group,
    required this.description,
    required this.unit,
    this.typicalRate,
    this.defaultQuantity = 1,
  });

  final CostPresetGroup group;
  final String description;

  /// Unit the rate is quoted in — e.g. 'day', 'kg', 'm²', 'lump sum'.
  final String unit;

  /// Indicative USD unit rate, or null for lines that are inherently a quote
  /// (surveyor fills the amount in).
  final double? typicalRate;
  final double defaultQuantity;

  /// Build an editable budget line from this preset in the given currency.
  BudgetItem toBudgetItem({required String currency, String itemId = ''}) {
    final rate = typicalRate;
    return BudgetItem(
      itemId: itemId,
      description: description,
      amount: rate != null ? rate * defaultQuantity : 0,
      currency: currency,
      quantity: defaultQuantity,
      unit: unit,
      unitRate: rate,
    );
  }
}

const List<RepairCostPreset> kRepairCostPresets = [
  // Docking & access
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Dry-dock hire',
      unit: 'day',
      typicalRate: 12000),
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Docking & undocking',
      unit: 'lump sum',
      typicalRate: 15000),
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Afloat / alongside berth hire',
      unit: 'day',
      typicalRate: 3500),
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Staging / scaffolding',
      unit: 'm²',
      typicalRate: 45),
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Crane hire',
      unit: 'day',
      typicalRate: 2500),
  RepairCostPreset(
      group: CostPresetGroup.docking,
      description: 'Tank cleaning / gas freeing',
      unit: 'lump sum'),
  // Structural / steel
  RepairCostPreset(
      group: CostPresetGroup.structural,
      description: 'Steel renewal (plate)',
      unit: 'kg',
      typicalRate: 6),
  RepairCostPreset(
      group: CostPresetGroup.structural,
      description: 'Steel renewal (sections)',
      unit: 'm²',
      typicalRate: 850),
  RepairCostPreset(
      group: CostPresetGroup.structural,
      description: 'Cropping & renewal — labour',
      unit: 'hour',
      typicalRate: 65),
  RepairCostPreset(
      group: CostPresetGroup.structural,
      description: 'Welding / fabrication',
      unit: 'hour',
      typicalRate: 70),
  RepairCostPreset(
      group: CostPresetGroup.structural,
      description: 'NDT / weld testing',
      unit: 'lump sum'),
  // Machinery
  RepairCostPreset(
      group: CostPresetGroup.machinery,
      description: 'Main-engine overhaul',
      unit: 'lump sum'),
  RepairCostPreset(
      group: CostPresetGroup.machinery,
      description: 'Auxiliary-engine overhaul',
      unit: 'lump sum'),
  RepairCostPreset(
      group: CostPresetGroup.machinery,
      description: 'Pump / motor renewal',
      unit: 'each'),
  RepairCostPreset(
      group: CostPresetGroup.machinery,
      description: 'Propeller / shaft repair',
      unit: 'lump sum'),
  RepairCostPreset(
      group: CostPresetGroup.machinery,
      description: 'Machinery labour',
      unit: 'hour',
      typicalRate: 75),
  // Coatings
  RepairCostPreset(
      group: CostPresetGroup.coatings,
      description: 'Blasting & painting',
      unit: 'm²',
      typicalRate: 35),
  RepairCostPreset(
      group: CostPresetGroup.coatings,
      description: 'High-pressure wash',
      unit: 'm²',
      typicalRate: 6),
  RepairCostPreset(
      group: CostPresetGroup.coatings,
      description: 'Paint & consumables',
      unit: 'lump sum'),
  // Class & attendance
  RepairCostPreset(
      group: CostPresetGroup.attendance,
      description: 'Classification-society attendance',
      unit: 'day',
      typicalRate: 1800),
  RepairCostPreset(
      group: CostPresetGroup.attendance,
      description: 'Superintendence',
      unit: 'day',
      typicalRate: 1200),
  RepairCostPreset(
      group: CostPresetGroup.attendance,
      description: 'Surveyor / consultant attendance',
      unit: 'day',
      typicalRate: 1500),
  // Yard services
  RepairCostPreset(
      group: CostPresetGroup.services,
      description: 'Electricity / shore power',
      unit: 'day',
      typicalRate: 800),
  RepairCostPreset(
      group: CostPresetGroup.services,
      description: 'Waste / sludge disposal',
      unit: 'lump sum'),
  RepairCostPreset(
      group: CostPresetGroup.services,
      description: 'General yard services',
      unit: 'lump sum'),
];

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

// ── Post-repair sea trial ───────────────────────────────────────────────────
//
// Added 16 July 2026 (surveyor sweep: "we have not managed a post repair
// seatrial entry"). One optional sea-trial record per repair period, capturing
// the confirmation that repairs performed as intended: date, duration,
// location, the parameters observed during the trial (e.g. engine load, RPM,
// speed achieved), an overall satisfactory yes/no, and free-text notes.
// Stored as a JSONB `sea_trial` column on repair_periods (migration 062).

@immutable
class SeaTrialParameter {
  const SeaTrialParameter({required this.label, required this.value});

  /// What was observed — e.g. 'Engine load', 'RPM', 'Speed'.
  final String label;

  /// The observed value, incl. units as the surveyor typed them —
  /// e.g. '85 %', '750 rpm', '14.2 kn'.
  final String value;

  factory SeaTrialParameter.fromJson(Map<String, dynamic> j) =>
      SeaTrialParameter(
        label: j['label'] as String? ?? '',
        value: j['value'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

/// Common parameter labels offered as quick-add chips in the sea-trial editor.
const List<String> kSeaTrialParameterPresets = [
  'Engine load',
  'RPM',
  'Speed',
  'Shaft power',
  'Exhaust temp',
  'Vibration',
  'Steering response',
  'Manoeuvring',
];

@immutable
class SeaTrial {
  const SeaTrial({
    this.date,
    this.durationHours,
    this.location,
    this.parameters = const [],
    this.satisfactory,
    this.notes,
  });

  final DateTime? date;
  final double? durationHours;
  final String? location;
  final List<SeaTrialParameter> parameters;

  /// Overall outcome — true = satisfactory, false = not satisfactory,
  /// null = not yet assessed.
  final bool? satisfactory;
  final String? notes;

  /// True when the record carries no meaningful content (so we can avoid
  /// persisting an empty object).
  bool get isEmpty =>
      date == null &&
      durationHours == null &&
      (location == null || location!.isEmpty) &&
      parameters.isEmpty &&
      satisfactory == null &&
      (notes == null || notes!.isEmpty);

  factory SeaTrial.fromJson(Map<String, dynamic> j) => SeaTrial(
        date: j['date'] != null
            ? DateTime.tryParse(j['date'] as String)
            : null,
        durationHours: (j['duration_hours'] as num?)?.toDouble(),
        location: j['location'] as String?,
        parameters: (j['parameters'] as List?)
                ?.map((e) =>
                    SeaTrialParameter.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        satisfactory: j['satisfactory'] as bool?,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (date != null)
          'date':
              '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
        if (durationHours != null) 'duration_hours': durationHours,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (parameters.isNotEmpty)
          'parameters': parameters.map((e) => e.toJson()).toList(),
        if (satisfactory != null) 'satisfactory': satisfactory,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  SeaTrial copyWith({
    Object? date = _sentinel,
    Object? durationHours = _sentinel,
    Object? location = _sentinel,
    List<SeaTrialParameter>? parameters,
    Object? satisfactory = _sentinel,
    Object? notes = _sentinel,
  }) =>
      SeaTrial(
        date: date == _sentinel ? this.date : date as DateTime?,
        durationHours: durationHours == _sentinel
            ? this.durationHours
            : durationHours as double?,
        location:
            location == _sentinel ? this.location : location as String?,
        parameters: parameters ?? this.parameters,
        satisfactory: satisfactory == _sentinel
            ? this.satisfactory
            : satisfactory as bool?,
        notes: notes == _sentinel ? this.notes : notes as String?,
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
    this.seaTrial,
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

  /// Optional post-repair sea trial record (see [SeaTrial]). Null until the
  /// surveyor adds one.
  final SeaTrial? seaTrial;

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
    Object? seaTrial = _sentinel,
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
        seaTrial:
            seaTrial == _sentinel ? this.seaTrial : seaTrial as SeaTrial?,
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
      seaTrial: j['sea_trial'] != null
          ? SeaTrial.fromJson(j['sea_trial'] as Map<String, dynamic>)
          : null,
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
        if (seaTrial != null && !seaTrial!.isEmpty)
          'sea_trial': seaTrial!.toJson(),
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
