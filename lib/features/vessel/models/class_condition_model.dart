// lib/features/vessel/models/class_condition_model.dart

import 'package:flutter/foundation.dart';

@immutable
class ClassConditionModel {
  const ClassConditionModel({
    required this.conditionId,
    required this.vesselId,
    this.reference,
    this.description,
    this.expiryDate,
    this.occurrenceRelated = false,
    this.occurrenceId,
    this.createdAt,
  });

  final String conditionId;
  final String vesselId;
  final String? reference;
  final String? description;
  final DateTime? expiryDate;
  final bool occurrenceRelated;
  final String? occurrenceId;
  final DateTime? createdAt;

  factory ClassConditionModel.fromJson(Map<String, dynamic> j) =>
      ClassConditionModel(
        conditionId:       j['condition_id'] as String,
        vesselId:          j['vessel_id'] as String,
        reference:         j['reference'] as String?,
        description:       j['description'] as String?,
        expiryDate:        j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'] as String)
            : null,
        occurrenceRelated: j['occurrence_related'] as bool? ?? false,
        occurrenceId:      j['occurrence_id'] as String?,
        createdAt:         j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'vessel_id':          vesselId,
    if (reference != null)    'reference':    reference,
    if (description != null)  'description':  description,
    if (expiryDate != null)
      'expiry_date': expiryDate!.toIso8601String().split('T').first,
    'occurrence_related': occurrenceRelated,
    if (occurrenceId != null) 'occurrence_id': occurrenceId,
  };

  ClassConditionModel copyWith({
    String? reference,
    String? description,
    DateTime? expiryDate,
    bool? occurrenceRelated,
    String? occurrenceId,
  }) =>
      ClassConditionModel(
        conditionId:       conditionId,
        vesselId:          vesselId,
        reference:         reference         ?? this.reference,
        description:       description       ?? this.description,
        expiryDate:        expiryDate        ?? this.expiryDate,
        occurrenceRelated: occurrenceRelated ?? this.occurrenceRelated,
        occurrenceId:      occurrenceId      ?? this.occurrenceId,
        createdAt:         createdAt,
      );
}
