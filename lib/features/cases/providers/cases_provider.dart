// lib/features/cases/providers/cases_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/case_model.dart';
import '../../../core/api/supabase_client.dart';

// ── All cases list ─────────────────────────────────────────────────────────

final casesProvider = AsyncNotifierProvider<CasesNotifier, List<CaseModel>>(
  CasesNotifier.new,
);

class CasesNotifier extends AsyncNotifier<List<CaseModel>> {
  @override
  Future<List<CaseModel>> build() async {
    return _fetchCases();
  }

  Future<List<CaseModel>> _fetchCases() async {
    final data = await SupabaseService.client
        .from('cases')
        .select('''
          *,
          vessels(name),
          principals_clients!cases_client_id_fkey(name)
        ''')
        .order('created_at', ascending: false);

    return (data as List).map((json) {
      final vessel = json['vessels'] as Map<String, dynamic>?;
      final client = json['principals_clients'] as Map<String, dynamic>?;
      return CaseModel.fromJson({
        ...json,
        'vessel_name': vessel?['name'],
        'client_name': client?['name'],
      });
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchCases);
  }

  Future<CaseModel> createCase({
    required String jobNumber,
    required CaseType caseType,
    OutputFormat? outputFormat,
    String? claimReference,
    String? clientId,
    String? vesselId,
    DateTime? instructionDate,
  }) async {
    final data = await SupabaseService.client
        .from('cases')
        .insert({
          'job_number':      jobNumber,
          'case_type':       caseType.value,
          'status':          'open',
          if (outputFormat != null) 'output_format': outputFormat.value,
          if (claimReference != null) 'claim_reference': claimReference,
          if (clientId != null) 'client_id': clientId,
          if (vesselId != null) 'vessel_id': vesselId,
          if (instructionDate != null)
            'instruction_date':
                instructionDate.toIso8601String().split('T').first,
          'inbox_email_tag': jobNumber,
          'assigned_surveyor': SupabaseService.userId,
        })
        .select()
        .single();

    final newCase = CaseModel.fromJson(data);

    // Clone checklist template for this case type
    await _cloneChecklistTemplate(newCase.caseId, caseType);

    // Refresh list
    await refresh();
    return newCase;
  }

  Future<void> deleteCase(String caseId) async {
    await SupabaseService.client
        .from('cases')
        .delete()
        .eq('case_id', caseId);
    await refresh();
  }

  Future<void> updateCaseStatus(String caseId, CaseStatus status) async {
    await SupabaseService.client
        .from('cases')
        .update({'status': status.value})
        .eq('case_id', caseId);
    await refresh();
  }

  Future<void> _cloneChecklistTemplate(
      String caseId, CaseType caseType) async {
    // Fetch template items for this case type
    final templates = await SupabaseService.client
        .from('checklist_templates')
        .select()
        .eq('case_type', caseType.value)
        .order('stage')
        .order('item_no');

    if ((templates as List).isEmpty) return;

    // Insert as case-specific checklist items
    final items = templates.map((t) => {
      'case_id':        caseId,
      'template_type':  t['case_type'],
      'stage':          t['stage'],
      'item_no':        t['item_no'],
      'item_text':      t['item_text'],
      'linked_section': t['linked_section'],
      'completed':      false,
    }).toList();

    await SupabaseService.client.from('checklists').insert(items);
  }
}

// ── Single case ────────────────────────────────────────────────────────────

final caseProvider = AsyncNotifierProviderFamily<CaseNotifier, CaseModel, String>(
  CaseNotifier.new,
);

class CaseNotifier extends FamilyAsyncNotifier<CaseModel, String> {
  @override
  Future<CaseModel> build(String caseId) async {
    return _fetch(caseId);
  }

  Future<CaseModel> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('cases')
        .select('''
          *,
          vessels(*),
          principals_clients!cases_client_id_fkey(name)
        ''')
        .eq('case_id', caseId)
        .single();

