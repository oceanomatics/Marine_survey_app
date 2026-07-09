// test/support/pump_with_router.dart
//
// Since Cluster A's app-wide back-navigation fix (lib/shared/widgets/
// back_app_bar.dart, 9 July 2026), every screen using BackAppBar calls
// `context.canPop()` / `GoRouterState.of(context)` during build — which
// throws "No GoRouter found in context" under a plain `MaterialApp(home:
// ...)` widget test. Any screen-level widget test now needs a real
// (minimal) GoRouter ancestor rather than bare MaterialApp. This helper
// wraps [child] in a single-route GoRouter + MaterialApp.router shell so
// widget tests can pump BackAppBar-using screens without wiring a full
// router per test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps [child] wrapped in [ProviderScope] (with [overrides]) and a
/// single-route [GoRouter] at [location], so screens built with
/// [BackAppBar] don't crash on `context.canPop()`/`GoRouterState.of()`.
Future<void> pumpWithRouter(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  String location = '/test',
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: location, builder: (_, __) => child),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
