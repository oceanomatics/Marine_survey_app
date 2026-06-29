// lib/core/models/ai_generation_log_model.dart

import 'package:flutter/foundation.dart';

@immutable
class AiGenerationLogModel {
  const AiGenerationLogModel({
    required this.id,
    required this.caseId,
    required this.callType,
    required this.model,
    required this.promptText,
    required this.promptSha256,
    required this.responseText,
    this.reportId,
    this.sectionLabel,
    this.documentId,
    this.inputTokens,
    this.outputTokens,
    this.humanReviewed = false,
    this.humanEdited = false,
    this.reviewedAt,
    this.reviewedBy,
    this.createdAt,
  });

  final String id;
  final String caseId;
  final String? reportId;

  // 'extraction' | 'report_section' | 'invoice_extraction' | 'correspondence'
  final String callType;
  final String? sectionLabel;  // e.g. 'damage_description', 'cost_section'
  final String? documentId;

  final String model;
  final String promptText;
  final String promptSha256;
  final String responseText;
  final int? inputTokens;
  final int? outputTokens;

  // GPN-AI compliance
  final bool humanReviewed;
  final bool humanEdited;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  final DateTime? createdAt;

  factory AiGenerationLogModel.fromJson(Map<String, dynamic> json) =>
      AiGenerationLogModel(
        id:           json['id'] as String,
        caseId:       json['case_id'] as String,
        reportId:     json['report_id'] as String?,
        callType:     json['call_type'] as String,
        sectionLabel: json['section_label'] as String?,
        documentId:   json['document_id'] as String?,
        model:        json['model'] as String,
        promptText:   json['prompt_text'] as String,
        promptSha256: json['prompt_sha256'] as String,
        responseText: json['response_text'] as String,
        inputTokens:  json['input_tokens'] as int?,
        outputTokens: json['output_tokens'] as int?,
        humanReviewed: json['human_reviewed'] as bool? ?? false,
        humanEdited:   json['human_edited'] as bool? ?? false,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.tryParse(json['reviewed_at'] as String)
            : null,
        reviewedBy: json['reviewed_by'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}
