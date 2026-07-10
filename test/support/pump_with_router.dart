// test/support/pump_with_router.dart
//
// A real single-route GoRouter + MaterialApp.router wrapper for widget
// tests. Since Cluster A's app-wide back-navigation fix (lib/shared/widgets/
// back_app_bar.dart, 9 July 2026), every screen using BackAppBar calls
// `context.canPop()` / `GoRouterState.of(context)` during build — which
// throws "No GoRouter found in context" under a plain `MaterialApp(home:
// ...)` widget test. Several screens also call GoRouter.of(context) directly
// (e.g. the Vessel Particulars Equasis "no credentials" snackbar links to
// /account), so a bare MaterialApp is not enough for those either. Use this
// helper for any screen test that needs real navigation context.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps [child] as the sole route ('/') of a GoRouter-backed MaterialApp,
/// wired to [container]. Extra [routes] (e.g. '/account') can be supplied
/// for screens that navigate elsewhere — each extra route builder can be as
/// simple as an empty Scaffold since tests typically only assert that
/// navigation was *attempted*, not what the destination renders.
Future<void> pumpWithRouter(
  WidgetTester tester, {
  required ProviderContainer container,
  required Widget child,
  List<RouteBase> extraRoutes = const [],
}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (context, state) => child),
    ...extraRoutes,
  ]);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// A trivial placeholder screen for extra routes a test doesn't care about
/// the content of — just that navigating there doesn't crash.
GoRoute placeholderRoute(String path) =>
    GoRoute(path: path, builder: (context, state) => const SizedBox());
