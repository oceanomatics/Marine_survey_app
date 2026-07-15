// lib/core/services/biometric_lock_service.dart
//
// Optional device-level app lock (14 July 2026 walkthrough — "2FA toggle...
// biometrics accepted as the second factor, not just OTP/authenticator").
// This is a local device gate (Face ID/fingerprint/Windows Hello via
// local_auth), not a server-side TOTP/OTP flow — the surveyor's own
// framing ("biometrics as the second factor") is exactly what this
// implements: something you know (Supabase login) + something you are
// (device biometric), checked at app start.

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEnabledKey = 'biometric_lock_enabled';

class BiometricLockService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Bounded with a timeout, not just a try/catch — an unhandled platform
  /// channel (e.g. no test binary messenger mock registered, or a genuinely
  /// unresponsive device implementation) leaves the underlying Future
  /// pending forever rather than throwing, which would otherwise soft-lock
  /// the App Lock card in its loading state indefinitely.
  static Future<bool> isSupported() async {
    try {
      return await (_auth.canCheckBiometrics.then((v) async =>
              v || await _auth.isDeviceSupported()))
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
  }

  /// Prompts the system biometric/device-credential UI. Returns false (not
  /// throws) on any failure — cancellation, no biometrics enrolled, or an
  /// unsupported device — so callers can treat every non-success case the
  /// same way (stay locked, let the surveyor retry).
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Marine Survey',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
