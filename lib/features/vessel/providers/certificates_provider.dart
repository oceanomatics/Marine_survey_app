// lib/features/vessel/providers/certificates_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum CertType {
  classCertificate('class_certificate', 'Class Certificate'),
  doc('doc', 'Document of Compliance (DOC)'),
  smc('smc', 'Safety Management Certificate (SMC)'),
  flagState('flag_state', 'Flag State Certificate'),
  loadLine('load_line', 'Load Line Certificate'),
  marpol('marpol', 'MARPOL / IOPP'),
  safetyEquipment('safety_equipment', 'Safety Equipment Certificate'),
  safetyRadio('safety_radio', 'Safety Radio Certificate'),
  safetyConstruction('safety_construction', 'Safety Construction Certificate'),
  iopp('iopp', 'IOPP Certificate'),
  issc('issc', 'International Ship Security Certificate'),
  pscInspection('psc_inspection', 'Port State Control Inspection'),
  dpCertificate('dp_certificate', 'DP Certificate'),
  other('other', 'Other');

  const CertType(this.value, this.label);
  final String value;
  final String label;

  static CertType fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => CertType.other);
}

enum CertStatus {
  valid('valid', 'Valid'),
  expired('expired', 'Expired'),
  suspended('suspended', 'Suspended'),
  notSighted('not_sighted', 'Not Sighted'),
  tbc('tbc', 'TBC');

  const CertStatus(this.value, this.label);
  final String value;
  final String label;

  static CertStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => CertStatus.tbc);
}

// ── Model ─────────────────────────────────────────────────────────────────

@immutable
class CertificateModel {
  const CertificateModel({
    required this.certId,
    required this.caseId,
    required this.certType,
    this.vesselId,
    this.certName,
    this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    this.annualSurveyDate,
    this.certNumber,
    this.status = CertStatus.tbc,
    this.sourceDocId,
    this.extractedAuto = false,
    this.notes,
    this.createdAt,
  });

  final String certId;
  final String caseId;
  final CertType certType;
  final String? vesselId;
  final String? certName;
  final String? issuingAuthority;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? annualSurveyDate;
  final String? certNumber;
  final CertStatus status;
  final String? sourceDocId;
  final bool extractedAuto;
  final String? notes;
  final DateTime? createdAt;

  /// Is this cert expiring within 90 days?
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 90;
  }

  /// Days until expiry (negative = already expired)
  int? get daysToExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Status derived from dates if not manually set
  CertStatus get effectiveStatus {
    if (status != CertStatus.tbc) return status;
    if (expiryDate == null) return CertStatus.tbc;
    if (expiryDate!.isBefore(DateTime.now())) return CertStatus.expired;
    return CertStatus.valid;
  }

  factory CertificateModel.fromJson(Map<String, dynamic> j) =>
      CertificateModel(
        certId:          j['cert_id'] as String,
        caseId:          j['case_id'] as String,
        certType:        CertType.fromValue(
            j['cert_type'] as String? ?? 'other'),
        vesselId:        j['vessel_id'] as String?,
        certName:        j['cert_name'] as String?,
        issuingAuthority: j['issuing_authority'] as String?,
        issueDate:       j['issue_date'] != null
            ? DateTime.tryParse(j['issue_date'] as String)
            : null,
        expiryDate:      j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'] as String)
            : null,
        annualSurveyDate: j['annual_survey_date'] != null
            ? DateTime.tryParse(j['annual_survey_date'] as String)
            : null,
        certNumber:      j['cert_number'] as String?,
        status:          CertStatus.fromValue(
            j['status'] as String? ?? 'tbc'),
        sourceDocId:     j['source_doc_id'] as String?,
        extractedAuto:   j['extracted_auto'] as bool? ?? false,
        notes:           j['notes'] as String?,
        createdAt:       j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':  caseId,
        'cert_type': certType.value,
        if (vesselId != null)        'vessel_id':        vesselId,
        if (certName != null)        'cert_name':        certName,
        if (issuingAuthority != null)'issuing_authority': issuingAuthority,
        if (issueDate != null)
          'issue_date': issueDate!.toIso8601String().split('T').first,
        if (expiryDate != null)
          'expiry_date': expiryDate!.toIso8601String().split('T').first,
        if (annualSurveyDate != null)
          'annual_survey_date':
              annualSurveyDate!.toIso8601String().split('T').first,
        if (certNumber != null)      'cert_number':      certNumber,
        'status':                    status.value,
        if (sourceDocId != null)     'source_doc_id':    sourceDocId,
        'extracted_auto':            extractedAuto,
        if (notes != null)           'notes':            notes,
      };

  CertificateModel copyWith({
    CertType? certType,
    String? certName,
    String? issuingAuthority,
    DateTime? issueDate,
    DateTime? expiryDate,
    DateTime? annualSurveyDate,
    String? certNumber,
    CertStatus? status,
    String? notes,
  }) =>
      CertificateModel(
        certId:          certId,
        caseId:          caseId,
        certType:        certType        ?? this.certType,
        vesselId:        vesselId,
        certName:        certName        ?? this.certName,
        issuingAuthority: issuingAuthority ?? this.issuingAuthority,
        issueDate:       issueDate       ?? this.issueDate,
        expiryDate:      expiryDate      ?? this.expiryDate,
        annualSurveyDate: annualSurveyDate ?? this.annualSurveyDate,
        certNumber:      certNumber      ?? this.certNumber,
        status:          status          ?? this.status,
        sourceDocId:     sourceDocId,
        extractedAuto:   extractedAuto,
        notes:           notes           ?? this.notes,
        createdAt:       createdAt,
      );
}

// ── Provider ───────────────────────────────────────────────────────────────

final certificatesProvider = AsyncNotifierProviderFamily<
    CertificatesNotifier, List<CertificateModel>, String>(
  CertificatesNotifier.new,
);

class CertificatesNotifier
    extends FamilyAsyncNotifier<List<CertificateModel>, String> {
  @override
  Future<List<CertificateModel>> build(String caseId) => _fetch(caseId);

  Future<List<CertificateModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('certificates')
        .select()
        .eq('case_id', caseId)
        .order('cert_type');
    return (data as List).map((e) => CertificateModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CertificateModel> addCertificate(CertificateModel cert) async {
    final data = await SupabaseService.client
        .from('certificates')
        .insert(cert.toInsertJson())
        .select()
        .single();

    final created = CertificateModel.fromJson(data);
    final current = state.value ?? [];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> updateCertificate(CertificateModel cert) async {
    await SupabaseService.client
        .from('certificates')
        .update(cert.toInsertJson())
        .eq('cert_id', cert.certId);

    final current = state.value ?? [];
    state = AsyncData(current
        .map((c) => c.certId == cert.certId ? cert : c)
        .toList());
  }

  Future<void> deleteCertificate(String certId) async {
    await SupabaseService.client
        .from('certificates')
        .delete()
        .eq('cert_id', certId);

    final current = state.value ?? [];
    state = AsyncData(
        current.where((c) => c.certId != certId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
