import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  /// Performs version check against Firestore config AND direct App Store / Play Store API.
  /// Automatically notifies users as soon as a new version is published to stores.
  Future<AppVersionStatus> checkVersion() async {
    try {
      // 1. Load local version information
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // 2. Fetch remote configurations from Firestore
      AppVersionModel config = AppVersionModel.empty();
      try {
        final doc = await _firestore
            .collection('config')
            .doc('app_version')
            .get()
            .timeout(const Duration(seconds: 2));

        if (doc.exists && doc.data() != null) {
          config = AppVersionModel.fromJson(doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore version check notice: $e');
      }

      // 3. Check for maintenance status
      if (config.maintenance) {
        return MaintenanceStatus(config.maintenanceMessage);
      }

      // 4. Live Store Lookup: Query Apple Store on iOS and Google Play Store on Android
      String effectiveLatestVersion = config.latestVersion;
      String effectiveAppStoreUrl = config.appStoreUrl;
      String effectivePlayStoreUrl = config.playStoreUrl;

      if (Platform.isIOS) {
        try {
          final uri = Uri.parse('https://itunes.apple.com/lookup?bundleId=${packageInfo.packageName}');
          final response = await http.get(uri).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final results = data['results'] as List<dynamic>?;
            if (results != null && results.isNotEmpty) {
              final remoteStoreVersion = results[0]['version'] as String?;
              final trackViewUrl = results[0]['trackViewUrl'] as String?;
              if (remoteStoreVersion != null && _isVersionOlder(effectiveLatestVersion, remoteStoreVersion)) {
                effectiveLatestVersion = remoteStoreVersion;
              }
              if (trackViewUrl != null && trackViewUrl.isNotEmpty && effectiveAppStoreUrl.isEmpty) {
                effectiveAppStoreUrl = trackViewUrl;
              }
            }
          }
        } catch (e) {
          debugPrint('App Store direct lookup notice: $e');
        }
      } else if (Platform.isAndroid) {
        try {
          final uri = Uri.parse('https://play.google.com/store/apps/details?id=${packageInfo.packageName}&hl=en');
          final response = await http.get(
            uri,
            headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10)'},
          ).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            final match = RegExp(r'\[\[\["(\d+\.\d+(?:\.\d+)?)"').firstMatch(response.body);
            if (match != null) {
              final playStoreVersion = match.group(1);
              if (playStoreVersion != null && _isVersionOlder(effectiveLatestVersion, playStoreVersion)) {
                effectiveLatestVersion = playStoreVersion;
              }
            }
          }
        } catch (e) {
          debugPrint('Play Store direct lookup notice: $e');
        }
      }

      final resolvedConfig = AppVersionModel(
        latestVersion: effectiveLatestVersion,
        minimumVersion: config.minimumVersion,
        forceUpdate: config.forceUpdate,
        maintenance: config.maintenance,
        maintenanceMessage: config.maintenanceMessage,
        appStoreUrl: effectiveAppStoreUrl.isNotEmpty
            ? effectiveAppStoreUrl
            : 'https://apps.apple.com/app/id6789895804',
        playStoreUrl: effectivePlayStoreUrl.isNotEmpty
            ? effectivePlayStoreUrl
            : 'https://play.google.com/store/apps/details?id=com.seinimomo.medscanapp',
        releaseNotes: config.releaseNotes,
      );

      // 5. Parse and compare versions
      final isBelowMinimum = _isVersionOlder(localVersion, resolvedConfig.minimumVersion);
      final isBelowLatest = _isVersionOlder(localVersion, resolvedConfig.latestVersion);

      if (resolvedConfig.forceUpdate || isBelowMinimum) {
        return UpdateRequiredStatus(resolvedConfig);
      }

      if (isBelowLatest) {
        return UpdateAvailableStatus(resolvedConfig);
      }

      return const UpToDateStatus();
    } catch (e) {
      debugPrint('Error running version checking: $e');
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
