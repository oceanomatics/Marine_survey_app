// lib/core/config/app_config.dart
// ─────────────────────────────────────────────
// Supabase credentials are compile-time (--dart-define) since they're
// needed to bootstrap the DB connection itself.
// AI/service API keys are runtime-mutable: they're loaded from the
// `profiles` table (see AccountNotifier) once the user is signed in, so
// they can be changed from the Account screen without a rebuild.
// A --dart-define value, if supplied, is used only until that DB load
// completes (or as a fallback if the user never sets one in-app).
// ─────────────────────────────────────────────

class AppConfig {
  // ── Supabase ──────────────────────────────
  // Find these in: Supabase Dashboard → Project Settings → API
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mgftoofmcnxfshtailgn.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZnRvb2ZtY254ZnNodGFpbGduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MTI2MjUsImV4cCI6MjA5Njk4ODYyNX0.jEcRP0Zh9xVTlD6eVpfgcrhJLCKcIpZtSOydtyOF6YQ',
  );

  // ── Anthropic (Claude API) ─────────────────
  static String anthropicApiKey =
      const String.fromEnvironment('ANTHROPIC_API_KEY');

  static bool get isAnthropicKeySet => anthropicApiKey.isNotEmpty;

  // Last 6 chars for display — enough to confirm which key is active.
  static String get anthropicKeyHint => isAnthropicKeySet
      ? '…${anthropicApiKey.substring(anthropicApiKey.length - 6)}'
      : 'not set';

  static const claudeModel = 'claude-sonnet-4-6';
  static const claudeMaxTokens = 4096;

  // ── OpenAI ─────────────────────────────────
  static String openAiApiKey = const String.fromEnvironment('OPENAI_API_KEY');
  static bool get isOpenAiKeySet => openAiApiKey.isNotEmpty;

  // ── Google (Maps/Places etc.) ──────────────
  static String googleApiKey = const String.fromEnvironment('GOOGLE_API_KEY');
  static bool get isGoogleKeySet => googleApiKey.isNotEmpty;

  // ── Google desktop OAuth (Linux/Windows/macOS) ─────────────
  // google_sign_in has no desktop implementation, so on desktop we use the
  // installed-app loopback flow (DesktopGoogleAuth). It needs an OAuth 2.0
  // client of type "Desktop app" (id + secret) from the Google Cloud Console —
  // distinct from the mobile client. Set both in .dart_defines. Empty on
  // mobile/web (where google_sign_in is used instead). Installed-app secrets
  // are not truly confidential per Google's own guidance, so shipping them via
  // --dart-define is acceptable.
  static const googleDesktopClientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const googleDesktopClientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  // ── Google Drive unified storage ───────────
  // Root folder name under which Cases/ and Admin/ live in the user's Drive
  // — null means directly under "My Drive". Set from the Account screen
  // (AccountNotifier.saveDriveBaseFolder), read by DriveStorageService.
  static String? driveBaseFolder;

  // ── App settings ──────────────────────────
  static const appName = 'Marine Survey';
  static const appVersion = '1.0.0';
  static const companyName = 'Oceanomatics Pty Ltd';

  // Offline sync interval in seconds
  static const syncIntervalSeconds = 30;

  // Max photo size for upload (bytes) — 10MB
  static const maxPhotoSizeBytes = 10 * 1024 * 1024;

  // Audio recording quality
  static const audioSampleRate = 44100;
  static const audioBitRate = 128000;
}
