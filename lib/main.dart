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
      child: kDebugMode ? BetterFeedback(child: app) : app));
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
