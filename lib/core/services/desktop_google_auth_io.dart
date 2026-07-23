// lib/core/services/desktop_google_auth_io.dart
//
// Real desktop (Linux/Windows/macOS) implementation of DesktopGoogleAuth.
// Selected via the conditional export in desktop_google_auth.dart on any
// platform where dart:io exists (desktop + mobile — mobile never actually
// calls it because GoogleAuthService only routes here on desktop). The web
// build gets desktop_google_auth_stub.dart instead: googleapis_auth/auth_io.dart
// pulls in dart:io (an HttpServer for the loopback redirect), which does not
// compile on web.
//
// google_sign_in has no desktop plugin, so on desktop GoogleAuthService
// delegates its token calls here. One browser consent covers every Google
// consumer (Gmail, Drive, Photos) because they all read their Bearer token
// from GoogleAuthService.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class DesktopGoogleAuth {
  DesktopGoogleAuth._();

  static const _storage = FlutterSecureStorage();
  static const _credsKey = 'google_desktop_credentials_v1';

  // Same scope set as the mobile GoogleSignIn config in google_auth_service.dart
  // — one consent covers Gmail + Drive + Photos.
  static const _scopes = <String>[
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/photospicker.mediaitems.readonly',
  ];

  static AccessCredentials? _creds;
  static bool _restored = false;

  static bool get isConfigured =>
      AppConfig.googleDesktopClientId.isNotEmpty &&
      AppConfig.googleDesktopClientSecret.isNotEmpty;

  static ClientId get _clientId => ClientId(
        AppConfig.googleDesktopClientId,
        AppConfig.googleDesktopClientSecret,
      );

  static Future<void> _ensureRestored() async {
    if (_restored) return;
    _restored = true;
    try {
      final raw = await _storage.read(key: _credsKey);
      if (raw != null) {
        _creds = AccessCredentials.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      _creds = null;
    }
  }

  static Future<void> _persist(AccessCredentials creds) async {
    _creds = creds;
    try {
      await _storage.write(key: _credsKey, value: jsonEncode(creds.toJson()));
    } catch (e) {
      // Non-fatal: the token still works for this session; only cross-restart
      // persistence is lost (e.g. no secret service running).
      debugPrint('DesktopGoogleAuth: could not persist credentials: $e');
    }
  }

  static Future<void> _clear() async {
    _creds = null;
    try {
      await _storage.delete(key: _credsKey);
    } catch (_) {}
  }

  /// True if we currently hold (persisted or in-memory) credentials.
  static Future<bool> get isSignedIn async {
    await _ensureRestored();
    return _creds != null;
  }

  /// Clear all desktop Google credentials.
  static Future<void> signOut() => _clear();

  /// Returns a valid Bearer access token, refreshing silently or (if
  /// [interactive]) prompting via the system browser as needed. Returns null
  /// when no token can be obtained without UI ([interactive] == false), or when
  /// the user cancels / times out an interactive consent. Throws [StateError]
  /// if the desktop OAuth client isn't configured and a token is required
  /// interactively.
  static Future<String?> accessToken({required bool interactive}) async {
    if (!isConfigured) {
      if (interactive) {
        throw StateError(
          'Desktop Google OAuth is not configured. Set GOOGLE_DESKTOP_CLIENT_ID '
          'and GOOGLE_DESKTOP_CLIENT_SECRET in .dart_defines (create an OAuth '
          '"Desktop app" client in the Google Cloud Console).',
        );
      }
      return null;
    }

    await _ensureRestored();

    // 1. Valid cached token.
    final current = _creds;
    if (current != null && !current.accessToken.hasExpired) {
      return current.accessToken.data;
    }

    // 2. Silent refresh with the stored refresh token (no UI).
    if (current?.refreshToken != null) {
      final client = http.Client();
      try {
        final refreshed = await refreshCredentials(_clientId, current!, client);
        await _persist(refreshed);
        return refreshed.accessToken.data;
      } catch (e) {
        debugPrint('DesktopGoogleAuth: refresh failed ($e) — clearing.');
        await _clear();
      } finally {
        client.close();
      }
    }

    // 3. Interactive browser-loopback consent.
    if (!interactive) return null;
    final client = http.Client();
    try {
      final creds = await obtainAccessCredentialsViaUserConsent(
        _clientId,
        _scopes,
        client,
        (url) => unawaited(
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      ).timeout(const Duration(minutes: 5));
      await _persist(creds);
      return creds.accessToken.data;
    } on TimeoutException {
      return null; // user walked away — treat as cancel
    } on UserConsentException {
      return null; // user denied consent — treat as cancel
    } on AccessDeniedException {
      return null;
    } finally {
      client.close();
    }
  }
}
