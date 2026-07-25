import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/app_version.dart';

sealed class AppVersionStatus {
  const AppVersionStatus();
}

class UpToDateStatus extends AppVersionStatus {
  const UpToDateStatus();
}

class MaintenanceStatus extends AppVersionStatus {
  final String message;
  const MaintenanceStatus(this.message);
}

class UpdateRequiredStatus extends AppVersionStatus {
  final AppVersionModel config;
  const UpdateRequiredStatus(this.config);
}

class UpdateAvailableStatus extends AppVersionStatus {
  final AppVersionModel config;
  const UpdateAvailableStatus(this.config);
}

class VersionService {
  final FirebaseFirestore _firestore;

  VersionService(this._firestore);

  /// Performs version check against Firestore config.
  /// Standard timeout of 2 seconds to prevent slow startup in case of poor network.
  Future<AppVersionStatus> checkVersion() async {
    try {
      // 1. Load local version information
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // 2. Fetch remote configurations from Firestore
      final doc = await _firestore
          .collection('config')
          .doc('app_version')
          .get()
          .timeout(const Duration(seconds: 2));

      if (!doc.exists || doc.data() == null) {
        return const UpToDateStatus();
      }

      final config = AppVersionModel.fromJson(doc.data()!);

      // 3. Check for maintenance status
      if (config.maintenance) {
        return MaintenanceStatus(config.maintenanceMessage);
      }

      // 4. Parse and compare versions
      final isBelowMinimum = _isVersionOlder(localVersion, config.minimumVersion);
      final isBelowLatest = _isVersionOlder(localVersion, config.latestVersion);

      if (config.forceUpdate || isBelowMinimum) {
        return UpdateRequiredStatus(config);
      }

      if (isBelowLatest) {
        return UpdateAvailableStatus(config);
      }

      return const UpToDateStatus();
    } catch (e) {
      debugPrint('Error running remote version checking: $e');
      // On connection error or timeout, let the user proceed normally
      return const UpToDateStatus();
    }
  }

  /// Compares semantic versions (e.g. "1.0.2" vs "1.0.3")
  bool _isVersionOlder(String localVersion, String targetVersion) {
    try {
      // Clean string from any trailing build number separator (+1)
      final localClean = localVersion.split('+')[0];
      final targetClean = targetVersion.split('+')[0];

      final localParts = localClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = targetClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = max(localParts.length, targetParts.length);
      for (int i = 0; i < maxLength; i++) {
        final localVal = i < localParts.length ? localParts[i] : 0;
        final targetVal = i < targetParts.length ? targetParts[i] : 0;

        if (localVal < targetVal) return true;
        if (localVal > targetVal) return false;
      }
    } catch (_) {}
    return false;
  }
}

final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService(FirebaseFirestore.instance);
});

final versionCheckProvider = FutureProvider<AppVersionStatus>((ref) async {
  final service = ref.watch(versionServiceProvider);
  return service.checkVersion();
});
