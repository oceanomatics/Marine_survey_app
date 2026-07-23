import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_certificate_provider.dart';

/// Widget-test double for the C&S certificate register.
class FakeCsCertificateNotifier extends CsCertificateNotifier {
  FakeCsCertificateNotifier([this._seed = const []]);
  final List<CsCertificateModel> _seed;
  int _counter = 0;

  @override
  Future<List<CsCertificateModel>> build(String caseId) async => _seed;

  @override
  Future<CsCertificateModel> add({
    required String certType,
    DateTime? issuedDate,
    String? issuedPlace,
    DateTime? expiryDate,
    String? status,
  }) async {
    final c = CsCertificateModel(
      id: 'fake-cert-${++_counter}',
      caseId: arg,
      certType: certType,
      issuedDate: issuedDate,
      issuedPlace: issuedPlace,
      expiryDate: expiryDate,
      status: status,
    );
    state = AsyncData([...(state.value ?? []), c]);
    return c;
  }

  @override
  Future<void> setStatus(String id, String status) async {}

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((c) => c.id != id).toList());
  }
}
