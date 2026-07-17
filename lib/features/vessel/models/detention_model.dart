// lib/features/vessel/models/detention_model.dart

import 'package:flutter/foundation.dart';

/// A Port State Control detention event for a vessel.
/// Typically sourced from the Equasis report (manual entry for now).
@immutable
class DetentionModel {
  const DetentionModel({
    required this.detentionId,
    required this.vesselId,
    this.detainedDate,
    this.releasedDate,
    this.port,
    this.authority,
    this.reason,
    this.resolved = false,
    this.createdAt,
  });

  final String detentionId;
  final String vesselId;
  final DateTime? detainedDate;
  final DateTime? releasedDate;
  final String? port;
  final String? authority;
  final String? reason;
  final bool resolved;
  final DateTime? createdAt;

  factory DetentionModel.fromJson(Map<String, dynamic> j) => DetentionModel(
        detentionId:  j['detention_id'] as String,
        vesselId:     j['vessel_id'] as String,
        detainedDate: j['detained_date'] != null
            ? DateTime.tryParse(j['detained_date'] as String)
            : null,
        releasedDate: j['released_date'] != null
            ? DateTime.tryParse(j['released_date'] as String)
            : null,
        port:         j['port'] as String?,
        authority:    j['authority'] as String?,
        reason:       j['reason'] as String?,
        resolved:     j['resolved'] as bool? ?? false,
        createdAt:    j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'vessel_id': vesselId,
        if (detainedDate != null)
          'detained_date': detainedDate!.toIso8601String().split('T').first,
        if (releasedDate != null)
          'released_date': releasedDate!.toIso8601String().split('T').first,
        if (port != null)      'port':      port,
        if (authority != null) 'authority': authority,
        if (reason != null)    'reason':    reason,
        'resolved': resolved,
      };
}
