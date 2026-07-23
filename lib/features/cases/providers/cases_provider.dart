// lib/features/cases/providers/cases_provider.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/case_model.dart';
import '../utils/case_title.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/services/drive_storage_service.dart';
import '../../checklist/providers/checklist_provider.dart';

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

  /// Phase 2 multi-tenancy (migration 044): cases.organisation_id is
  /// NOT NULL, resolved from the creating user's own surveyor_profiles
  /// row rather than assumed — a case always belongs to its creator's
  /// org.
  Future<String> _currentOrgId() async {
    final row = await SupabaseService.client
        .from('surveyor_profiles')
        .select('organisation_id')
        .eq('user_id', SupabaseService.userId)
        .single();
    return row['organisation_id'] as String;
  }

  Future<CaseModel> createCase({
    required String technicalFileNo,
    required CaseType caseType,
    OutputFormat? outputFormat,
    String? claimReference,
    String? clientId,
    String? vesselId,
    DateTime? instructionDate,
    int? caseYear,
  }) async {
    final orgId = await _currentOrgId();
    final data = await SupabaseService.client
        .from('cases')
        .insert({
          'technical_file_no':      technicalFileNo,
          'case_type':       caseType.value,
          'status':          'open',
          'organisation_id': orgId,
          if (outputFormat != null) 'output_format': outputFormat.value,
          if (claimReference != null) 'claim_reference': claimReference,
          if (clientId != null) 'client_id': clientId,
          if (vesselId != null) 'vessel_id': vesselId,
          if (caseYear != null) 'case_year': caseYear,
          if (instructionDate != null)
            'instruction_date':
                instructionDate.toIso8601String().split('T').first,
          'inbox_email_tag': technicalFileNo,
          'assigned_surveyor': SupabaseService.userId,
        })
        .select()
        .single();

    final newCase = CaseModel.fromJson(data);

    // Clone checklist template for this case type
    await _cloneChecklistTemplate(newCase.caseId, caseType);

    // Provision the Drive folder structure — best-effort, must not block or
    // fail case creation if Drive is offline/unconfigured.
    unawaited(DriveStorageService.ensureCaseFoldersExist(newCase).catchError(
        (e) => debugPrint('[CasesNotifier] Drive folder provisioning skipped: $e')));

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

    // Insert as case-specific checklist items — response left unset
    // (defaults to NULL/unanswered; see checklist_provider.dart).
    final items = templates.map((t) => {
      'case_id':        caseId,
      'template_type':  t['case_type'],
      'stage':          t['stage'],
      'item_no':        t['item_no'],
      'item_text':      t['item_text'],
      'linked_section': t['linked_section'],
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

  Future<void> updateSignOff({
    bool? attending,
    String? attendingName,
    DateTime? attendingAt,
    String? attendingSigPath,
    bool? reviewing,
    String? reviewingName,
    DateTime? reviewingAt,
    String? reviewingSigPath,
  }) async {
    final updates = <String, dynamic>{};
    if (attending != null) {
      updates['signed_off_attending'] = attending;
      if (attending && attendingAt == null) {
        updates['signed_off_attending_at'] = DateTime.now().toIso8601String();
      }
    }
    if (attendingName != null)    updates['signed_off_attending_name']     = attendingName;
    if (attendingAt != null)      updates['signed_off_attending_at']       = attendingAt.toIso8601String();
    if (attendingSigPath != null) updates['signed_off_attending_sig_path'] = attendingSigPath;
    if (reviewing != null) {
      updates['signed_off_reviewing'] = reviewing;
      if (reviewing && reviewingAt == null) {
        updates['signed_off_reviewing_at'] = DateTime.now().toIso8601String();
      }
    }
    if (reviewingName != null)    updates['signed_off_reviewing_name']     = reviewingName;
    if (reviewingAt != null)      updates['signed_off_reviewing_at']       = reviewingAt.toIso8601String();
    if (reviewingSigPath != null) updates['signed_off_reviewing_sig_path'] = reviewingSigPath;

    // If both now signed, record the combined timestamp
    final current = state.value;
    if (current != null) {
      final nowAttending = attending ?? current.signedOffAttending;
      final nowReviewing = reviewing ?? current.signedOffReviewing;
      if (nowAttending && nowReviewing) {
        updates['signed_off_at'] = DateTime.now().toIso8601String();
      }
    }

    if (updates.isEmpty) return;
    await SupabaseService.client.from('cases').update(updates).eq('case_id', arg);
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<void> updateCaseRefs({
    String? technicalFileNo,
    String? claimReference,
    CaseStatus? status,
    CaseType? caseType,
    DateTime? instructionDate,
    int? caseYear,
    OutputFormat? outputFormat,
    String? organisationId,
    String? baseCurrency,
    String? instructingParty,
    String? assured,
    String? costEstimateStatus,
    double? estimatedRepairCost,
    bool? costIncludesGeneralExpenses,
    String? costIncludesTowing,
    double? surveyFeeReserveHours,
    double? surveyFeeReserveExpenses,
    String? costEstimateComment,
    bool? followUpRequired,
    String? followUpDetail,
  }) async {
    final updates = <String, dynamic>{};
    if (technicalFileNo != null)  updates['technical_file_no'] = technicalFileNo;
    if (claimReference != null)   updates['claim_reference']   = claimReference;
    if (status != null)           updates['status']            = status.value;
    if (caseType != null)         updates['case_type']         = caseType.value;
    if (outputFormat != null)     updates['output_format']     = outputFormat.value;
    if (instructionDate != null) {
      updates['instruction_date'] = instructionDate.toIso8601String().split('T').first;
    }
    if (caseYear != null)         updates['case_year']         = caseYear;
    if (organisationId != null)   updates['organisation_id']   = organisationId;
    if (baseCurrency != null)     updates['base_currency']     = baseCurrency;
    if (instructingParty != null) updates['instructing_party'] = instructingParty;
    if (assured != null)          updates['assured']           = assured;
    if (costEstimateStatus != null)  updates['cost_estimate_status']  = costEstimateStatus;
    if (estimatedRepairCost != null) updates['estimated_repair_cost'] = estimatedRepairCost;
    if (costIncludesGeneralExpenses != null) {
      updates['cost_includes_general_expenses'] = costIncludesGeneralExpenses;
    }
    if (costIncludesTowing != null) {
      updates['cost_includes_towing'] = costIncludesTowing;
    }
    if (surveyFeeReserveHours != null) {
      updates['survey_fee_reserve_hours'] = surveyFeeReserveHours;
    }
    if (surveyFeeReserveExpenses != null) {
      updates['survey_fee_reserve_expenses'] = surveyFeeReserveExpenses;
    }
    if (costEstimateComment != null) updates['cost_estimate_comment'] = costEstimateComment;
    if (followUpRequired != null) updates['follow_up_required'] = followUpRequired;
    if (followUpDetail != null)   updates['follow_up_detail']   = followUpDetail;

    if (updates.isEmpty) return;
    await SupabaseService.client
        .from('cases')
        .update(updates)
        .eq('case_id', arg);
    state = await AsyncValue.guard(() => _fetch(arg));
    // Rebuild composite title whenever file no or case type may have changed;
    // also when case_year changes, since that renames the Drive case folder
    // (driveFolderName leads with the year — syncCaseFolderName runs inside
    // _rebuildTitle).
    if (technicalFileNo != null || caseType != null || caseYear != null) {
      await _rebuildTitle();
    }
    ref.invalidate(casesProvider);
  }

  /// Full replace of the "Other Matters of Relevance" ticked clause list
  /// (docs/migrations/018_other_matters_clauses.sql) — a toggle set rather
  /// than a single nullable field, so it doesn't fit updateCaseRefs's
  /// "only update if non-null" pattern.
  Future<void> updateOtherMattersClauses(List<String> clauseIds) async {
    await SupabaseService.client
        .from('cases')
        .update({'other_matters_clause_ids': clauseIds})
        .eq('case_id', arg);
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  /// Free-text additional notes for "Other Matters of Relevance" — see
  /// docs/migrations/019_other_matters_notes.sql. Rendered after the ticked
  /// clause text in the same report section.
  Future<void> updateOtherMattersNotes(String notes) async {
    await SupabaseService.client
        .from('cases')
        .update({'other_matters_notes': notes})
        .eq('case_id', arg);
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  /// Rebuilds the composite case title: "JobNo – Vessel – SurveyType – Occurrence"
  /// and persists it to cases.title. Skips if the file number is still a placeholder.
  Future<void> _rebuildTitle() async {
    try {
      final c = state.value;
      if (c == null) return;

      final jobNo   = c.hasPlaceholderFileNo ? '' : c.technicalFileNo;
      final vName   = c.vesselName ?? '';
      final ctLabel = c.caseType.label;

      // Primary (or only) occurrence title from DB
      final occRows = await SupabaseService.client
          .from('occurrences')
          .select('title, is_primary, occurrence_no')
          .eq('case_id', arg)
          .order('is_primary', ascending: false)
          .order('occurrence_no')
          .limit(1);

      final occTitle = (occRows as List).isNotEmpty
          ? (occRows.first['title'] as String? ?? '')
          : '';

      final newTitle = buildCaseTitle(
        jobNo:           jobNo,
        vesselName:      vName,
        caseTypeLabel:   ctLabel,
        occurrenceTitle: occTitle,
      );

      if (newTitle.isEmpty) return;
      await SupabaseService.client
          .from('cases')
          .update({'title': newTitle})
          .eq('case_id', arg);
      // Patch local state so the header updates instantly without a full refetch.
      final updated = c.copyWith(title: newTitle);
      state = AsyncData(updated);
      // Drive folder name depends on technical file no. / vessel name, both
      // of which can trigger this rebuild — resync (rename in place) best-effort.
      unawaited(DriveStorageService.syncCaseFolderName(updated).catchError(
          (e) => debugPrint('[CaseNotifier] Drive folder rename skipped: $e')));
    } catch (e) {
      debugPrint('[CaseNotifier] _rebuildTitle: $e');
    }
  }

  /// Creates a vessel record (if case has none) or updates the existing one,
  /// then links it to this case.
  Future<void> upsertVesselName(String vesselName) async {
    final current = state.value;
    if (current == null) return;

    if (current.vesselId != null) {
      // Guard (17 July 2026): never rename a vessel that is already identified
      // by IMO. A vessel name extracted from a cross-linked email must not
      // overwrite the real, IMO-verified vessel (the Balder-vs-Odin bug) — and
      // the vessel record may be shared by other cases. Skip the rename.
      final existing = await SupabaseService.client
          .from('vessels')
          .select('imo_number')
          .eq('vessel_id', current.vesselId!)
          .maybeSingle();
      final hasImo =
          ((existing?['imo_number'] as String?) ?? '').trim().isNotEmpty;
      if (hasImo) return;
      await SupabaseService.client
          .from('vessels')
          .update({'name': vesselName})
          .eq('vessel_id', current.vesselId!);
    } else {
      // Phase 2 multi-tenancy (migration 044): vessels.organisation_id is
      // NOT NULL — a vessel created for this case belongs to the same org
      // as the case itself.
      final row = await SupabaseService.client
          .from('vessels')
          .insert({'name': vesselName, 'organisation_id': current.organisationId})
          .select()
          .single();
      final newVesselId = row['vessel_id'] as String;
      await SupabaseService.client
          .from('cases')
          .update({'vessel_id': newVesselId})
          .eq('case_id', arg);
    }
    state = await AsyncValue.guard(() => _fetch(arg));
    await _rebuildTitle();
    ref.invalidate(casesProvider);
  }
}

// ── Checklist progress ─────────────────────────────────────────────────────

final checklistProgressProvider =
    FutureProvider.family<double, String>((ref, caseId) async {
  // Derive from the live checklist state (single source of truth) so the
  // case-home % updates the moment an item is ticked. Previously this ran its
  // own one-shot query that never re-ran on a tick, so the header % went stale
  // until the screen was rebuilt from scratch (17 July 2026 report). Watching
  // checklistProvider's future makes this recompute whenever the checklist
  // changes, and reuses ChecklistState.progress's na-excluded semantics.
  final cl = await ref.watch(checklistProvider(caseId).future);
  return cl.progress;
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
