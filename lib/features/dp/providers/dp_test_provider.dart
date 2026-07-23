// lib/features/dp/providers/dp_test_provider.dart
//
// The DP FMEA trials test register, backed by the existing `trials_tests`
// scaffold table (RLS already in place). Case-scoped, direct-Supabase CRUD,
// optimistic patching. NB: PK column is `test_id`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/dp_models.dart';

final dpTestProvider =
    AsyncNotifierProviderFamily<DpTestNotifier, List<DpTestModel>, String>(
  DpTestNotifier.new,
);

class DpTestNotifier extends FamilyAsyncNotifier<List<DpTestModel>, String> {
  @override
  Future<List<DpTestModel>> build(String caseId) => _fetch(caseId);

  Future<List<DpTestModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('trials_tests')
        .select()
        .eq('case_id', caseId)
        .order('test_no', nullsFirst: false);
    return (data as List)
        .map((e) => DpTestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DpTestModel> add(String testName,
      {int? testNo, String? system}) async {
    final data = await SupabaseService.client
        .from('trials_tests')
        .insert({
          'case_id': arg,
          'test_name': testName,
          if (testNo != null) 'test_no': testNo,
          if (system != null) 'system': system,
        })
        .select()
        .single();
    final test = DpTestModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), test]);
    return test;
  }

  Future<void> setResult(String testId, DpTestResult? result) async {
    await SupabaseService.client
        .from('trials_tests')
        .update({'result': result?.value}).eq('test_id', testId);
    _patch(testId, (t) => t.copyWith(result: result));
  }

  Future<void> setFindingCategory(
      String testId, DpFindingCategory? category) async {
    await SupabaseService.client
        .from('trials_tests')
        .update({'finding_category': category?.value}).eq('test_id', testId);
    _patch(testId, (t) => t.copyWith(findingCategory: category));
  }

  Future<void> setObservations(String testId, String observations) async {
    await SupabaseService.client
        .from('trials_tests')
        .update({'observations': observations}).eq('test_id', testId);
    _patch(testId, (t) => t.copyWith(observations: observations));
  }

  Future<void> setWcfTested(String testId, bool value) async {
    await SupabaseService.client
        .from('trials_tests')
        .update({'wcf_tested': value}).eq('test_id', testId);
    _patch(testId, (t) => t.copyWith(wcfTested: value));
  }

  Future<void> setCarriedForward(String testId, bool value) async {
    await SupabaseService.client
        .from('trials_tests')
        .update({'carried_forward': value}).eq('test_id', testId);
    _patch(testId, (t) => t.copyWith(carriedForward: value));
  }

  Future<void> delete(String testId) async {
    await SupabaseService.client
        .from('trials_tests')
        .delete()
        .eq('test_id', testId);
    state =
        AsyncData((state.value ?? []).where((t) => t.testId != testId).toList());
  }

  void _patch(String testId, DpTestModel Function(DpTestModel) update) {
    final current = state.value ?? [];
    state = AsyncData(
        current.map((t) => t.testId == testId ? update(t) : t).toList());
  }
}
