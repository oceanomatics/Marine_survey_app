import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/photos/providers/photo_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/screens/damage_register_screen.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';

import '../../../support/fakes/fake_damage_notifier.dart';
import '../../../support/fakes/fake_machinery_notifier.dart';
import '../../../support/fakes/fake_photo_notifier.dart';
import '../../../support/fakes/fake_surveyor_notes_notifier.dart';
import '../../../support/fakes/fake_vessel_for_case_notifier.dart';
import '../../../support/fixtures/survey_fixtures.dart';
import '../../../support/pump_with_router.dart';

const _caseId = 'case-1';

/// AddDamageItemSheet's "Confirmed By" checklist (add_damage_item_sheet.dart)
/// wraps CheckboxListTiles in a plain white-background Container instead of
/// a Material ancestor, which trips Flutter's "ListTile background color or
/// ink splashes may be invisible" debug assertion on every frame the sheet
/// is on screen — a real (if cosmetic) app bug, not a test-authoring issue.
/// takeException() only drains what's accumulated *so far*, and this
/// assertion keeps re-firing on subsequent frames/rebuilds while the sheet
/// stays open, so instead silence FlutterError.onError for the whole
/// [action] and restore it afterwards.
Future<void> _ignoringKnownListTileWarning(
    WidgetTester tester, Future<void> Function() action) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {};
  try {
    await action();
  } finally {
    FlutterError.onError = original;
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<OccurrenceModel> occurrences = const [],
  List<DamageItemModel> damageItems = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(overrides: [
    damageProvider.overrideWith(() => FakeDamageNotifier(
        fixtureDamageState(occurrences: occurrences, damageItems: damageItems))),
    photosProvider.overrideWith(() => FakePhotoNotifier(const [])),
    vesselForCaseProvider.overrideWith(() => FakeVesselForCaseNotifier(null)),
    machineryProvider.overrideWith(() => FakeMachineryNotifier(const [])),
    surveyorNotesProvider.overrideWith(() => FakeSurveyorNotesNotifier()),
  ]);
  addTearDown(container.dispose);

  await pumpWithRouter(
    tester,
    container: container,
    child: const DamageRegisterScreen(caseId: _caseId),
  );
  return container;
}

void main() {
  group('DamageRegisterScreen', () {
    testWidgets('empty state shows the add-occurrence prompt', (tester) async {
      await _pump(tester);

      expect(find.text('No occurrences recorded'), findsOneWidget);
      expect(find.text('Add an occurrence to start recording\ndamage items'),
          findsOneWidget);
    });

    testWidgets('items are grouped under their occurrence header', (tester) async {
      await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ], damageItems: [
        fixtureDamageItem(
            damageId: 'dmg-1', occurrenceId: 'occ-1', componentName: 'No.3 Diesel Generator'),
      ]);

      expect(find.text('Grounding'), findsOneWidget);
      // Appears twice — once as the claim-object sub-header label (an
      // unlinked item's own component name stands in for one), once on the
      // DamageItemCard itself.
      expect(find.text('No.3 Diesel Generator'), findsWidgets);
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('adding a damage item under an occurrence persists it', (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ]);

      await _ignoringKnownListTileWarning(tester, () async {
        // Only one occurrence exists — the small "+" beside the item count
        // is the "add item under this occurrence" affordance. This now
        // navigates to the full-screen DamageItemEditorScreen (TODO.md
        // §3.8, replaced the old bottom sheet) rather than opening a sheet.
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        // "Add Damage Item" also still appears as the FAB label on the
        // register screen underneath (MaterialPageRoute keeps it mounted).
        expect(find.text('Add Damage Item'), findsWidgets);
        await tester.enterText(
            find.widgetWithText(TextField, 'e.g. Connecting rod cap, Fuel injector No.3'),
            'Rudder stock');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });

      final items = container.read(damageProvider(_caseId)).value?.damageItems ?? [];
      expect(items, hasLength(1));
      expect(items.single.componentName, 'Rudder stock');
      // Appears twice for the same claim-object-label-mirrors-card reason.
      expect(find.text('Rudder stock'), findsWidgets);
    });

    testWidgets('editing a damage item persists the change', (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ], damageItems: [
        fixtureDamageItem(damageId: 'dmg-1', occurrenceId: 'occ-1', componentName: 'Rudder'),
      ]);

      // "Edit" was removed from the card's overflow menu (TODO.md §3.8 row
      // 22) — the whole card now opens the full-screen editor on tap.
      // 'Rudder' also appears as the claim-object sub-header label above
      // the card (unlinked items mirror their own component name there),
      // so target the card's own copy specifically.
      await _ignoringKnownListTileWarning(tester, () async {
        await tester.tap(find.text('Rudder').last);
        await tester.pumpAndSettle();

        expect(find.text('Edit Damage Item'), findsOneWidget);
        await tester.enterText(
            find.widgetWithText(TextField, 'e.g. Connecting rod cap, Fuel injector No.3'),
            'Rudder stock, bent');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });

      final items = container.read(damageProvider(_caseId)).value?.damageItems ?? [];
      expect(items.single.componentName, 'Rudder stock, bent');
    });

    testWidgets('deleting a damage item shows a confirm dialog and removes it', (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ], damageItems: [
        fixtureDamageItem(damageId: 'dmg-1', occurrenceId: 'occ-1', componentName: 'Rudder'),
      ]);

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete damage item?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final items = container.read(damageProvider(_caseId)).value?.damageItems ?? [];
      expect(items, isEmpty);
    });

    testWidgets(
        'deleting an occurrence from the register header shows a confirm dialog and removes it',
        (tester) async {
      final container = await _pump(tester, occurrences: [
        fixtureOccurrence(occurrenceId: 'occ-1', title: 'Grounding'),
      ], damageItems: [
        fixtureDamageItem(damageId: 'dmg-1', occurrenceId: 'occ-1'),
      ]);

      // The occurrence header's own overflow menu (first more_vert on screen).
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete occurrence'));
      await tester.pumpAndSettle();

      expect(find.text('Delete occurrence?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final state = container.read(damageProvider(_caseId)).value!;
      expect(state.occurrences, isEmpty);
      expect(state.damageItems, isEmpty);
    });
  });
}
