// lib/core/widgets/debug_feedback_button.dart
//
// Debug-build-only floating button for reporting bugs/improvements while
// testing, without breaking flow to go write it up separately. Uses the
// `feedback` package's built-in screenshot + draw-to-annotate UI, then
// uploads straight into Supabase (debug_feedback table + 'debug-feedback'
// storage bucket) so it's reviewable without the surveyor having to
// describe it in a chat message from memory later.
//
// Only rendered when kDebugMode is true (see main.dart) — never present in
// release builds.

import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:feedback/feedback.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../api/supabase_client.dart';
import '../config/app_router.dart';
import '../../shared/theme/app_theme.dart';

/// Wraps the whole app in main.dart so the bug button can capture a still of
/// the exact frame it's tapped on (before any transient error snackbar fades).
final GlobalKey debugFeedbackBoundaryKey = GlobalKey();

/// The frozen still shown *over* the app while the feedback UI is open, so the
/// surveyor annotates a frozen frame — not the live screen, on which a
/// transient error has already vanished (16 July 2026). main.dart paints this
/// as a full-screen overlay in the MaterialApp builder when non-null.
final ValueNotifier<Uint8List?> debugFeedbackFrozenFrame =
    ValueNotifier<Uint8List?>(null);

class DebugFeedbackButton extends StatefulWidget {
  const DebugFeedbackButton({super.key});

  @override
  State<DebugFeedbackButton> createState() => _DebugFeedbackButtonState();
}

class _DebugFeedbackButtonState extends State<DebugFeedbackButton> {
  // Null until dragged — bottom-right default is computed per-build from
  // the current screen size (a fixed top-left offset landed on top of real
  // page content, e.g. the first field on Account, on first render).
  Offset? _offset;
  bool _submitting = false;

  // The frame captured the instant the button is tapped — uploaded alongside
  // the feedback package's (later, annotated) screenshot so a transient error
  // that has since vanished is still on record.
  Uint8List? _instantShot;

  Future<Uint8List?> _captureInstant() async {
    try {
      final ctx = debugFeedbackBoundaryKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final dpr = View.of(ctx).devicePixelRatio.clamp(1.0, 2.0);
      final image = await boundary.toImage(pixelRatio: dpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // Uses the top-level `appRouter` singleton directly rather than
  // GoRouter.of(context) — this widget lives in MaterialApp.router's
  // `builder`, whose context sits *outside* the Router/Navigator go_router
  // creates, so GoRouter.of(context) throws there every time (silently
  // swallowed by the try/catch below, which is why route always came back
  // null in testing).
  String? _currentRoute() {
    try {
      return appRouter.routerDelegate.currentConfiguration.uri.toString();
    } catch (_) {
      return null;
    }
  }

  String? _extractCaseId(String? route) {
    if (route == null) return null;
    final match = RegExp(
            r'/cases/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
        .firstMatch(route);
    return match?.group(1);
  }

  Future<void> _submit(BuildContext context, fb.UserFeedback feedback) async {
    setState(() => _submitting = true);
    try {
      final route = _currentRoute();
      final fileName =
          'fb_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(feedback)}.png';
      await SupabaseService.client.storage
          .from('debug-feedback')
          .uploadBinary(fileName, feedback.screenshot,
              fileOptions: const FileOptions(contentType: 'image/png'));

      // The tap-time still (captured before the feedback UI opened) — uploaded
      // as a second image so a since-vanished error is preserved.
      String? instantFileName;
      final instant = _instantShot;
      if (instant != null) {
        instantFileName = 'fb_${DateTime.now().millisecondsSinceEpoch}_'
            '${identityHashCode(feedback)}_instant.png';
        await SupabaseService.client.storage
            .from('debug-feedback')
            .uploadBinary(instantFileName, instant,
                fileOptions: const FileOptions(contentType: 'image/png'));
      }

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // Best-effort only.
      }

      await SupabaseService.client.from('debug_feedback').insert({
        'case_id': _extractCaseId(route),
        'created_by': SupabaseService.currentUser?.id,
        'note': feedback.text,
        'screenshot_path': fileName,
        if (instantFileName != null) 'screenshot_instant_path': instantFileName,
        'route': route,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'app_version': appVersion,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback logged'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback failed to upload: $e')),
        );
      }
    } finally {
      _instantShot = null;
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final offset = _offset ?? Offset(size.width - 60, size.height - 160);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Draggable(
        feedback: _button(dragging: true),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (details) {
          final box = context.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(details.offset) ?? details.offset;
          setState(() {
            _offset = Offset(
              local.dx.clamp(0, size.width - 44),
              local.dy.clamp(0, size.height - 44),
            );
          });
        },
        child: GestureDetector(
          onTap: _submitting
              ? null
              : () async {
                  // Freeze the frame NOW, before the feedback UI opens, so the
                  // annotation canvas shows a still (with any transient error)
                  // rather than the live screen. main.dart overlays it.
                  _instantShot = await _captureInstant();
                  debugFeedbackFrozenFrame.value = _instantShot;
                  if (!context.mounted) {
                    debugFeedbackFrozenFrame.value = null;
                    return;
                  }
                  // Clear the overlay whenever the feedback session ends —
                  // submit AND cancel (the show() callback only fires on
                  // submit, so listen to the controller's visibility).
                  final controller = fb.BetterFeedback.of(context);
                  void onVisibility() {
                    if (!controller.isVisible) {
                      debugFeedbackFrozenFrame.value = null;
                      controller.removeListener(onVisibility);
                    }
                  }
                  controller.addListener(onVisibility);
                  controller.show((f) => _submit(context, f));
                },
          child: _button(dragging: false),
        ),
      ),
    );
  }

  Widget _button({required bool dragging}) => Material(
        elevation: dragging ? 6 : 3,
        shape: const CircleBorder(),
        color: Colors.black.withValues(alpha: 0.65),
        child: SizedBox(
          width: 44,
          height: 44,
          child: _submitting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bug_report_outlined,
                  color: Colors.white, size: 22),
        ),
      );
}
