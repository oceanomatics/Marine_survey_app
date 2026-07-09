// lib/shared/widgets/back_app_bar.dart
//
// Drop-in replacement for AppBar that reliably shows a back/up affordance.
// Flutter's AppBar only auto-shows a back button when Navigator.canPop() is
// true, but this app navigates almost entirely via go_router's context.go()
// (37 call sites vs. 4 context.push()), which *replaces* the current route
// rather than pushing — so Navigator.canPop() is false on nearly every
// screen and the built-in back button silently never appears. Confirmed as
// the root cause of the "no back arrow anywhere" complaint, 8 July 2026.
//
// Usage: same named params as AppBar (only the ones actually used in this
// app are mirrored). Pass [fallbackRoute] for screens reached via go() with
// a known parent (e.g. '/cases/$caseId') so there's still a way back when
// there's nothing to pop.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BackAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.fallbackRoute,
    this.automaticallyImplyLeading = true,
    this.titleSpacing,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? titleSpacing;

  /// Route to fall back to when there's nothing on the navigation stack to
  /// pop (the common case with go_router's context.go()). Typically the
  /// parent hub screen, e.g. '/cases/$caseId'.
  final String? fallbackRoute;

  /// Set false to suppress the back button entirely (e.g. a true top-level
  /// screen with nowhere to go back to).
  final bool automaticallyImplyLeading;

  /// When [fallbackRoute] isn't given and there's nothing to pop, derive a
  /// sensible "up" target by stripping the last path segment off the
  /// current location — e.g. '/cases/abc/vessel' -> '/cases/abc'. Covers
  /// the overwhelming majority of screens in this app without per-screen
  /// configuration, since almost everything is nested under /cases/:id/...
  /// and reached via context.go() (which leaves nothing to pop).
  String? _derivedFallback(BuildContext context) {
    if (fallbackRoute != null) return fallbackRoute;
    final path = GoRouterState.of(context).uri.path;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 1) return null;
    return '/${segments.sublist(0, segments.length - 1).join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    // Widget tests pump screens under a plain MaterialApp (no GoRouter
    // ancestor) — context.canPop()/GoRouterState.of() both throw in that
    // case. Fall back to plain Navigator.canPop() and no derived-fallback
    // route, which is enough for a test harness to render without crashing;
    // every real route in the app is under GoRouter via app_router.dart.
    final hasGoRouter = GoRouter.maybeOf(context) != null;
    final canPop = hasGoRouter ? context.canPop() : Navigator.canPop(context);
    final fallback =
        (canPop || !hasGoRouter) ? null : _derivedFallback(context);
    final showBack = automaticallyImplyLeading && (canPop || fallback != null);

    // Root cause of the "light/barely readable title text" bug (§3.12 item
    // 38, also latent on any other screen overriding backgroundColor away
    // from the navy default — e.g. vessel_compliance_screen.dart,
    // invoice_detail_screen.dart): the app-wide AppBarTheme in app_theme.dart
    // hardcodes `titleTextStyle: TextStyle(color: Colors.white)` for the
    // default navy bar. Flutter's AppBar resolves its title style as
    // `widget.titleTextStyle ?? appBarTheme.titleTextStyle ?? defaults...`
    // (see flutter/material/app_bar.dart) — `foregroundColor` is only ever
    // used as a fallback *inside* that last `defaults` branch, so it never
    // gets a chance to override a theme-set titleTextStyle. Passing
    // `foregroundColor` here silently did nothing to the title colour.
    // Fix: when a caller explicitly overrides `foregroundColor`, also derive
    // an explicit `titleTextStyle` from it (keeping the theme's font/size/
    // weight) so it actually wins over the theme default.
    final themeTitleStyle = Theme.of(context).appBarTheme.titleTextStyle;
    final resolvedTitleTextStyle = foregroundColor != null
        ? (themeTitleStyle ?? const TextStyle()).copyWith(color: foregroundColor)
        : null;

    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      titleTextStyle: resolvedTitleTextStyle,
      elevation: elevation,
      titleSpacing: titleSpacing,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                if (canPop) {
                  hasGoRouter ? context.pop() : Navigator.pop(context);
                } else if (fallback != null) {
                  context.go(fallback);
                }
              },
            )
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}
