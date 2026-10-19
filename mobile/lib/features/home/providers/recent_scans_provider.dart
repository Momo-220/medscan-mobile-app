import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/recent_scan.dart';
import '../../../data/remote/api_client.dart';
import '../../../data/local/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/pharmacy_provider.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';

class RecentScansNotifier extends StateNotifier<AsyncValue<List<RecentScan>>> {
  final Ref _ref;
  final ApiClient _client;
  final SecureStorageService _storage;

  RecentScansNotifier(this._ref)
      : _client = _ref.read(apiClientProvider),
        _storage = _ref.read(secureStorageServiceProvider),
        super(const AsyncValue.loading()) {
    _loadFromCacheOrPharmacy();
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        fetchRecentScans();
      } else {
        _syncUnauthenticatedState();
      }
    }, fireImmediately: true);
  }

  static bool isIdentifiedMedication(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final lower = name.trim().toLowerCase();
    if (lower == 'medication not identified' ||
        lower == 'médicament non identifié' ||
        lower == 'non identifié' ||
        lower == 'not identified' ||
        lower == 'unknown' ||
        lower == 'inconnu' ||
        lower == 'aucun' ||
        lower == 'tanımlanamayan ilaç' ||
        lower == 'دواء غير محدد') {
      return false;
    }
    return true;
  }

  void _loadFromCacheOrPharmacy() {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final deletedIds = prefs.getDeletedScanIds();

      // 1. Check pharmacyProvider first
      final pharmacyScans = _ref.read(pharmacyProvider).allScans;
      final validPharmacy = pharmacyScans
          .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id) && isIdentifiedMedication(s.medicationName))
          .toList();
      if (validPharmacy.isNotEmpty) {
        validPharmacy.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        state = AsyncValue.data(validPharmacy.take(4).toList());
        return;
      }

      // 2. Check local user/trial cache (isolated by user ID)
      final user = _ref.read(firebaseAuthStateProvider).value;
      final cacheJson = user != null
          ? prefs.getPharmacyCache(user.uid)
          : prefs.getPharmacyCache('trial');
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(cacheJson);
        final list = decoded
            .map((e) => RecentScan.fromJson(e))
            .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id) && isIdentifiedMedication(s.medicationName))
            .toList();
        list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        if (list.isNotEmpty) {
          state = AsyncValue.data(list.take(4).toList());
        }
      }
    } catch (_) {}
  }

  void syncWithPharmacy(List<RecentScan> scans) {
    if (!mounted || scans.isEmpty) return;
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final deletedIds = prefs.getDeletedScanIds();
    final valid = scans
        .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id) && isIdentifiedMedication(s.medicationName))
        .toList();
    valid.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    if (valid.isNotEmpty) {
      state = AsyncValue.data(valid.take(4).toList());
    }
  }

  void _syncUnauthenticatedState() async {
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      fetchRecentScans();
    } else {
      _loadFromCacheOrPharmacy();
      if (state.value == null || state.value!.isEmpty) {
        state = const AsyncValue.data([]);
      }
    }
  }

  Future<void> fetchRecentScans() async {
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _loadFromCacheOrPharmacy();
      return;
    }

    if (state.value == null || state.value!.isEmpty) {
      state = const AsyncValue.loading();
    }

    try {
      final lang = _ref.read(languageProvider);
      // Fetch up to 50 scans from the backend to ensure we always have 4 active items after deleted/tombstone filtering
      final response = await _client.get(
        '/history',
        queryParameters: {'limit': 50, 'page': 1, 'language': lang},
      );
      if (!mounted) return;
      final List<dynamic> listJson = response.data['scans'] ?? response.data['history'] ?? [];
      final List<RecentScan> list = listJson
          .map((e) => RecentScan.fromJson(e))
          .where((s) => isIdentifiedMedication(s.medicationName))
          .toList();

      final appDir = await getApplicationDocumentsDirectory();
      if (!mounted) return;

      final resolvedScans = list.map<RecentScan>((scan) {
        if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) {
          final imgUrl = scan.imageUrl!;
          if (!imgUrl.startsWith('http')) {
            final fileName = imgUrl.split('/').last;
            final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
            if (resolvedFile.existsSync()) {
              return scan.copyWith(imageUrl: resolvedFile.path, localImagePath: resolvedFile.path);
            }
          }
          final resolvedNetworkUrl = ApiConstants.resolveImageUrl(imgUrl);
          return scan.copyWith(imageUrl: resolvedNetworkUrl);
        }
        return scan;
      }).toList();

      final prefs = _ref.read(sharedPrefsServiceProvider);
      final user = _ref.read(firebaseAuthStateProvider).value;
      final cacheJson = user != null
          ? prefs.getPharmacyCache(user.uid)
          : prefs.getPharmacyCache('trial');

      Map<String, RecentScan> localCacheMap = {};
      if (cacheJson != null && cacheJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(cacheJson);
          for (var item in decoded) {
            final localScan = RecentScan.fromJson(item);
            if (isIdentifiedMedication(localScan.medicationName)) {
              localCacheMap[localScan.scanId] = localScan;
            }
          }
        } catch (_) {}
      }

      // Merge local cache, pharmacy provider, and backend scans together
      final Map<String, RecentScan> mergedMap = {};

      // 1. Local cache scans
      for (final local in localCacheMap.values) {
        mergedMap[local.scanId] = local;
      }

      // 2. Pharmacy provider scans
      final pharmacyScans = _ref.read(pharmacyProvider).allScans;
      for (final pScan in pharmacyScans) {
        if (!mergedMap.containsKey(pScan.scanId) && isIdentifiedMedication(pScan.medicationName)) {
          mergedMap[pScan.scanId] = pScan;
        }
      }

      // 3. Backend resolved scans (authoritative details, preserving localImagePath)
      for (final scan in resolvedScans) {
        final local = mergedMap[scan.scanId] ?? (scan.id.isNotEmpty ? mergedMap[scan.id] : null);
        String? finalLocalPath = local?.localImagePath;
        if (finalLocalPath == null && scan.imageUrl != null && !scan.imageUrl!.startsWith('http')) {
          final fileName = scan.imageUrl!.split('/').last;
          final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
          if (resolvedFile.existsSync()) {
            finalLocalPath = resolvedFile.path;
          }
        }
        final earliestDate = (local != null && local.scannedAt.isBefore(scan.scannedAt))
            ? local.scannedAt
            : scan.scannedAt;

        mergedMap[scan.scanId] = scan.copyWith(
          scannedAt: earliestDate,
          localImagePath: finalLocalPath,
          imageUrl: (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) ? scan.imageUrl : local?.imageUrl,
        );
      }

      final deletedIds = prefs.getDeletedScanIds();
      final activeMergedScans = mergedMap.values
          .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id) && isIdentifiedMedication(s.medicationName))
          .toList();

      activeMergedScans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

      if (mounted) {
        state = AsyncValue.data(activeMergedScans.take(4).toList());
      }
    } catch (e, stack) {
      debugPrint('Failed to fetch recent scans from backend, falling back to cache: $e');
      _loadFromCacheOrPharmacy();
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<bool> deleteScan(String scanId, {String? secondaryId}) async {
    // 1. Add to tombstone persistent storage immediately
    final prefs = _ref.read(sharedPrefsServiceProvider);
    await prefs.addDeletedScanId(scanId);
    if (secondaryId != null && secondaryId.isNotEmpty && secondaryId != scanId) {
      await prefs.addDeletedScanId(secondaryId);
    }

    // 2. Optimistic removal & backfill to always keep 4 items if available
    final deletedIds = prefs.getDeletedScanIds();
    final pharmacyScans = _ref.read(pharmacyProvider).allScans;
    final allAvailable = pharmacyScans.isNotEmpty
        ? pharmacyScans
        : (state.value ?? []);
    final updated = allAvailable
        .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id))
        .toList();
    updated.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    state = AsyncValue.data(updated.take(4).toList());

    // 3. Delegate to pharmacyProvider for cache, backend, and health stats sync
    final success = await _ref.read(pharmacyProvider.notifier).deleteScan(scanId, secondaryId: secondaryId);
    await fetchRecentScans();
    return success;
  }
}

final recentScansProvider = StateNotifierProvider<RecentScansNotifier, AsyncValue<List<RecentScan>>>((ref) {
  ref.watch(languageProvider);
  ref.watch(firebaseAuthStateProvider);
  final notifier = RecentScansNotifier(ref);
  ref.listen<PharmacyState>(pharmacyProvider, (prev, next) {
    if (next.allScans.isNotEmpty) {
      notifier.syncWithPharmacy(next.allScans);
    }
  });
  return notifier;
});