    final vessel = data['vessels'] as Map<String, dynamic>?;
    final client = data['principals_clients'] as Map<String, dynamic>?;

    return CaseModel.fromJson({
      ...data,
      'vessel_name': vessel?['name'],
      'client_name': client?['name'],
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> updateCaseRefs({
    String? jobNumber,
    String? claimReference,
    CaseStatus? status,
    CaseType? caseType,
    DateTime? instructionDate,
    OutputFormat? outputFormat,
    String? organisationId,
    String? baseCurrency,
    String? policyUcr,
    String? policyNumber,
    PolicyType? policyType,
    String? instructingParty,
    InstructingPartyRole? instructingPartyRole,
    String? assured,
    DateTime? dateOfFirstAttendance,
    String? surveyLocation,
  }) async {
    final updates = <String, dynamic>{};
    if (jobNumber != null)            updates['job_number']               = jobNumber;
    if (claimReference != null)       updates['claim_reference']          = claimReference;
    if (status != null)               updates['status']                   = status.value;
    if (caseType != null)             updates['case_type']                = caseType.value;
    if (outputFormat != null)         updates['output_format']            = outputFormat.value;
    if (instructionDate != null) {
      updates['instruction_date'] = instructionDate.toIso8601String().split('T').first;
    }
    if (organisationId != null)       updates['organisation_id']          = organisationId;
    if (baseCurrency != null)         updates['base_currency']            = baseCurrency;
    if (policyUcr != null)            updates['policy_ucr']               = policyUcr;
    if (policyNumber != null)         updates['policy_number']            = policyNumber;
    if (policyType != null)           updates['policy_type']              = policyType.value;
    if (instructingParty != null)     updates['instructing_party']        = instructingParty;
    if (instructingPartyRole != null) updates['instructing_party_role']   = instructingPartyRole.value;
    if (assured != null)              updates['assured']                  = assured;
    if (dateOfFirstAttendance != null) {
      updates['date_of_first_attendance'] =
          dateOfFirstAttendance.toIso8601String().split('T').first;
    }
    if (surveyLocation != null)       updates['survey_location']          = surveyLocation;
    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('cases')
        .update(updates)
        .eq('case_id', arg);
    state = await AsyncValue.guard(() => _fetch(arg));
    ref.invalidate(casesProvider);
  }

  /// Creates a vessel record (if case has none) or updates the existing one,
  /// then links it to this case.
  Future<void> upsertVesselName(String vesselName) async {
    final current = state.value;
    if (current == null) return;

    if (current.vesselId != null) {
      await SupabaseService.client
          .from('vessels')
          .update({'name': vesselName})
          .eq('vessel_id', current.vesselId!);
    } else {
      final row = await SupabaseService.client
          .from('vessels')
          .insert({'name': vesselName})
          .select()
          .single();
      final newVesselId = row['vessel_id'] as String;
      await SupabaseService.client
          .from('cases')
          .update({'vessel_id': newVesselId})
          .eq('case_id', arg);
    }
    state = await AsyncValue.guard(() => _fetch(arg));
    ref.invalidate(casesProvider);
  }
}

// ── Checklist progress ─────────────────────────────────────────────────────

final checklistProgressProvider =
    FutureProvider.family<double, String>((ref, caseId) async {
  final data = await SupabaseService.client
      .from('checklists')
      .select('completed')
      .eq('case_id', caseId);

  final items = data as List;
  if (items.isEmpty) return 0;
  final done = items.where((i) => i['completed'] == true).length;
  return done / items.length;
});

// ── Quick capture count (pending items) ───────────────────────────────────

final pendingCapturesProvider =
    FutureProvider.family<int, String>((ref, caseId) async {
  final data = await SupabaseService.client
      .from('quick_captures')
      .select('capture_id')
      .eq('case_id', caseId)
      .eq('status', 'pending');
  return (data as List).length;
});
