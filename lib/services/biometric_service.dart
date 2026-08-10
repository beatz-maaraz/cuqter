import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static bool isAuthenticating = false;
  static bool? _cachedAppLockEnabled;

  static Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  static Future<bool> authenticate({
    String reason = 'Please authenticate to unlock Cuqter',
  }) async {
    isAuthenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: $e');
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      return false;
    } finally {
      isAuthenticating = false;
    }
  }

  static bool get appLockEnabled => _cachedAppLockEnabled ?? false;

  static Future<bool> isAppLockEnabled() async {
    if (_cachedAppLockEnabled != null) {
      return _cachedAppLockEnabled!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      return _cachedAppLockEnabled!;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    _cachedAppLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', enabled);
  }
}
