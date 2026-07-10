import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/vessel/providers/certificates_provider.dart';

class FakeCertificatesNotifier extends CertificatesNotifier {
  FakeCertificatesNotifier(this._seed);
  final List<CertificateModel> _seed;
  int _counter = 0;

  @override
  Future<List<CertificateModel>> build(String caseId) async => _seed;

  @override
  Future<CertificateModel> addCertificate(CertificateModel cert) async {
    final withId = CertificateModel(
      certId: 'fake-cert-${++_counter}',
      caseId: cert.caseId,
      certType: cert.certType,
      vesselId: cert.vesselId,
      certName: cert.certName,
      issuingAuthority: cert.issuingAuthority,
      issueDate: cert.issueDate,
      expiryDate: cert.expiryDate,
      annualSurveyDate: cert.annualSurveyDate,
      certNumber: cert.certNumber,
      status: cert.status,
      notes: cert.notes,
    );
    state = AsyncData([...state.value ?? [], withId]);
    return withId;
  }

  @override
  Future<void> updateCertificate(CertificateModel cert) async {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((c) => c.certId == cert.certId ? cert : c).toList(),
    );
  }

  @override
  Future<void> deleteCertificate(String certId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((c) => c.certId != certId).toList());
  }

  @override
  Future<void> refresh() async {}
}
