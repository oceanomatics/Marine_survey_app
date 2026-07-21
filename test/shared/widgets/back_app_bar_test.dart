// test/shared/widgets/back_app_bar_test.dart
//
// Regression test for the §9 walkthrough "back button loops me around" bug:
// a screen using BackAppBar that is reached via a raw Navigator.push
// (MaterialPageRoute) rather than go_router. go_router's context.canPop() is
// false for such a route, so BackAppBar used to fall through to
// context.go(fallback) — navigating go_router underneath while leaving the
// pushed route on top. The fix pops the raw Navigator route in that case.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marine_survey_app/shared/widgets/back_app_bar.dart';

class _PushedScreen extends StatelessWidget {
  const _PushedScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: BackAppBar(title: Text('Pushed viewer')),
        body: Center(child: Text('PUSHED_BODY')),
      );
}

void main() {
  testWidgets(
      'BackAppBar back arrow pops a raw Navigator.push route instead of looping',
      (tester) async {
    // Home sits at a nested location so BackAppBar's derived fallback is
    // non-null (that non-null fallback is exactly what the old code used to
    // wrongly navigate to). The AiTaskIndicator inside BackAppBar needs a
    // ProviderScope; ai_tasks_provider tolerates the bare scope here.
    final router = GoRouter(
      initialLocation: '/cases/abc',
      routes: [
        GoRoute(
          path: '/cases/abc',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _PushedScreen()),
                ),
                child: const Text('OPEN_VIEWER'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/cases',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('CASES_LIST'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    // Open the raw-pushed viewer.
    await tester.tap(find.text('OPEN_VIEWER'));
    await tester.pumpAndSettle();
    expect(find.text('PUSHED_BODY'), findsOneWidget);

    // Tap the BackAppBar back arrow.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Should be back on the pusher screen — NOT looped, NOT dumped to /cases.
    expect(find.text('PUSHED_BODY'), findsNothing);
    expect(find.text('OPEN_VIEWER'), findsOneWidget);
    expect(find.text('CASES_LIST'), findsNothing);
  });
}
