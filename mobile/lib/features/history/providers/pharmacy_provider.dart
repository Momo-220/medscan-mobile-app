import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/recent_scan.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/utils/localization.dart';

class PharmacyState {
  final List<RecentScan> allScans;
  final List<RecentScan> filteredScans;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String selectedCategory;

  PharmacyState({
    required this.allScans,
    required this.filteredScans,
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategory = '',
  });

  PharmacyState copyWith({
    List<RecentScan>? allScans,
    List<RecentScan>? filteredScans,
    bool? loading,
    String? error,
    String? searchQuery,
    String? selectedCategory,
  }) {
    return PharmacyState(
      allScans: allScans ?? this.allScans,
      filteredScans: filteredScans ?? this.filteredScans,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class PharmacyNotifier extends StateNotifier<PharmacyState> {
  final Ref _ref;
  final _client;
  final _storage;

  PharmacyNotifier(this._ref)
      : _client = _ref.read(apiClientProvider),
        _storage = _ref.read(secureStorageServiceProvider),
        super(PharmacyState(allScans: [], filteredScans: [])) {
    _syncAuthState();
  }

  void _syncAuthState() async {
    final user = _ref.read(firebaseAuthStateProvider).value;
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    
    if (user != null) {
      final oldUser = _ref.read(firebaseAuthStateProvider).value;
      if (oldUser != null && oldUser.isAnonymous && !user.isAnonymous) {
        _migrateAnonymousScans(oldUser.uid, user.uid);
      } else {
        _loadCacheAndFetch(user.uid);
      }
    } else if (token != null && token.isNotEmpty) {
      _loadCacheAndFetch('trial');
    } else {
      state = PharmacyState(allScans: [], filteredScans: []);
    }
  }

  void _migrateAnonymousScans(String anonUid, String targetUid) async {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final anonCacheJson = prefs.getPharmacyCache(anonUid);
      if (anonCacheJson != null && anonCacheJson.isNotEmpty) {
        final List<dynamic> anonList = json.decode(anonCacheJson);
        if (anonList.isNotEmpty) {
          List<dynamic> targetList = [];
          final targetCacheJson = prefs.getPharmacyCache(targetUid);
          if (targetCacheJson != null && targetCacheJson.isNotEmpty) {
            try {
              targetList = json.decode(targetCacheJson);
            } catch (_) {}
          }

          // Merge lists keeping unique scanIds
          final Map<String, dynamic> combinedMap = {};
          for (var item in targetList) {
            final scanId = item['scanId'] ?? item['id'] ?? item['scan_id'];
            if (scanId != null) combinedMap[scanId.toString()] = item;
          }
          for (var item in anonList) {
            final scanId = item['scanId'] ?? item['id'] ?? item['scan_id'];
            if (scanId != null) combinedMap[scanId.toString()] = item;
          }

          final combinedList = combinedMap.values.toList();
          await prefs.setPharmacyCache(targetUid, json.encode(combinedList));
          final lang = _ref.read(languageProvider);
          await prefs.setPharmacyCacheLanguage(targetUid, lang);
          
          // Also sync to backend so the new user account permanently stores these scans in MongoDB
          final client = _ref.read(apiClientProvider);
          for (var item in anonList) {
            try {
              await client.post('/history/migrate', data: item);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    // Load fresh target user scans (will include the migrated ones since we synced them above)
    _loadCacheAndFetch(targetUid);
  }

  void _loadCacheAndFetch(String userId) async {
    // 1. Load local cache first (offline support)
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final cacheJson = prefs.getPharmacyCache(userId);
    if (cacheJson != null) {
      try {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedScans = list.map((e) => RecentScan.fromJson(e)).toList();
        
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

        state = PharmacyState(
          allScans: cachedScans,
          filteredScans: cachedScans,
        );

        final appDir = await getApplicationDocumentsDirectory();
        if (!mounted) return;
        final resolvedScans = cachedScans.map<RecentScan>((scan) {
          if (scan.imageUrl != null && !scan.imageUrl!.startsWith('http')) {
            final fileName = scan.imageUrl!.split('/').last;
            final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
            return scan.copyWith(imageUrl: resolvedFile.path);
          }
          return scan;
        }).toList();

        state = PharmacyState(
          allScans: resolvedScans,
          filteredScans: resolvedScans,
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
      final List<RecentScan> list = listJson.map((e) => RecentScan.fromJson(e)).toList();

      final appDir = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      final resolvedScans = list.map<RecentScan>((scan) {
        if (scan.imageUrl != null) {
          String imgUrl = scan.imageUrl!;
          if (!imgUrl.startsWith('http')) {
            final fileName = imgUrl.split('/').last;
            final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
            return scan.copyWith(imageUrl: resolvedFile.path);
          } else {
            // Resolve dev localhost addresses to actual dev IP so physical device can load it
            if (imgUrl.contains('localhost:8888') || imgUrl.contains('127.0.0.1:8888')) {
              final base = ApiConstants.baseUrl.replaceAll('/api/v1', '');
              imgUrl = imgUrl.replaceAll(RegExp(r'https?://(localhost|127\.0\.0\.1):8888'), base);
            }
            return scan.copyWith(imageUrl: imgUrl);
          }
        }
        return scan;
      }).toList();

      if (mounted) {
        state = state.copyWith(
          allScans: resolvedScans,
          filteredScans: resolvedScans,
          loading: false,
        );
        _saveCache(userId, resolvedScans);
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

  void _applyFilters() {
    List<RecentScan> filtered = List<RecentScan>.from(state.allScans);

    // Apply category filter
    if (state.selectedCategory.isNotEmpty) {
      filtered = filtered
          .where((s) => s.category.toLowerCase() == state.selectedCategory.toLowerCase())
          .toList();
    }

    // Apply search search query filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final matchesName = s.medicationName.toLowerCase().contains(query);
        final matchesGeneric = s.genericName?.toLowerCase().contains(query) ?? false;
        final matchesCategory = s.category.toLowerCase().contains(query);
        return matchesName || matchesGeneric || matchesCategory;
      }).toList();
    }

    state = state.copyWith(filteredScans: filtered);
  }
}

final pharmacyProvider = StateNotifierProvider<PharmacyNotifier, PharmacyState>((ref) {
  ref.watch(languageProvider);
  ref.watch(firebaseAuthStateProvider);
  return PharmacyNotifier(ref);
});
