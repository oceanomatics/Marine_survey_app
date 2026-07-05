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

  /// On web, GIS can auto-restore a bare identity (no scoped access token)
  /// into `currentUser` on page load. Worse, `google_sign_in_web`'s `signIn()`
  /// internally requests with `prompt: ''` (fully silent, no visible UI)
  /// whenever it already knows a "known user" from that restored identity —
  /// so simply re-calling `signIn()` silently fails again with no popup and
  /// no way to grant scopes. Signing out first clears that cached identity,
  /// forcing `signIn()` down its `prompt: 'select_account'` path instead,
  /// which shows the real consent screen and actually grants the scopes.
  static Future<String> accessToken() async {
    var account = await ensureSignedIn();
    if (account == null) throw const GoogleSignInCancelled();
    var token = (await account.authentication).accessToken;

    if (token == null) {
      await _signIn.signOut();
      account = await _signIn.signIn();
      if (account == null) throw const GoogleSignInCancelled();
      token = (await account.authentication).accessToken;
    }

    if (token == null) {
      throw Exception('Could not obtain Google access token');
    }
    return token;
  }
}
