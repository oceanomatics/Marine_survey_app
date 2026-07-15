// test/features/survey/screens/nature_of_repairs_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/survey/screens/nature_of_repairs_screen.dart';
import 'package:marine_survey_app/features/survey/providers/nature_of_repairs_provider.dart';

import '../../../support/fakes/fake_nature_of_repairs_notifier.dart';

const _caseId = 'case-1';

Future<FakeNatureOfRepairsNotifier> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = FakeNatureOfRepairsNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [natureOfRepairsProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: NatureOfRepairsScreen(caseId: _caseId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('loads and shows all 5 question cards', (tester) async {
    await _pump(tester);

    expect(find.text('Does the repair require drydocking of the vessel?'),
        findsOneWidget);
    expect(find.text("Has the Assured already formulated a plan for the repairs?"),
        findsOneWidget);
    expect(find.text('Are any further inspections planned prior to the repairs?'),
        findsOneWidget);
    expect(find.text('Are there parts with a long lead time?'), findsOneWidget);
    expect(find.text('Are there any foreseeable difficulties?'), findsOneWidget);
  });

  testWidgets('toggling a question reveals its comment field and saves the toggle',
      (tester) async {
    final fake = await _pump(tester);

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(fake.state.value!.drydockingRequired, isTrue);
  });

  testWidgets('typing in a comment field saves after the debounce', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Drydock at Sembcorp');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(fake.state.value!.drydockingComment, 'Drydock at Sembcorp');
  });

  testWidgets('adding a repair sequence step appends it to the bullet list',
      (tester) async {
    final fake = await _pump(tester);

    expect(find.text('No items added. Tap Add to record an anticipated step.'),
        findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Temporary weld repair');
    // The header's own "+ Add" trigger is still in the tree behind the
    // dialog barrier, so `find.text('Add')` is ambiguous here — target the
    // dialog's confirm button specifically.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Temporary weld repair'), findsOneWidget);
    expect(fake.state.value!.sequenceItems, hasLength(1));
  });
}
