import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import '../../core/di/providers.dart';

class LanguageStateNotifier extends StateNotifier<String> {
  final Ref _ref;

  LanguageStateNotifier(this._ref) : super('fr') {
    _init();
  }

  void _init() {
    final prefs = _ref.read(sharedPrefsServiceProvider);
    state = prefs.getLanguage();
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = _ref.read(sharedPrefsServiceProvider);
    await prefs.setLanguage(langCode);
    state = langCode;
    // Load new translation map
    await _ref.read(translationsProvider.notifier).loadTranslations(langCode);
  }
}

class TranslationsStateNotifier extends StateNotifier<Map<String, String>> {
  TranslationsStateNotifier() : super({});

  Future<void> loadTranslations(String langCode) async {
    try {
      final jsonString = await rootBundle.loadString('assets/translations/$langCode.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      state = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // Fallback to French if loading fails
      try {
        final jsonString = await rootBundle.loadString('assets/translations/fr.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        state = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      } catch (_) {
        state = {};
      }
    }
  }
}

// Providers
final languageProvider = StateNotifierProvider<LanguageStateNotifier, String>((ref) {
  return LanguageStateNotifier(ref);
});

final translationsProvider = StateNotifierProvider<TranslationsStateNotifier, Map<String, String>>((ref) {
  final translationsNotifier = TranslationsStateNotifier();
  // Auto load active language
  final currentLang = ref.watch(languageProvider);
  translationsNotifier.loadTranslations(currentLang);
  return translationsNotifier;
});

// Extension to make translating inside widgets super easy:
// ref.watch(translationsProvider)['key'] ?? 'key'
// We can also make a utility extension:
extension TranslateExtension on WidgetRef {
  String t(String key) {
    return watch(translationsProvider)[key] ?? key;
  }
}
