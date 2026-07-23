// lib/features/cs/providers/cs_certificate_provider.dart
//
// The C&S §3.0 certification register (cs_certificate, created in migration
// 064). Case-scoped, direct-Supabase CRUD, optimistic patching.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';
import '../models/cs_models.dart';

final csCertificateProvider = AsyncNotifierProviderFamily<CsCertificateNotifier,
    List<CsCertificateModel>, String>(
  CsCertificateNotifier.new,
);

class CsCertificateNotifier
    extends FamilyAsyncNotifier<List<CsCertificateModel>, String> {
  @override
  Future<List<CsCertificateModel>> build(String caseId) => _fetch(caseId);

  Future<List<CsCertificateModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('cs_certificate')
        .select()
        .eq('case_id', caseId)
        .order('sort_order');
    return (data as List)
        .map((e) => CsCertificateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CsCertificateModel> add({
    required String certType,
    DateTime? issuedDate,
    String? issuedPlace,
    DateTime? expiryDate,
    String? status,
  }) async {
    String? d(DateTime? x) => x?.toIso8601String().split('T').first;
    final data = await SupabaseService.client
        .from('cs_certificate')
        .insert({
          'case_id': arg,
          'cert_type': certType,
          if (issuedDate != null) 'issued_date': d(issuedDate),
          if (issuedPlace != null) 'issued_place': issuedPlace,
          if (expiryDate != null) 'expiry_date': d(expiryDate),
          if (status != null) 'status': status,
        })
        .select()
        .single();
    final cert = CsCertificateModel.fromJson(data);
    state = AsyncData([...(state.value ?? []), cert]);
    return cert;
  }

  Future<void> setStatus(String id, String status) async {
    await SupabaseService.client
        .from('cs_certificate')
        .update({'status': status}).eq('id', id);
    state = AsyncData((state.value ?? [])
        .map((c) => c.id == id ? _withStatus(c, status) : c)
        .toList());
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('cs_certificate').delete().eq('id', id);
    state = AsyncData((state.value ?? []).where((c) => c.id != id).toList());
  }

  CsCertificateModel _withStatus(CsCertificateModel c, String status) =>
      CsCertificateModel(
        id: c.id,
        caseId: c.caseId,
        certType: c.certType,
        issuedDate: c.issuedDate,
        issuedPlace: c.issuedPlace,
        expiryDate: c.expiryDate,
        status: status,
        documentId: c.documentId,
        sortOrder: c.sortOrder,
      );
}
