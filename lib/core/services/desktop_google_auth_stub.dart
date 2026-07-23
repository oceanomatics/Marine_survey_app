// lib/core/services/desktop_google_auth_stub.dart
//
// Web / no-dart:io stub for DesktopGoogleAuth. Selected by the conditional
// export in desktop_google_auth.dart on web, where google_sign_in is used and
// the desktop loopback flow (which needs dart:io / an HttpServer) neither
// compiles nor runs. GoogleAuthService never routes here on web — its desktop
// guard is false — so these are inert and exist only to satisfy compilation.

class DesktopGoogleAuth {
  DesktopGoogleAuth._();

  static bool get isConfigured => false;

  static Future<bool> get isSignedIn async => false;

  static Future<void> signOut() async {}

  static Future<String?> accessToken({required bool interactive}) async => null;
}
