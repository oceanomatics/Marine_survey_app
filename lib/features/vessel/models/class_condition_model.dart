// lib/features/vessel/models/class_condition_model.dart

import 'package:flutter/foundation.dart';

@immutable
class ClassConditionModel {
  const ClassConditionModel({
    required this.conditionId,
    required this.vesselId,
    this.reference,
    this.description,
    this.issuedDate,
    this.expiryDate,
    this.duration,
    this.status = 'open',
    this.occurrenceRelated = false,
    this.occurrenceId,
    this.createdAt,
  });

  final String conditionId;
  final String vesselId;
  final String? reference;
  final String? description;
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final String? duration;

  /// 'open' (outstanding) or 'closed' (cleared/lifted).
  final String status;
  final bool occurrenceRelated;
  final String? occurrenceId;
  final DateTime? createdAt;

  bool get isClosed => status == 'closed';

  factory ClassConditionModel.fromJson(Map<String, dynamic> j) =>
      ClassConditionModel(
        conditionId:       j['condition_id'] as String,
        vesselId:          j['vessel_id'] as String,
        reference:         j['reference'] as String?,
        description:       j['description'] as String?,
        issuedDate:        j['issued_date'] != null
            ? DateTime.tryParse(j['issued_date'] as String)
            : null,
        expiryDate:        j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'] as String)
            : null,
        duration:          j['duration'] as String?,
        status:            j['status'] as String? ?? 'open',
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
    if (issuedDate != null)
      'issued_date': issuedDate!.toIso8601String().split('T').first,
    if (expiryDate != null)
      'expiry_date': expiryDate!.toIso8601String().split('T').first,
    if (duration != null)     'duration':     duration,
    'status':             status,
    'occurrence_related': occurrenceRelated,
    if (occurrenceId != null) 'occurrence_id': occurrenceId,
  };

  ClassConditionModel copyWith({
    String? reference,
    String? description,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? duration,
    String? status,
    bool? occurrenceRelated,
    String? occurrenceId,
  }) =>
      ClassConditionModel(
        conditionId:       conditionId,
        vesselId:          vesselId,
        reference:         reference         ?? this.reference,
        description:       description       ?? this.description,
        issuedDate:        issuedDate        ?? this.issuedDate,
        expiryDate:        expiryDate        ?? this.expiryDate,
        duration:          duration          ?? this.duration,
        status:            status            ?? this.status,
        occurrenceRelated: occurrenceRelated ?? this.occurrenceRelated,
        occurrenceId:      occurrenceId      ?? this.occurrenceId,
        createdAt:         createdAt,
      );
}
