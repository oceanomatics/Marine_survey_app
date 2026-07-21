// lib/main.dart

import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/supabase_client.dart';
import 'core/config/app_router.dart';
import 'core/widgets/debug_feedback_button.dart';
import 'core/widgets/import_review_banner.dart';
import 'features/interviews/widgets/interview_recording_overlay.dart';
import 'features/settings/providers/account_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/biometric_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error-widget: when a widget's build() throws (e.g. a transient
  // network DioException surfacing mid-rebuild), Flutter's default red
  // ErrorWidget renders the full exception on one unwrapped line — placed in a
  // Row/Flex that becomes a "RIGHT OVERFLOWED BY 99468 PIXELS" red screen
  // (bug report, 21 July 2026: "after taking a picture"). Replace it with a
  // contained, wrapping, size-bounded message so a single failed build can
  // never blow out the layout — the details stay visible but constrained.
  ErrorWidget.builder = (details) => _SafeErrorWidget(details: details);

  // Initialise Supabase
  await SupabaseService.initialize();

  // Preload the account profile (incl. AI/service API keys) before showing
  // any UI, so AppConfig has the DB-stored keys warm before the first
  // AI call — see AccountNotifier._load().
  final container = ProviderContainer();
  try {
    await container.read(accountProvider.future);
  } catch (_) {
    // Offline or signed out — AppConfig keeps its --dart-define fallback.
  }

  // Riverpod scope wraps the entire app, reusing the preloaded container so
  // accountProvider isn't reloaded from scratch. BetterFeedback wraps that
  // in turn, debug builds only — it owns the screenshot + draw-to-annotate
  // overlay the DebugFeedbackButton triggers (see debug_feedback_button.dart).
  // Never present in release builds: kDebugMode is compiled out entirely.
  final app = UncontrolledProviderScope(
    container: container,
    child: const MarineSurveyApp(),
  );
  // Biometric app-lock (14 July 2026 walkthrough) wraps everything —
  // checked once at cold start and again on every resume from background;
  // a no-op wrapper when the surveyor hasn't turned the setting on.
  runApp(BiometricLockGate(
      child: kDebugMode
          ? BetterFeedback(
              // Default FeedbackThemeData renders a dark sheet with near-black
              // text — barely readable (bug report, 16 July 2026). Force a
              // light sheet with dark text for both the prompt and the typed
              // note, matching the app's light surface.
              theme: FeedbackThemeData(
                background: Colors.grey.shade600,
                feedbackSheetColor: AppColors.surface,
                activeFeedbackModeColor: AppColors.navy,
                bottomSheetDescriptionStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                bottomSheetTextInputStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              // Keyed boundary so the bug button can grab a still of the exact
              // frame the instant it's tapped — the feedback package captures
              // a beat later, by which point a transient error snackbar has
              // already animated away (16 July 2026 report). Wraps the whole
              // app (above the ScaffoldMessenger) so snackbars are included.
              child: RepaintBoundary(
                key: debugFeedbackBoundaryKey,
                child: app,
              ),
            )
          : app));
}

/// Contained replacement for Flutter's default (unbounded, overflow-prone)
/// ErrorWidget — see the ErrorWidget.builder override in main().
class _SafeErrorWidget extends StatelessWidget {
  const _SafeErrorWidget({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // A build-throw's replacement inherits the broken widget's constraints,
    // which may be UNBOUNDED (e.g. the widget sat directly in a Row) — so
    // rendering the exception text at its natural width overflows ("RIGHT
    // OVERFLOWED BY N PIXELS", bug reports 21 Jul). Cap to a tiny fixed box
    // when the width is unbounded (a small icon can't overflow any slot); show
    // a readable message only when we actually have bounded width. Everything
    // is clipped so nothing can paint outside its box either way.
    return LayoutBuilder(
      builder: (context, c) {
        final bounded = c.maxWidth.isFinite;
        final w = bounded ? c.maxWidth : 40.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : (bounded ? 140.0 : 40.0);
        return SizedBox(
          width: w,
          height: h,
          child: ClipRect(
            child: Container(
              color: const Color(0xFFFBEAEA),
              alignment: Alignment.center,
              padding: EdgeInsets.all(bounded ? 12 : 4),
              child: bounded
                  ? SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFB00020), size: 28),
                          const SizedBox(height: 8),
                          const Text('This section couldn\'t load.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFFB00020),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          if (kDebugMode) ...[
                            const SizedBox(height: 6),
                            Text(details.exceptionAsString(),
                                textAlign: TextAlign.center,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF7A1520), fontSize: 10)),
                          ],
                        ],
                      ),
                    )
                  : const Icon(Icons.error_outline,
                      color: Color(0xFFB00020), size: 20),
            ),
          ),
        );
      },
    );
  }
}

class MarineSurveyApp extends StatelessWidget {
  const MarineSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      builder: (context, child) => Stack(
        children: [
          child!,
          const ImportReviewBanner(),
          const InterviewRecordingOverlay(),
          // Frozen still shown over the live app while the bug reporter is open
          // so annotation happens on a still frame (debug only).
          if (kDebugMode)
            ValueListenableBuilder<Uint8List?>(
              valueListenable: debugFeedbackFrozenFrame,
              builder: (context, frozen, _) => frozen == null
                  ? const SizedBox.shrink()
                  : Positioned.fill(
                      child: Image.memory(frozen,
                          fit: BoxFit.fill, gaplessPlayback: true),
                    ),
            ),
          if (kDebugMode) const DebugFeedbackButton(),
        ],
      ),
      title: 'Marine Survey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      locale: const Locale('en', 'AU'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'AU'),
      ],
    );
  }
}
