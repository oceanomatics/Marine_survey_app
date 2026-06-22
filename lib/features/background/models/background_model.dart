// lib/features/background/models/background_model.dart

import 'package:flutter/foundation.dart';

@immutable
class CaseBackground {
  const CaseBackground({
    required this.caseId,
    required this.content,
    required this.updatedAt,
  });

  final String caseId;
  final String content;
  final DateTime updatedAt;

  factory CaseBackground.fromMap(Map<String, dynamic> m) => CaseBackground(
        caseId:    m['case_id'] as String,
        content:   m['content'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'case_id':    caseId,
        'content':    content,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  CaseBackground copyWith({String? content}) => CaseBackground(
        caseId:    caseId,
        content:   content ?? this.content,
        updatedAt: DateTime.now(),
      );
}
