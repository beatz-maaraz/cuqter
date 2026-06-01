import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote Config parameter keys — must match what you set in the Firebase console.
class _Keys {
  static const latestVersion = 'latest_version'; // String  e.g. "1.4.0"
  static const downloadUrl = 'download_url'; // String  direct APK / page URL
  static const updateUrl = 'update_url'; // String  alternative key name
  static const releaseNotes = 'release_notes'; // String  changelog text
  static const forceUpdate = 'force_update'; // Boolean
}

class UpdateService {
  static FirebaseRemoteConfig? _rc;

  /// Initialises (once) and fetches fresh Remote Config values,
  /// then compares [latest_version] against the installed version.
  /// Returns [UpdateInfo] when an update is available, otherwise null.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      _rc ??= FirebaseRemoteConfig.instance;

      // Set default values so the app works even if fetch fails.
      await _rc!.setDefaults({
        _Keys.latestVersion: '',
        _Keys.downloadUrl: '',
        _Keys.updateUrl: '',
        _Keys.releaseNotes: '',
        _Keys.forceUpdate: false,
      });

      // Use zero interval in debug so you always get fresh values.
      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));

      final activated = await _rc!.fetchAndActivate();
      debugPrint('[UpdateService] fetchAndActivate → activated=$activated');

      final latestVersion = _rc!.getString(_Keys.latestVersion).trim();
      String downloadUrl = _rc!.getString(_Keys.downloadUrl).trim();
      if (downloadUrl.isEmpty) {
        downloadUrl = _rc!.getString(_Keys.updateUrl).trim();
      }
      final releaseNotes = _rc!.getString(_Keys.releaseNotes).trim();
      final forceUpdate = _rc!.getBool(_Keys.forceUpdate);

      debugPrint('[UpdateService] latestVersion="$latestVersion"');
      debugPrint('[UpdateService] downloadUrl="$downloadUrl"');
      debugPrint('[UpdateService] releaseNotes="$releaseNotes"');
      debugPrint('[UpdateService] forceUpdate=$forceUpdate');

      if (latestVersion.isEmpty) {
        debugPrint('[UpdateService] latest_version is empty — skipping update check.');
        return null;
      }
      if (downloadUrl.isEmpty) {
        debugPrint('[UpdateService] Both download_url and update_url are empty — skipping update check.');
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.3.8"
      debugPrint('[UpdateService] currentVersion="$currentVersion"');

      if (_isNewer(latestVersion, currentVersion)) {
        debugPrint('[UpdateService] Update available: $currentVersion → $latestVersion');
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
        );
      }

      debugPrint('[UpdateService] App is up to date.');
      return null;
    } catch (e, st) {
      // Surface errors during development; stay silent in release.
      debugPrint('[UpdateService] ERROR: $e\n$st');
      return null;
    }
  }

  /// Returns true when [remote] is strictly newer than [local] (semver compare).
  static bool _isNewer(String remote, String local) {
    final r = _segments(remote);
    final l = _segments(local);
    debugPrint('[UpdateService] Segment comparison: remote=$r vs local=$l');
    for (int i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static List<int> _segments(String v) {
    String clean = v.trim();
    // Strip leading 'v' or 'V'
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    // Strip build numbers and pre-release tags (e.g. "1.3.8+3" -> "1.3.8", "1.4.0-beta" -> "1.4.0")
    clean = clean.split('+')[0].split('-')[0].trim();

    final parts = clean.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}
