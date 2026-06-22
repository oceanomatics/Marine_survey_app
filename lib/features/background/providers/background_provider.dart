// lib/features/background/providers/background_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_client.dart';
import '../models/background_model.dart';

// Manages the free-form background narrative for a case (Supabase-backed).
// Context cues are handled by surveyorNotesProvider with ReportSection tags.

final backgroundProvider = AsyncNotifierProviderFamily<
    BackgroundNotifier, CaseBackground, String>(
  BackgroundNotifier.new,
);

class BackgroundNotifier extends FamilyAsyncNotifier<CaseBackground, String> {
  @override
  Future<CaseBackground> build(String caseId) => _fetch(caseId);

  Future<CaseBackground> _fetch(String caseId) async {
    final rows = await SupabaseService.client
        .from('case_background')
        .select()
        .eq('case_id', caseId)
        .limit(1);

    if ((rows as List).isEmpty) {
      return CaseBackground(
        caseId:    caseId,
        content:   '',
        updatedAt: DateTime.now(),
      );
    }
    return CaseBackground.fromMap(rows.first);
  }

  Future<void> save(String content) async {
    final caseId = arg;
    final record = CaseBackground(
      caseId:    caseId,
      content:   content,
      updatedAt: DateTime.now(),
    );

    await SupabaseService.client
        .from('case_background')
        .upsert(record.toMap(), onConflict: 'case_id');

    state = AsyncData(record);
  }
}
