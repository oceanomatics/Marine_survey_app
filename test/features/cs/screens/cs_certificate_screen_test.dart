import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/cs/models/cs_models.dart';
import 'package:marine_survey_app/features/cs/providers/cs_certificate_provider.dart';
import 'package:marine_survey_app/features/cs/screens/cs_certificate_screen.dart';

import '../../../support/fakes/fake_cs_certificate_notifier.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CsCertificateModel> certs = const [],
}) async {
  final container = ProviderContainer(overrides: [
    csCertificateProvider.overrideWith(() => FakeCsCertificateNotifier(certs)),
  ]);
  addTearDown(container.dispose);
  await pumpWithRouter(
    tester,
    container: container,
    child: const CsCertificateScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('CsCertificateScreen', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.text('No certificates recorded'), findsOneWidget);
    });

    testWidgets('lists a cert with an Expired badge for a past expiry',
        (tester) async {
      await _pump(tester, certs: [
        CsCertificateModel(
          id: '1',
          caseId: _caseId,
          certType: 'Safety Equipment Certificate',
          expiryDate: DateTime(2025, 1, 1),
        ),
      ]);
      expect(find.text('Safety Equipment Certificate'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('valid badge for a future expiry', (tester) async {
      await _pump(tester, certs: [
        CsCertificateModel(
          id: '1',
          caseId: _caseId,
          certType: 'Class Certificate',
          expiryDate: DateTime(2030, 1, 1),
        ),
      ]);
      expect(find.text('Valid'), findsOneWidget);
    });

    testWidgets('delete removes the certificate', (tester) async {
      final container = await _pump(tester, certs: const [
        CsCertificateModel(id: '1', caseId: _caseId, certType: 'X'),
      ]);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(container.read(csCertificateProvider(_caseId)).value, isEmpty);
    });
  });
}
