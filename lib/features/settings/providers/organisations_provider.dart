// lib/features/settings/providers/organisations_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organisation_model.dart';
import '../../../core/api/supabase_client.dart';

final organisationsProvider =
    AsyncNotifierProvider<OrganisationsNotifier, List<OrganisationModel>>(
  OrganisationsNotifier.new,
);

class OrganisationsNotifier
    extends AsyncNotifier<List<OrganisationModel>> {
  @override
  Future<List<OrganisationModel>> build() => _fetch();

  Future<List<OrganisationModel>> _fetch() async {
    final data = await SupabaseService.client
        .from('organisations')
        .select('*, surveyor_profiles(*)')
        .order('created_at');
    return (data as List)
        .map((j) => OrganisationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<OrganisationModel> createOrganisation({required String name}) async {
    final row = await SupabaseService.client
        .from('organisations')
        .insert({'name': name})
        .select()
        .single();
    await refresh();
    return OrganisationModel.fromJson(row);
  }

  Future<void> saveOrganisation(OrganisationModel org) async {
    await SupabaseService.client
        .from('organisations')
        .update(org.toJson())
        .eq('id', org.organisationId);
    await refresh();
  }

  Future<void> deleteOrganisation(String orgId) async {
    await SupabaseService.client
        .from('organisations')
        .delete()
        .eq('id', orgId);
    await refresh();
  }

  // ── Surveyor profiles ──────────────────────────────────────────────────────

  Future<void> addSurveyorProfile({
    required String organisationId,
    required String fullName,
    String? title,
    String? qualifications,
    String? email,
    String? phone,
  }) async {
    await SupabaseService.client.from('surveyor_profiles').insert({
      'organisation_id': organisationId,
      'full_name':       fullName,
      if (title != null)          'title':          title,
      if (qualifications != null) 'qualifications': qualifications,
      if (email != null)          'email':          email,
      if (phone != null)          'phone':          phone,
    });
    await refresh();
  }

  Future<void> saveSurveyorProfile(SurveyorProfileModel profile) async {
    await SupabaseService.client
        .from('surveyor_profiles')
        .update(profile.toJson())
        .eq('id', profile.profileId);
    await refresh();
  }

  Future<void> deleteSurveyorProfile(String profileId) async {
    await SupabaseService.client
        .from('surveyor_profiles')
        .delete()
        .eq('id', profileId);
    await refresh();
  }
}
