// lib/features/interviews/providers/interview_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/interview_model.dart';
import '../../../core/api/supabase_client.dart';

final interviewsProvider = AsyncNotifierProviderFamily<
    InterviewsNotifier, List<InterviewModel>, String>(
  InterviewsNotifier.new,
);

class InterviewsNotifier
    extends FamilyAsyncNotifier<List<InterviewModel>, String> {
  @override
  Future<List<InterviewModel>> build(String arg) => _fetch();

  Future<List<InterviewModel>> _fetch() async {
    final data = await SupabaseService.client
        .from('interviews')
        .select()
        .eq('case_id', arg)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => InterviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InterviewModel> save({
    required String caseId,
    required List<InterviewParticipant> participants,
    required String transcript,
    required int durationSecs,
    String? title,
  }) async {
    final model = InterviewModel(
      interviewId:  const Uuid().v4(),
      caseId:       caseId,
      createdAt:    DateTime.now(),
      participants: participants,
      transcript:   transcript,
      durationSecs: durationSecs,
      title:        title,
    );
    await SupabaseService.client
        .from('interviews')
        .insert(model.toInsertJson());
    final current = state.valueOrNull ?? [];
    state = AsyncData([model, ...current]);
    return model;
  }

  Future<void> updateInterview(InterviewModel model) async {
    await SupabaseService.client
        .from('interviews')
        .update(model.toInsertJson())
        .eq('interview_id', model.interviewId);
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final m in current)
        if (m.interviewId == model.interviewId) model else m,
    ]);
  }

  Future<void> delete(String interviewId) async {
    await SupabaseService.client
        .from('interviews')
        .delete()
        .eq('interview_id', interviewId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(
        current.where((m) => m.interviewId != interviewId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
