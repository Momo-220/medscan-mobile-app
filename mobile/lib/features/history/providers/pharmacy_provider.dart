import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/recent_scan.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/health_stats_provider.dart';
import '../../home/providers/recent_scans_provider.dart';
import '../../../data/remote/api_client.dart';
import '../../../data/local/secure_storage.dart';
import '../../../shared/utils/localization.dart';

class PharmacyState {
  final List<RecentScan> allScans;
  final List<RecentScan> filteredScans;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String selectedCategory;
  final String sortFilter; // 'all', 'date', 'name'

  PharmacyState({
    required this.allScans,
    required this.filteredScans,
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategory = '',
    this.sortFilter = 'all',
  });

  PharmacyState copyWith({
    List<RecentScan>? allScans,
    List<RecentScan>? filteredScans,
    bool? loading,
    String? error,
    String? searchQuery,
    String? selectedCategory,
    String? sortFilter,
  }) {
    return PharmacyState(
      allScans: allScans ?? this.allScans,
      filteredScans: filteredScans ?? this.filteredScans,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortFilter: sortFilter ?? this.sortFilter,
    );
  }
}

class PharmacyNotifier extends StateNotifier<PharmacyState> {
  final Ref _ref;
  final ApiClient _client;
  final SecureStorageService _storage;

