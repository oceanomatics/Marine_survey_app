// lib/core/services/google_auth_service.dart
//
// Single shared GoogleSignIn instance for every Google Workspace integration
// (Drive, Gmail, Photos) — one consent screen covering all scopes instead of
// each feature triggering its own sign-in.
//
// SETUP REQUIRED — Google Cloud Console (same project as before, extended):
//   1. Enable "Google Drive API", "Gmail API", "Photos Library API"
//   2. OAuth consent screen: add the scopes below. While the app is in
//      "Testing" publishing status, any account added as a test user can
//      grant these scopes immediately — no Google verification review needed
//      for internal/single-user use.
//   3. Same Android/iOS OAuth client already used by Drive import continues
//      to work; no new client ID needed for additional scopes.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

class GoogleAuthService {
  GoogleAuthService._();

  static final _signIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/photoslibrary.appendonly',
      'https://www.googleapis.com/auth/photoslibrary.sharing',
    ],
  );

  static GoogleSignInAccount? get currentAccount => _signIn.currentUser;

  /// Signs in silently if possible, otherwise shows the account picker.
  /// Returns null only if the user explicitly cancels.
  static Future<GoogleSignInAccount?> ensureSignedIn() async {
    return _signIn.currentUser ??
        await _signIn.signInSilently() ??
        await _signIn.signIn();
  }

  static Future<void> signOut() => _signIn.signOut();

  /// Returns a usable OAuth access token, refreshing silently where possible.
  ///
  /// Google access tokens expire (~1 h), so a long survey session will hit a
  /// null/stale token mid-work. The previous implementation reacted to that by
  /// `signOut()` + interactive `signIn()`, which tore down the persisted
  /// session and popped a visible account picker mid-session — and because it
  /// had signed out, the *next* call had no `currentUser` either and prompted
  /// again. That was the "mailbox keeps asking me to log in" bug.
  ///
  /// Now a null token first attempts a *silent* refresh via `signInSilently()`
  /// (no UI) on mobile/desktop, where the OAuth session persists across the
  /// token's lifetime. Only if that genuinely fails do we fall back to the
  /// interactive path — so the surveyor is asked to sign in at most once per
  /// launch, not every time a token rolls over.
  ///
  /// Web is deliberately kept on the signOut-first interactive path: GIS can
  /// auto-restore a bare identity (no scoped access token) into `currentUser`
  /// on page load, and `google_sign_in_web`'s `signIn()` then requests with
  /// `prompt: ''` (fully silent, no visible UI) for that "known user" — so it
  /// silently fails again with no popup and no way to grant scopes. Signing
  /// out first clears the cached identity, forcing `signIn()` down its
  /// `prompt: 'select_account'` path, which shows the real consent screen.
  static Future<String> accessToken() async {
    var account = await ensureSignedIn();
    if (account == null) throw const GoogleSignInCancelled();
    var token = (await account.authentication).accessToken;
    if (token != null) return token;

    // Token expired/invalidated. On mobile/desktop, refresh silently first so
    // an expiry never surfaces as a login prompt.
    if (!kIsWeb) {
      final refreshed = await _signIn.signInSilently();
      if (refreshed != null) {
        token = (await refreshed.authentication).accessToken;
        if (token != null) return token;
      }
    }

    // Last resort (and the standard web path — see doc comment): clear the
    // session and re-consent interactively.
    await _signIn.signOut();
    account = await _signIn.signIn();
    if (account == null) throw const GoogleSignInCancelled();
    token = (await account.authentication).accessToken;

    if (token == null) {
      throw Exception('Could not obtain Google access token');
    }
    return token;
  }
}
