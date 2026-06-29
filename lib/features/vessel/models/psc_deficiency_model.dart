// lib/features/vessel/models/psc_deficiency_model.dart

import 'package:flutter/foundation.dart';

@immutable
class PscDeficiencyModel {
  const PscDeficiencyModel({
    required this.deficiencyId,
    required this.vesselId,
    this.code,
    this.description,
    this.actionRequired,
    this.rectified = false,
    this.createdAt,
  });

  final String deficiencyId;
  final String vesselId;
  final String? code;
  final String? description;
  final String? actionRequired;
  final bool rectified;
  final DateTime? createdAt;

  factory PscDeficiencyModel.fromJson(Map<String, dynamic> j) =>
      PscDeficiencyModel(
        deficiencyId:   j['deficiency_id'] as String,
        vesselId:       j['vessel_id'] as String,
        code:           j['code'] as String?,
        description:    j['description'] as String?,
        actionRequired: j['action_required'] as String?,
        rectified:      j['rectified'] as bool? ?? false,
        createdAt:      j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'vessel_id':         vesselId,
    if (code != null)           'code':            code,
    if (description != null)    'description':     description,
    if (actionRequired != null) 'action_required': actionRequired,
    'rectified':         rectified,
  };

  PscDeficiencyModel copyWith({
    String? code,
    String? description,
    String? actionRequired,
    bool? rectified,
  }) =>
      PscDeficiencyModel(
        deficiencyId:   deficiencyId,
        vesselId:       vesselId,
        code:           code           ?? this.code,
        description:    description    ?? this.description,
        actionRequired: actionRequired ?? this.actionRequired,
        rectified:      rectified      ?? this.rectified,
        createdAt:      createdAt,
      );
}
