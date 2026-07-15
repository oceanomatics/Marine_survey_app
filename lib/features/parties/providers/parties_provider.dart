// lib/features/parties/providers/parties_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/party_model.dart';
import '../../../core/api/supabase_client.dart';
import '../../correspondence/models/correspondence_model.dart';

// ── Case Parties (single record per case) ─────────────────────────────────

final partiesProvider =
    AsyncNotifierProviderFamily<PartiesNotifier, CasePartiesModel?, String>(
  PartiesNotifier.new,
);

class PartiesNotifier extends FamilyAsyncNotifier<CasePartiesModel?, String> {
  @override
  Future<CasePartiesModel?> build(String arg) => _fetch();

  Future<CasePartiesModel?> _fetch() async {
    final data = await SupabaseService.client
        .from('case_parties')
        .select()
        .eq('case_id', arg)
        .maybeSingle();
    if (data == null) return null;
    return CasePartiesModel.fromJson(data);
  }

  Future<void> save(CasePartiesModel model) async {
    await SupabaseService.client
        .from('case_parties')
        .upsert(model.toUpsertJson());
    state = AsyncData(model);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

// ── Assured Contacts / Stakeholders (multiple per case) ───────────────────

final assuredContactsProvider = AsyncNotifierProviderFamily<
    AssuredContactsNotifier, List<AssuredContactModel>, String>(
  AssuredContactsNotifier.new,
);

class AssuredContactsNotifier
    extends FamilyAsyncNotifier<List<AssuredContactModel>, String> {
  @override
  Future<List<AssuredContactModel>> build(String arg) => _fetch();

  Future<List<AssuredContactModel>> _fetch() async {
    final data = await SupabaseService.client
        .from('assured_contacts')
        .select()
        .eq('case_id', arg)
        .order('created_at');
    return (data as List)
        .map((j) => AssuredContactModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String caseId,
    required String fullName,
    String? company,
    String? roleTitle,
    StakeholderGroup? stakeholderGroup,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final payload = AssuredContactModel(
      contactId:        '',
      caseId:           caseId,
      fullName:         fullName,
      company:          company,
      roleTitle:        roleTitle,
      stakeholderGroup: stakeholderGroup,
      phone:            phone,
      email:            email,
      notes:            notes,
    );
    final inserted = await SupabaseService.client
        .from('assured_contacts')
        .insert(payload.toInsertJson())
        .select()
        .single();
    final created = AssuredContactModel.fromJson(inserted);
    final current = state.value ?? [];
    state = AsyncData([...current, created]);
  }

  /// Add all extracted parties from a correspondence in one call.
  /// Skips duplicates (same fullName already exists for this case).
  Future<int> addFromExtracted(
    String caseId,
    List<ExtractedParty> parties,
  ) async {
    // Correspondence's "Add to Parties" calls this via ref.read(...).notifier
    // without ever having watched this provider first (unlike the Parties
    // screen itself) — if this is the first touch of assuredContactsProvider
    // in the session, state.value is still null while the initial fetch is
    // in flight, so the dedupe check below would silently miss every
    // existing contact. `?? await future` waits for that first fetch to
    // land instead of racing it (found via a widget test, 15 July 2026).
    final existing = (state.value ?? await future)
        .map((c) => c.fullName.toLowerCase())
        .toSet();
    var added = 0;
    for (final p in parties) {
      if (existing.contains(p.name.toLowerCase())) continue;
      await add(
        caseId:           caseId,
        fullName:         p.name,
        company:          p.company,
        roleTitle:        p.role,
        stakeholderGroup: StakeholderGroup.fromRole(p.role),
        phone:            p.phone,
        email:            p.email,
      );
      existing.add(p.name.toLowerCase());
      added++;
    }
    return added;
  }

  Future<void> editContact(AssuredContactModel contact) async {
    await SupabaseService.client
        .from('assured_contacts')
        .update({
          'full_name':         contact.fullName,
          'company':           contact.company,
          'role_title':        contact.roleTitle,
          'stakeholder_group': contact.stakeholderGroup?.value,
          'phone':             contact.phone,
          'email':             contact.email,
          'notes':             contact.notes,
        })
        .eq('contact_id', contact.contactId);
    final current = state.value ?? [];
    state = AsyncData(
      current.map((c) => c.contactId == contact.contactId ? contact : c).toList(),
    );
  }

  Future<void> delete(String contactId) async {
    await SupabaseService.client
        .from('assured_contacts')
        .delete()
        .eq('contact_id', contactId);
    final current = state.value ?? [];
    state =
        AsyncData(current.where((c) => c.contactId != contactId).toList());
  }
}
