// lib/features/survey/models/nature_of_repairs_model.dart

import 'package:flutter/foundation.dart';

@immutable
class RepairSequenceItem {
  const RepairSequenceItem({required this.itemId, required this.text});
  final String itemId;
  final String text;

  factory RepairSequenceItem.fromJson(Map<String, dynamic> j) =>
      RepairSequenceItem(
        itemId: j['item_id'] as String,
        text:   j['text'] as String,
      );

  Map<String, dynamic> toJson() => {'item_id': itemId, 'text': text};
}

@immutable
class NatureOfRepairs {
  const NatureOfRepairs({
    required this.caseId,
    this.drydockingRequired = false,
    this.drydockingComment,
    this.assuredPlanFormulated = false,
    this.assuredPlanComment,
    this.furtherInspectionsPlanned = false,
    this.furtherInspectionsComment,
    this.partsLongLeadTime = false,
    this.partsLeadTimeComment,
    this.foreseeableDifficulties = false,
    this.foreseeableDifficultiesComment,
    this.sequenceItems = const [],
    required this.updatedAt,
  });

  final String caseId;
  final bool drydockingRequired;
  final String? drydockingComment;
  final bool assuredPlanFormulated;
  final String? assuredPlanComment;
  final bool furtherInspectionsPlanned;
  final String? furtherInspectionsComment;
  final bool partsLongLeadTime;
  final String? partsLeadTimeComment;
  final bool foreseeableDifficulties;
  final String? foreseeableDifficultiesComment;
  final List<RepairSequenceItem> sequenceItems;
  final DateTime updatedAt;

  factory NatureOfRepairs.empty(String caseId) =>
      NatureOfRepairs(caseId: caseId, updatedAt: DateTime.now());

  factory NatureOfRepairs.fromMap(Map<String, dynamic> m) => NatureOfRepairs(
        caseId: m['case_id'] as String,
        drydockingRequired: m['drydocking_required'] as bool? ?? false,
        drydockingComment: m['drydocking_comment'] as String?,
        assuredPlanFormulated: m['assured_plan_formulated'] as bool? ?? false,
        assuredPlanComment: m['assured_plan_comment'] as String?,
        furtherInspectionsPlanned:
            m['further_inspections_planned'] as bool? ?? false,
        furtherInspectionsComment: m['further_inspections_comment'] as String?,
        partsLongLeadTime: m['parts_long_lead_time'] as bool? ?? false,
        partsLeadTimeComment: m['parts_lead_time_comment'] as String?,
        foreseeableDifficulties: m['foreseeable_difficulties'] as bool? ?? false,
        foreseeableDifficultiesComment:
            m['foreseeable_difficulties_comment'] as String?,
        sequenceItems: (m['sequence_items'] as List?)
                ?.map((e) =>
                    RepairSequenceItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String).toLocal()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'case_id': caseId,
        'drydocking_required': drydockingRequired,
        'drydocking_comment': drydockingComment,
        'assured_plan_formulated': assuredPlanFormulated,
        'assured_plan_comment': assuredPlanComment,
        'further_inspections_planned': furtherInspectionsPlanned,
        'further_inspections_comment': furtherInspectionsComment,
        'parts_long_lead_time': partsLongLeadTime,
        'parts_lead_time_comment': partsLeadTimeComment,
        'foreseeable_difficulties': foreseeableDifficulties,
        'foreseeable_difficulties_comment': foreseeableDifficultiesComment,
        'sequence_items': sequenceItems.map((e) => e.toJson()).toList(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  /// True when nothing has been entered — the report subsection is
  /// omitted entirely in that case, same convention as other
  /// conditionally-empty sections (Other Matters, WNCA).
  bool get isEmpty =>
      !drydockingRequired &&
      !assuredPlanFormulated &&
      !furtherInspectionsPlanned &&
      !partsLongLeadTime &&
      !foreseeableDifficulties &&
      sequenceItems.isEmpty;
}
