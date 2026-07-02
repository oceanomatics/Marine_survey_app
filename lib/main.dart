// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api/supabase_client.dart';
import 'core/config/app_router.dart';
import 'core/widgets/import_review_banner.dart';
import 'features/settings/providers/account_provider.dart';
import 'shared/theme/app_theme.dart';

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

  runApp(
    // Riverpod scope wraps the entire app, reusing the preloaded container
    // so accountProvider isn't reloaded from scratch.
    UncontrolledProviderScope(
      container: container,
      child: const MarineSurveyApp(),
    ),
  );
}

class MarineSurveyApp extends StatelessWidget {
  const MarineSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      builder: (context, child) => Stack(
        children: [child!, const ImportReviewBanner()],
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
