// test/features/settings/screens/usage_screen_test.dart
//
// UsageScreen has no Riverpod provider seam at all — it calls
// SupabaseService.client directly inside a plain StatefulWidget's _load().
// In a widget test (no real Supabase backend) that throws, and _load()'s
// own catch-all turns it into the screen's real error state rather than
// crashing — so what's actually verifiable here, honestly, is "the screen
// loads and degrades gracefully", not "real usage data renders". Faking
// real data would need a Supabase client double, out of scope for the
// lightweight fake-notifier pattern used everywhere else in this suite.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:marine_survey_app/features/settings/screens/usage_screen.dart';

void main() {
  testWidgets('loads without crashing and shows the API Usage title',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageScreen()));
    await tester.pump();

    expect(find.text('API Usage'), findsOneWidget);
  });

  testWidgets('degrades to an error state with a Retry action when the backend is unreachable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry attempts to reload without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Still on the error state (backend is still unreachable) — the point
    // of this test is that retrying doesn't throw or leave the screen stuck.
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });
}
