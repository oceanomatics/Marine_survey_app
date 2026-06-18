// lib/core/config/app_config.dart
// ─────────────────────────────────────────────
// Replace placeholder values with your real keys
// NEVER commit real keys to version control
// Use --dart-define or a .env approach for CI/CD
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
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZnRvb2ZtY254ZnNodGFpbGduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MTI2MjUsImV4cCI6MjA5Njk4ODYyNX0.jEcRP0Zh9xVTlD6eVpfgcrhJLCKcIpZtSOydtyOF6YQ',
  );

  // ── Anthropic (Claude API) ─────────────────
  // Find this in: console.anthropic.com → API Keys
  static const anthropicApiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: 'YOUR_ANTHROPIC_API_KEY',
  );

  // True when a real key was injected via --dart-define at build time.
  static bool get isAnthropicKeySet =>
      anthropicApiKey.isNotEmpty &&
      anthropicApiKey != 'YOUR_ANTHROPIC_API_KEY';

  // Last 6 chars for display — enough to confirm which key is active.
  static String get anthropicKeyHint => isAnthropicKeySet
      ? '…${anthropicApiKey.substring(anthropicApiKey.length - 6)}'
      : 'not set';

  static const claudeModel = 'claude-sonnet-4-6';
  static const claudeMaxTokens = 4096;

  // ── OpenAI (Whisper transcription) ────────
  // Find this in: platform.openai.com → API Keys
  static const openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: 'YOUR_OPENAI_API_KEY',
  );

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
