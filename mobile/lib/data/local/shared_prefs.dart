import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SharedPrefsService {
  final SharedPreferences _prefs;

  SharedPrefsService(this._prefs);

  static const String _keyTheme = 'theme';
  static const String _keyLanguage = 'language';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyDeviceId = 'mediscan_device_id';
  static const String _keyLocalName = 'mediscan_user_name';
  static const String _keyAvatarCompleted = 'mediscan_avatar_completed';
  static const String _keyPharmacyCachePrefix = 'pharmacy_cache_';
  static const String _keyChatCachePrefix = 'chat_cache_';

  // Theme
  String getTheme() {
    return _prefs.getString(_keyTheme) ?? 'light';
  }

  Future<void> setTheme(String theme) async {
    await _prefs.setString(_keyTheme, theme);
  }

  // Language
  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? 'fr';
  }

  Future<void> setLanguage(String language) async {
    await _prefs.setString(_keyLanguage, language);
  }

  // Onboarding
  bool isOnboardingCompleted() {
    return _prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_keyOnboardingCompleted, completed);
  }

  // Avatar Setup Completed
  bool isAvatarCompleted() {
    return _prefs.getBool(_keyAvatarCompleted) ?? false;
  }

  Future<void> setAvatarCompleted(bool completed) async {
    await _prefs.setBool(_keyAvatarCompleted, completed);
  }

  // Local Name (for Trial/Anonymous User)
  String? getLocalName() {
    return _prefs.getString(_keyLocalName);
  }

  Future<void> setLocalName(String name) async {
    await _prefs.setString(_keyLocalName, name);
  }

  Future<void> clearLocalName() async {
    await _prefs.remove(_keyLocalName);
  }

  // Device ID (Trial Tracking)
  String getDeviceId() {
    String? id = _prefs.getString(_keyDeviceId);
    if (id == null) {
      id = 'd_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  // Cache Management (Pharmacy/History)
  String? getPharmacyCache(String userId) {
    return _prefs.getString('$_keyPharmacyCachePrefix$userId');
  }

  Future<void> setPharmacyCache(String userId, String cacheJson) async {
    await _prefs.setString('$_keyPharmacyCachePrefix$userId', cacheJson);
  }

  String? getPharmacyCacheLanguage(String userId) {
    return _prefs.getString('pharmacy_cache_language_$userId');
  }

  Future<void> setPharmacyCacheLanguage(String userId, String language) async {
    await _prefs.setString('pharmacy_cache_language_$userId', language);
  }

  // Cache Management (Chat History)
  String? getChatCache(String userId) {
    return _prefs.getString('$_keyChatCachePrefix$userId');
  }

  Future<void> setChatCache(String userId, String cacheJson) async {
    await _prefs.setString('$_keyChatCachePrefix$userId', cacheJson);
  }

  // Cache Management (Reminders)
  String? getRemindersCache(String userId) {
    return _prefs.getString('reminders_cache_$userId');
  }

  Future<void> setRemindersCache(String userId, String cacheJson) async {
    await _prefs.setString('reminders_cache_$userId', cacheJson);
  }

  // Cache Management (Credits/Gemmes)
  int? getCreditsCache(String userId) {
    return _prefs.getInt('credits_cache_$userId');
  }

  Future<void> setCreditsCache(String userId, int credits) async {
    await _prefs.setInt('credits_cache_$userId', credits);
  }

  // Clear Preferences on Logout
  Future<void> clearUserSession(String userId) async {
    await _prefs.remove('$_keyPharmacyCachePrefix$userId');
    await _prefs.remove('$_keyChatCachePrefix$userId');
    await _prefs.remove('reminders_cache_$userId');
    await _prefs.remove('credits_cache_$userId');
    await _prefs.remove(_keyAvatarCompleted);
    // Keep theme, language, deviceId, onboarding
  }
}