  PharmacyNotifier(this._ref)
      : _client = _ref.read(apiClientProvider),
        _storage = _ref.read(secureStorageServiceProvider),
        super(PharmacyState(allScans: [], filteredScans: [])) {
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _migrateTrialScansIfAny(user.uid);
        _loadCacheAndFetch(user.uid);
      } else {
        _syncUnauthenticatedState();
      }
    }, fireImmediately: true);
  }

  void _syncUnauthenticatedState() {
    state = PharmacyState(allScans: [], filteredScans: []);
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

  /// Migrates ONLY anonymous/guest trial scans (if any) to the newly authenticated user.
  /// Never touches or reads scans belonging to any other user account on this device.
  void _migrateTrialScansIfAny(String targetUid) async {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final rawTrialScans = prefs.getTrialScans();
      final trialScans = rawTrialScans.where((item) {
        final name = (item['medicationName'] ?? item['medication_name'])?.toString();
        return isIdentifiedMedication(name);
      }).toList();
      if (trialScans.isEmpty) return;

      final targetCacheJson = prefs.getPharmacyCache(targetUid);
      List<dynamic> targetList = [];
      if (targetCacheJson != null && targetCacheJson.isNotEmpty) {
        try {
          targetList = json.decode(targetCacheJson);
        } catch (_) {}
      }

      final Map<String, dynamic> combinedMap = {};
      for (var item in targetList) {
        final scanId = item['scanId'] ?? item['id'] ?? item['scan_id'];
        if (scanId != null) combinedMap[scanId.toString()] = item;
      }
      for (var item in trialScans) {
        final scanId = item['scanId'] ?? item['id'] ?? item['scan_id'];
        if (scanId != null) combinedMap[scanId.toString()] = item;
      }

      final combinedList = combinedMap.values.toList();
      await prefs.setPharmacyCache(targetUid, json.encode(combinedList));

      // Clear trial scans immediately so they are never migrated again or to another account
      await prefs.clearTrialScans();

      // Sync migrated trial scans to backend MongoDB under targetUid
      final client = _ref.read(apiClientProvider);
      for (var item in trialScans) {
        try {
          await client.post('/history/migrate', data: item);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Trial scan migration error: $e');
    }
  }

  void _loadCacheAndFetch(String userId) async {
    // Immediately clear in-memory state so previous user's data does not linger
    state = PharmacyState(allScans: [], filteredScans: [], loading: true);

    // 1. Load local cache first strictly for this user (offline support & immediate display)
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final String? cacheJson = prefs.getPharmacyCache(userId);

    if (cacheJson != null && cacheJson.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedScans = list
            .map((e) => RecentScan.fromJson(e))
            .where((s) => isIdentifiedMedication(s.medicationName))
            .toList();
        
        // Translate local cache if language differs
        final lang = _ref.read(languageProvider);
        final cacheLang = prefs.getPharmacyCacheLanguage(userId);
        bool needsTranslation = cacheLang != lang;

        if (needsTranslation) {
          try {
            final translationResponse = await _client.post(
              '/history/translate',
              data: {'items': cachedScans.map((e) => e.toJson()).toList()},
              queryParameters: {'language': lang},
            );
            if (!mounted) return;
            final List<dynamic> translatedJson = translationResponse.data['items'] ?? [];
            final List<RecentScan> translatedScans = translatedJson.map((e) => RecentScan.fromJson(e)).toList();
            
            // Save to local cache
            await prefs.setPharmacyCache(userId, json.encode(translatedJson));
            await prefs.setPharmacyCacheLanguage(userId, lang);
            if (!mounted) return;
            
            // Re-assign to local scans
            cachedScans.clear();
            cachedScans.addAll(translatedScans);
          } catch (translateError) {
            debugPrint('Failed to translate local pharmacy cache: $translateError');
          }
        }

        final appDir = await getApplicationDocumentsDirectory();
        if (!mounted) return;
        final resolvedScans = cachedScans.map<RecentScan>((scan) {
          if (scan.imageUrl != null && !scan.imageUrl!.startsWith('http')) {
            final fileName = scan.imageUrl!.split('/').last;
            final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
            if (resolvedFile.existsSync()) {
              return scan.copyWith(imageUrl: resolvedFile.path);
            }
            return scan.copyWith(imageUrl: ApiConstants.resolveImageUrl(scan.imageUrl));
          }
          return scan;
        }).toList();

        // Sort descending: most recent first
        resolvedScans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

        state = PharmacyState(
          allScans: resolvedScans,
          filteredScans: resolvedScans,
          loading: false,
        );
        _applyFilters();
      } catch (_) {}
    }

    // 2. Fetch fresh lists
    fetchPharmacyList(userId);
  }

  Future<void> fetchPharmacyList(String userId) async {
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      state = state.copyWith(allScans: [], filteredScans: [], loading: false);
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      final lang = _ref.read(languageProvider);
      final response = await _client.get(
        '/history',
        queryParameters: {'limit': 100, 'page': 1, 'language': lang},
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

      // 3. Merge backend scans strictly with this user's local cache so offline scans are preserved
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final userCacheJson = prefs.getPharmacyCache(userId);
      List<RecentScan> userLocalScans = [];
      if (userCacheJson != null && userCacheJson.isNotEmpty) {
        try {
          final List<dynamic> localDecoded = json.decode(userCacheJson);
          userLocalScans = localDecoded
              .map((e) => RecentScan.fromJson(e))
              .where((s) => isIdentifiedMedication(s.medicationName))
              .toList();
        } catch (_) {}
      }

      final Map<String, RecentScan> mergedMap = {};
      for (final localScan in userLocalScans) {
        mergedMap[localScan.scanId] = localScan;
      }
      for (final backendScan in resolvedScans) {
        if (mergedMap.containsKey(backendScan.scanId)) {
          final local = mergedMap[backendScan.scanId]!;
          final earliestScannedAt = local.scannedAt.isBefore(backendScan.scannedAt)
              ? local.scannedAt
              : backendScan.scannedAt;
          mergedMap[backendScan.scanId] = backendScan.copyWith(
            scannedAt: earliestScannedAt,
            localImagePath: local.localImagePath ?? backendScan.localImagePath,
          );
        } else {
          mergedMap[backendScan.scanId] = backendScan;
        }
      }
      final mergedList = mergedMap.values.toList();
      mergedList.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

      // Filter out permanently deleted scans from blacklist & unidentified medications
      final deletedIds = prefs.getDeletedScanIds();
      final activeMergedList = mergedList
          .where((s) => !deletedIds.contains(s.scanId) && !deletedIds.contains(s.id) && isIdentifiedMedication(s.medicationName))
          .toList();

      // Auto-sync any user local-only scans to MongoDB backend in background
      for (final scan in userLocalScans) {
        if (!deletedIds.contains(scan.scanId) &&
            !deletedIds.contains(scan.id) &&
            isIdentifiedMedication(scan.medicationName) &&
            !list.any((b) => (b.scanId == scan.scanId || b.id == scan.id))) {
          try {
            _client.post('/history/migrate', data: scan.toJson());
          } catch (_) {}
        }
      }

      if (mounted) {
        state = state.copyWith(
          allScans: activeMergedList,
          filteredScans: activeMergedList,
          loading: false,
        );
        _saveCache(userId, activeMergedList);
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          error: state.allScans.isEmpty ? e.toString() : null,
        );
      }
    }
  }

  void _saveCache(String userId, List<RecentScan> scans) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final listJson = scans.map((e) => e.toJson()).toList();
      prefs.setPharmacyCache(userId, json.encode(listJson));
      final lang = _ref.read(languageProvider);
      prefs.setPharmacyCacheLanguage(userId, lang);
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    _applyFilters();
  }

  void setSortFilter(String filter) {
    state = state.copyWith(sortFilter: filter);
    _applyFilters();
  }

  void _applyFilters() {
    List<RecentScan> filtered = List<RecentScan>.from(state.allScans);

    // Apply category filter
    if (state.selectedCategory.isNotEmpty) {
      filtered = filtered
          .where((s) => s.category.toLowerCase() == state.selectedCategory.toLowerCase())
          .toList();
    }

    // Apply search query filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final matchesName = s.medicationName.toLowerCase().contains(query);
        final matchesGeneric = s.genericName?.toLowerCase().contains(query) ?? false;
        final matchesCategory = s.category.toLowerCase().contains(query);
        return matchesName || matchesGeneric || matchesCategory;
      }).toList();
    }

    // Apply sort filter: 'name' -> A-Z, 'date' / 'all' -> most recent first
    if (state.sortFilter == 'name') {
      filtered.sort((a, b) => a.medicationName.toLowerCase().compareTo(b.medicationName.toLowerCase()));
    } else {
      filtered.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    }

    state = state.copyWith(filteredScans: filtered);
  }

  Future<bool> deleteScan(String scanId, {String? secondaryId}) async {
    try {
      // 1. Add to persistent tombstone blacklist immediately
      final prefs = _ref.read(sharedPrefsServiceProvider);
      await prefs.addDeletedScanId(scanId);
      if (secondaryId != null && secondaryId.isNotEmpty && secondaryId != scanId) {
        await prefs.addDeletedScanId(secondaryId);
      }

      // 2. Remove optimistically from state
      final updatedAll = state.allScans.where((s) {
        final matchesPrimary = s.scanId == scanId || s.id == scanId;
        final matchesSecondary = secondaryId != null && (s.scanId == secondaryId || s.id == secondaryId);
        return !matchesPrimary && !matchesSecondary;
      }).toList();

      final updatedFiltered = state.filteredScans.where((s) {
        final matchesPrimary = s.scanId == scanId || s.id == scanId;
        final matchesSecondary = secondaryId != null && (s.scanId == secondaryId || s.id == secondaryId);
        return !matchesPrimary && !matchesSecondary;
      }).toList();

      state = state.copyWith(allScans: updatedAll, filteredScans: updatedFiltered);

      // 3. Persist updated cache
      final user = _ref.read(firebaseAuthStateProvider).value;
      final userId = user?.uid ?? 'trial';
      _saveCache(userId, updatedAll);

      // 4. Remove from trial scans in shared preferences if present
      final trialScans = prefs.getTrialScans();
      if (trialScans.isNotEmpty) {
        final filteredTrial = trialScans.where((s) {
          final id = (s['scanId'] ?? s['scan_id'] ?? s['id'])?.toString();
          return id != scanId && (secondaryId == null || id != secondaryId);
        }).toList();
        await prefs.setPharmacyCache('trial', json.encode(filteredTrial));
      }

      // 5. Call backend DELETE endpoint if authenticated
      if (user != null && !user.isAnonymous) {
        try {
          await _client.delete('/history/$scanId');
        } catch (e) {
          debugPrint('Backend delete scan notice: $e');
        }
      }

      // 6. Invalidate / update health stats and recent scans
      try {
        _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
      } catch (_) {}
      try {
        _ref.read(recentScansProvider.notifier).fetchRecentScans();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error deleting scan: $e');
      return false;
    }
  }
}

final pharmacyProvider = StateNotifierProvider<PharmacyNotifier, PharmacyState>((ref) {
  ref.watch(languageProvider);
  ref.watch(firebaseAuthStateProvider);
  return PharmacyNotifier(ref);
});
