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
  final RepairType outcome; // reuses the existing RepairType enum
  final bool isConcerningAverage;
  final String? notes;

  factory RepairAssignmentModel.fromJson(Map<String, dynamic> j) =>
      RepairAssignmentModel(
        assignmentId:       j['assignment_id'] as String,
        periodId:           j['period_id'] as String,
        damageId:           j['damage_id'] as String,
        outcome:            RepairType.fromValue(j['outcome'] as String),
        isConcerningAverage: j['is_concerning_average'] as bool? ?? true,
        notes:              j['notes'] as String?,
      );
}

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

  String get displayTitle => title ?? 'Repair Period $periodNo';

  factory RepairPeriodModel.fromJson(
    Map<String, dynamic> j, {
    List<RepairAssignmentModel> assignments = const [],
  }) =>
      RepairPeriodModel(
        periodId:    j['period_id'] as String,
        caseId:      j['case_id'] as String,
        periodNo:    j['period_no'] as int? ?? 1,
        title:       j['title'] as String?,
        startDate:   j['start_date'] != null
            ? DateTime.tryParse(j['start_date'] as String)
            : null,
        endDate:     j['end_date'] != null
            ? DateTime.tryParse(j['end_date'] as String)
            : null,
        location:    j['location'] as String?,
        portContext: PortContext.fromValue(
            j['port_context'] as String? ?? 'planned'),
        notes:       j['notes'] as String?,
        assignments: assignments,
        createdAt:   j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':      caseId,
        'period_no':    periodNo,
        'port_context': portContext.value,
        if (title != null)     'title':      title,
        if (startDate != null) 'start_date': _fmt(startDate!),
        if (endDate != null)   'end_date':   _fmt(endDate!),
        if (location != null)  'location':   location,
        if (notes != null)     'notes':      notes,
      };

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
