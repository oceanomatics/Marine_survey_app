// test/features/settings/screens/account_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marine_survey_app/features/settings/screens/account_screen.dart';
import 'package:marine_survey_app/features/settings/providers/account_provider.dart';
import 'package:marine_survey_app/features/settings/providers/organisations_provider.dart';

import '../../../support/fakes/fake_account_notifier.dart';
import '../../../support/fakes/fake_organisations_notifier.dart';

Future<void> _pump(WidgetTester tester, {AccountState account = const AccountState()}) async {
  // Connectivity tab is a long ListView (API Keys/Cloud Storage/FX Rates/
  // Speech/External Accounts) — a default test surface only renders items
  // within the viewport, so a tall surface is needed for content near the
  // bottom to exist in the widget tree at all (same gotcha documented for
  // the Report Builder Editor tab).
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountProvider.overrideWith(() => FakeAccountNotifier(account)),
        organisationsProvider.overrideWith(() => FakeOrganisationsNotifier()),
      ],
      child: const MaterialApp(home: AccountScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows three tabs: Surveyor, Organisations, Connectivity',
      (tester) async {
    await _pump(tester);

    expect(find.text('Surveyor'), findsOneWidget);
    expect(find.text('Organisations'), findsOneWidget);
    expect(find.text('Connectivity'), findsOneWidget);
  });

  testWidgets('Surveyor tab is shown by default with the profile card and app lock',
      (tester) async {
    await _pump(tester, account: const AccountState(name: 'Pierre-Louis Constant'));

    expect(find.text('SURVEYOR PROFILE'), findsOneWidget);
    expect(find.text('APP LOCK'), findsOneWidget);
    expect(find.text('Require biometric unlock'), findsOneWidget);
    // Connectivity-only content must not be visible yet.
    expect(find.text('API KEYS'), findsNothing);
  });

  testWidgets('switching to the Organisations tab shows the FAB and hides the SaveBar',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Organisations'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New Organisation'), findsOneWidget);
  });

  testWidgets('switching to the Connectivity tab shows API Keys, Cloud Storage, FX Rates, Speech and External Accounts',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Connectivity'));
    await tester.pumpAndSettle();

    expect(find.text('API KEYS'), findsOneWidget);
    expect(find.text('CLOUD STORAGE'), findsOneWidget);
    expect(find.text('FX RATES'), findsOneWidget);
    expect(find.text('SPEECH & TRANSCRIPTION'), findsOneWidget);
    expect(find.text('EXTERNAL ACCOUNTS'), findsOneWidget);
    // No FAB on this tab.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Connectivity tab shows Active badge when a key is configured, Missing otherwise',
      (tester) async {
    await _pump(tester, account: const AccountState(anthropicApiKey: 'sk-ant-real-key'));

    await tester.tap(find.text('Connectivity'));
    await tester.pumpAndSettle();

    // Anthropic is the only one seeded — OpenAI, Google, Drive Base Folder
    // and the FX Rates key all share the same _ApiKeyEditCard Active/Missing
    // badge, so they all read "Missing" here too.
    expect(find.text('Active'), findsOneWidget); // Anthropic
    expect(find.text('Missing'), findsNWidgets(4));
  });

  testWidgets('empty external accounts shows the empty-state message',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Connectivity'));
    await tester.pumpAndSettle();

    expect(
      find.text('No external accounts saved yet. Add Equasis or other site credentials here.'),
      findsOneWidget,
    );
  });

  testWidgets('editing the profile name shows the save bar', (tester) async {
    await _pump(tester, account: const AccountState(name: 'Original Name'));

    await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'New Name');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsOneWidget);
  });
}
