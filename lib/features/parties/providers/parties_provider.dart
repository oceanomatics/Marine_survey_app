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
    // Merge, don't skip: an extracted party whose name already exists may
    // carry data the stored contact is missing (16 July 2026 — a second email
    // from Ryan Allison finally included his address, but re-importing him
    // dropped it because he "already existed"). Fill any blank field on the
    // existing record; only insert a genuinely new contact. Returns the number
    // of contacts added OR updated.
    final current = List<AssuredContactModel>.from(state.value ?? await future);
    final byName = {for (final c in current) c.fullName.toLowerCase(): c};
    final processed = <String>{};
    var affected = 0;
    for (final p in parties) {
      final key = p.name.toLowerCase();
      if (!processed.add(key)) continue; // handle each name once per batch
      final existing = byName[key];
      if (existing != null) {
        final merged = AssuredContactModel(
          contactId:        existing.contactId,
          caseId:           existing.caseId,
          fullName:         existing.fullName,
          company:          _fill(existing.company, p.company),
          roleTitle:        _fill(existing.roleTitle, p.role),
          stakeholderGroup: existing.stakeholderGroup ??
              StakeholderGroup.fromRole(p.role),
          phone:            _fill(existing.phone, p.phone),
          email:            _fill(existing.email, p.email),
          notes:            existing.notes,
        );
        if (!_sameContact(merged, existing)) {
          await editContact(merged);
          affected++;
        }
        continue;
      }
      await add(
        caseId:           caseId,
        fullName:         p.name,
        company:          p.company,
        roleTitle:        p.role,
        stakeholderGroup: StakeholderGroup.fromRole(p.role),
        phone:            p.phone,
        email:            p.email,
      );
      affected++;
    }
    return affected;
  }

  /// Add stakeholders extracted from a document (Document Vault extraction —
  /// `detected_contacts`). Each map carries `name` plus optional `role`
  /// (professional title/function), `company`, `email`, `phone`. Delegates to
  /// [addFromExtracted] so the same dedupe + non-destructive merge applies.
  /// Returns the number of contacts added or updated.
  Future<int> addFromExtractedContacts(
    String caseId,
    List<Map<String, dynamic>> contacts,
  ) async {
    final parties = <ExtractedParty>[];
    for (final c in contacts) {
      final name = c['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      String? s(Object? v) {
        final t = v?.toString().trim();
        return (t == null || t.isEmpty) ? null : t;
      }
      parties.add(ExtractedParty(
        name: name,
        company: s(c['company']),
        role: s(c['role']),
        email: s(c['email']),
        phone: s(c['phone']),
      ));
    }
    if (parties.isEmpty) return 0;
    return addFromExtracted(caseId, parties);
  }

  /// Prefer an existing non-blank value; otherwise take the incoming one.
  String? _fill(String? existing, String? incoming) =>
      (existing != null && existing.trim().isNotEmpty) ? existing : incoming;

  bool _sameContact(AssuredContactModel a, AssuredContactModel b) =>
      a.company == b.company &&
      a.roleTitle == b.roleTitle &&
      a.stakeholderGroup == b.stakeholderGroup &&
      a.phone == b.phone &&
      a.email == b.email;

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
