// lib/core/services/desktop_google_auth.dart
//
// Platform-dispatched DesktopGoogleAuth: the real browser-loopback OAuth
// implementation on desktop/mobile (dart:io present, see
// desktop_google_auth_io.dart), a no-op stub on web (desktop_google_auth_stub.dart).
// GoogleAuthService imports THIS file and only ever calls into it on desktop.
export 'desktop_google_auth_stub.dart'
    if (dart.library.io) 'desktop_google_auth_io.dart';
