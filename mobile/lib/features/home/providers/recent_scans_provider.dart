import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/recent_scan.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';

class RecentScansNotifier extends StateNotifier<AsyncValue<List<RecentScan>>> {
  final Ref _ref;
  final _client;
  final _storage;

  RecentScansNotifier(this._ref)
      : _client = _ref.read(apiClientProvider),
        _storage = _ref.read(secureStorageServiceProvider),
        super(const AsyncValue.loading()) {
    _syncAuthState();
  }

  void _syncAuthState() async {
    final user = _ref.read(firebaseAuthStateProvider).value;
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    
    if (user != null || (token != null && token.isNotEmpty)) {
      fetchRecentScans();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetchRecentScans() async {
    final token = await _storage.getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final lang = _ref.read(languageProvider);
      // Fetch the latest 3 scans from the backend MongoDB history
      final response = await _client.get(
        '/history',
        queryParameters: {'limit': 3, 'page': 1, 'language': lang},
      );
      if (!mounted) return;
      final List<dynamic> listJson = response.data['scans'] ?? response.data['history'] ?? [];
      final List<RecentScan> list = listJson.map((e) => RecentScan.fromJson(e)).toList();

      final resolvedScans = list.map<RecentScan>((scan) {
        if (scan.imageUrl != null) {
          String imgUrl = scan.imageUrl!;
          // Resolve dev localhost addresses to actual dev IP so physical device can load it
          if (imgUrl.contains('localhost:8888') || imgUrl.contains('127.0.0.1:8888')) {
            final base = ApiConstants.baseUrl.replaceAll('/api/v1', '');
            imgUrl = imgUrl.replaceAll(RegExp(r'https?://(localhost|127\.0\.0\.1):8888'), base);
          }
          return scan.copyWith(imageUrl: imgUrl);
        }
        return scan;
      }).toList();

      if (mounted) {
        state = AsyncValue.data(resolvedScans);
      }
    } catch (e, stack) {
      debugPrint('Failed to fetch recent scans from backend, falling back to cache: $e');
      
      // Fallback: load from local cache if backend is unreachable / offline
      try {
        final prefs = _ref.read(sharedPrefsServiceProvider);
        final user = _ref.read(firebaseAuthStateProvider).value;
        final cacheJson = prefs.getPharmacyCache(user?.uid ?? 'trial');
        if (cacheJson != null) {
          final List<dynamic> decoded = json.decode(cacheJson);
          var cachedScans = decoded.map((e) => RecentScan.fromJson(e)).toList();
          
          final appDir = await getApplicationDocumentsDirectory();
          final resolvedScans = cachedScans.map<RecentScan>((scan) {
            if (scan.imageUrl != null && !scan.imageUrl!.startsWith('http')) {
              final fileName = scan.imageUrl!.split('/').last;
              final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
              return scan.copyWith(imageUrl: resolvedFile.path);
            }
            return scan;
          }).toList();

          // Translate if needed
          final lang = _ref.read(languageProvider);
          final cacheLang = prefs.getPharmacyCacheLanguage(user?.uid ?? 'trial');
          bool needsTranslation = cacheLang != lang;

          if (needsTranslation) {
            try {
              final translationResponse = await _client.post(
                '/history/translate',
                data: {'items': resolvedScans.map((e) => e.toJson()).toList()},
                queryParameters: {'language': lang},
              );
              if (!mounted) return;
              final List<dynamic> translatedJson = translationResponse.data['items'] ?? [];
              final List<RecentScan> translatedScans = translatedJson.map((e) => RecentScan.fromJson(e)).toList();
              
              // Also translate and update the entire cache list
              final fullListTranslationResponse = await _client.post(
                '/history/translate',
                data: {'items': cachedScans.map((e) => e.toJson()).toList()},
                queryParameters: {'language': lang},
              );
              if (!mounted) return;
              final List<dynamic> fullTranslatedJson = fullListTranslationResponse.data['items'] ?? [];
              await prefs.setPharmacyCache(user?.uid ?? 'trial', json.encode(fullTranslatedJson));
              await prefs.setPharmacyCacheLanguage(user?.uid ?? 'trial', lang);
              if (!mounted) return;
              
              // Resolve images for translated scans
              final resolvedTranslatedScans = translatedScans.map<RecentScan>((scan) {
                if (scan.imageUrl != null && !scan.imageUrl!.startsWith('http')) {
                  final fileName = scan.imageUrl!.split('/').last;
                  final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
                  return scan.copyWith(imageUrl: resolvedFile.path);
                }
                return scan;
              }).toList();

              if (resolvedTranslatedScans.length > 3) {
                resolvedTranslatedScans.removeRange(3, resolvedTranslatedScans.length);
              }

              if (mounted) {
                state = AsyncValue.data(resolvedTranslatedScans);
                return;
              }
            } catch (translateError) {
              debugPrint('Failed to translate local cache: $translateError');
            }
          }

          if (resolvedScans.length > 3) {
            resolvedScans.removeRange(3, resolvedScans.length);
          }

          if (mounted) {
            state = AsyncValue.data(resolvedScans);
            return;
          }
        }
      } catch (cacheError) {
        debugPrint('Cache fallback failed: $cacheError');
      }

      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

final recentScansProvider = StateNotifierProvider<RecentScansNotifier, AsyncValue<List<RecentScan>>>((ref) {
  ref.watch(languageProvider);
  ref.watch(firebaseAuthStateProvider);
  return RecentScansNotifier(ref);
});
