import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/secure_storage.dart';
import '../../data/local/shared_prefs.dart';
import '../../data/remote/api_client.dart';

// Instances providers (must be overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final sharedPrefsServiceProvider = Provider<SharedPrefsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsService(prefs);
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecureStorageService(storage);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return ApiClient(secureStorage);
});

class ThemeStateNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeStateNotifier(this._ref) : super(ThemeMode.light) {
    _init();
  }

  void _init() {
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final themeStr = prefs.getTheme();
    state = _parseThemeMode(themeStr);
  }

  ThemeMode _parseThemeMode(String themeStr) {
    switch (themeStr) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = _ref.read(sharedPrefsServiceProvider);
    String themeStr = 'light';
    if (mode == ThemeMode.dark) {
      themeStr = 'dark';
    } else if (mode == ThemeMode.system) {
      themeStr = 'system';
    }
    await prefs.setTheme(themeStr);
    state = mode;
  }
  
  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeStateNotifier, ThemeMode>((ref) {
  return ThemeStateNotifier(ref);
});
