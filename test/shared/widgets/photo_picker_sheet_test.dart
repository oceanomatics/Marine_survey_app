// test/shared/widgets/photo_picker_sheet_test.dart
//
// Render-only coverage for the "which import source" sheet — the 4 import
// options (Photo Library/Files/Import from Folder/Google Drive) were flagged
// as awkward/confusing (14 July 2026 walkthrough §11); this locks in that
// each tile names its actual source so they stay distinguishable. Tapping a
// tile isn't tested here since resolving bytes hits file_picker/image_picker
// platform channels not available in a plain widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/shared/widgets/photo_picker_sheet.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<PhotoPickSource>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => const PhotoPickerSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all 5 sources with distinguishable subtitles', (tester) async {
    await _pump(tester);

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photo Library'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Import from Folder'), findsOneWidget);
    expect(find.text('Google Drive'), findsOneWidget);

    // Each subtitle names its actual source app/location rather than a
    // generic description that could apply to more than one tile.
    expect(find.textContaining("This device's own Photos app"), findsOneWidget);
    expect(find.textContaining('The system Files picker'), findsOneWidget);
    expect(find.textContaining('A folder on this device'), findsOneWidget);
    expect(find.textContaining("this app's Google Drive integration"),
        findsOneWidget);
  });
}
