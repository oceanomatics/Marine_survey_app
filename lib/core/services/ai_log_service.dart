// lib/core/services/ai_log_service.dart
//
// Writes to ai_generation_log for GPN-AI compliance (Federal Court of
// Australia, April 2026).  Called from the ClaudeApi Dio interceptor — any
// failure is silently swallowed so it never breaks the calling feature.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../api/supabase_client.dart';

class AiLogService {
  static Future<void> log({
    required String caseId,
    required String callType,
    required String model,
    required String promptText,
    required String responseText,
    String? sectionLabel,
    String? documentId,
    int? inputTokens,
    int? outputTokens,
  }) async {
    try {
      final digest = sha256.convert(utf8.encode(promptText));
      await SupabaseService.client.from('ai_generation_log').insert({
        'case_id':       caseId,
        'call_type':     callType,
        'model':         model,
        'prompt_text':   promptText,
        'prompt_sha256': digest.toString(),
        'response_text': responseText,
        if (sectionLabel != null) 'section_label': sectionLabel,
        if (documentId != null)   'document_id':   documentId,
        if (inputTokens != null)  'input_tokens':  inputTokens,
        if (outputTokens != null) 'output_tokens': outputTokens,
      });
    } catch (_) {
      // Logging failure must never break the feature that triggered it
    }
  }
}
