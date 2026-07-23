// lib/features/pi/models/pi_models.dart
//
// Data models for the P&I / Expert module. The Opinion/Conclusions register
// (spec §4.4) is the genuinely-new data object — discrete reasoned opinion
// points with the GPN-EXPT / Harmonised Code cl.3 qualifiers. See migration
// 066_pi_opinion.sql. Mirrors the modern register pattern (action_items / cs).

import 'package:flutter/foundation.dart';

@immutable
class PiOpinionModel {
  const PiOpinionModel({
    required this.id,
    required this.caseId,
    required this.opinionText,
    this.heading,
    this.basis,
    this.outsideExpertise = false,
    this.notConcluded = false,
    this.qualifierNote,
    this.sourceRefs = const [],
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;
  final String opinionText;
  final String? heading;

  /// Assumptions / material facts the opinion is based on (Code cl.3(d)).
  final String? basis;

  /// cl.3(f) — the matter (partly) falls outside the expert's expertise.
  final bool outsideExpertise;

  /// cl.3(k) — opinion not concluded for want of sufficient data.
  final bool notConcluded;

  /// cl.3(j) — any other qualification on the opinion.
  final String? qualifierNote;

  /// Optional ids of supporting observations / damage-register items.
  final List<String> sourceRefs;

  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasQualifier =>
      outsideExpertise ||
      notConcluded ||
      (qualifierNote != null && qualifierNote!.trim().isNotEmpty);

  factory PiOpinionModel.fromJson(Map<String, dynamic> j) => PiOpinionModel(
        id: j['id'] as String,
        caseId: j['case_id'] as String,
        opinionText: j['opinion_text'] as String,
        heading: j['heading'] as String?,
        basis: j['basis'] as String?,
        outsideExpertise: j['outside_expertise'] as bool? ?? false,
        notConcluded: j['not_concluded'] as bool? ?? false,
        qualifierNote: j['qualifier_note'] as String?,
        sourceRefs: (j['source_refs'] as List?)?.cast<String>() ?? const [],
        sortOrder: j['sort_order'] as int? ?? 0,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );

  PiOpinionModel copyWith({
    String? opinionText,
    String? heading,
    String? basis,
    bool? outsideExpertise,
    bool? notConcluded,
    String? qualifierNote,
  }) =>
      PiOpinionModel(
        id: id,
        caseId: caseId,
        opinionText: opinionText ?? this.opinionText,
        heading: heading ?? this.heading,
        basis: basis ?? this.basis,
        outsideExpertise: outsideExpertise ?? this.outsideExpertise,
        notConcluded: notConcluded ?? this.notConcluded,
        qualifierNote: qualifierNote ?? this.qualifierNote,
        sourceRefs: sourceRefs,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
