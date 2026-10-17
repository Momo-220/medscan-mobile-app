import 'dart:convert';
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
  static const String _keyLocalUsername = 'mediscan_user_username';
  static const String _keyAvatarCompleted = 'mediscan_avatar_completed';
  static const String _keyLocalAvatar = 'mediscan_user_avatar';
  static const String _keyDoctorCompleted = 'mediscan_doctor_completed';
  static const String _keySelectedDoctorId = 'mediscan_selected_doctor_id';
  static const String _keyPharmacyCachePrefix = 'pharmacy_cache_';
  static const String _keyChatCachePrefix = 'chat_cache_';
  static const String _keySuccessfulScansCount = 'medscan_successful_scans_count';
  static const String _keyHasRatedApp = 'medscan_has_rated_app';
  static const String _keyLastRatingPromptTimestamp = 'medscan_last_rating_prompt_ts';

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

  // Local Avatar (for instant and resilient avatar access across app)
  String? getLocalAvatar() {
    return _prefs.getString(_keyLocalAvatar);
  }

  Future<void> setLocalAvatar(String avatarPath) async {
    await _prefs.setString(_keyLocalAvatar, avatarPath);
  }

  Future<void> clearLocalAvatar() async {
    await _prefs.remove(_keyLocalAvatar);
  }

  // Doctor AI Setup Completed
  bool isDoctorCompleted() {
    return _prefs.getBool(_keyDoctorCompleted) ?? false;
  }

  Future<void> setDoctorCompleted(bool completed) async {
    await _prefs.setBool(_keyDoctorCompleted, completed);
  }

  // Selected Doctor AI ID
  String getSelectedDoctorId() {
    return _prefs.getString(_keySelectedDoctorId) ?? 'dr_sarah';
  }

  Future<void> setSelectedDoctorId(String doctorId) async {
    await _prefs.setString(_keySelectedDoctorId, doctorId);
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

  // Local Username
  String? getLocalUsername() {
    return _prefs.getString(_keyLocalUsername);
  }

  Future<void> setLocalUsername(String username) async {
    await _prefs.setString(_keyLocalUsername, username);
  }

  Future<void> clearLocalUsername() async {
    await _prefs.remove(_keyLocalUsername);
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

  // ChatGPT-style Chat Sessions Storage
  static const String _keyChatSessionsPrefix = 'chat_sessions_v2_';
  static const String _keyActiveChatSessionIdPrefix = 'active_chat_session_id_';
  static const String _keyActiveConsultationSessionIdPrefix = 'active_consultation_session_id_';
  static const String _keyLastChatActivityPrefix = 'last_chat_activity_ts_';

  String? getChatSessionsJson(String userId) {
    return _prefs.getString('$_keyChatSessionsPrefix$userId');
  }

  Future<void> setChatSessionsJson(String userId, String jsonStr) async {
    await _prefs.setString('$_keyChatSessionsPrefix$userId', jsonStr);
  }

  String? getActiveChatSessionId(String userId) {
    return _prefs.getString('$_keyActiveChatSessionIdPrefix$userId');
  }

  Future<void> setActiveChatSessionId(String userId, String sessionId) async {
    await _prefs.setString('$_keyActiveChatSessionIdPrefix$userId', sessionId);
  }

  String? getActiveConsultationSessionId(String userId) {
    return _prefs.getString('$_keyActiveConsultationSessionIdPrefix$userId');
  }

  Future<void> setActiveConsultationSessionId(String userId, String sessionId) async {
    await _prefs.setString('$_keyActiveConsultationSessionIdPrefix$userId', sessionId);
  }

  int? getLastChatActivity(String userId) {
    return _prefs.getInt('$_keyLastChatActivityPrefix$userId');
  }

  Future<void> setLastChatActivity(String userId, int timestamp) async {
    await _prefs.setInt('$_keyLastChatActivityPrefix$userId', timestamp);
  }

  Future<void> clearActiveChatSessionId(String userId) async {
    await _prefs.remove('$_keyActiveChatSessionIdPrefix$userId');
  }

  Future<void> clearActiveConsultationSessionId(String userId) async {
    await _prefs.remove('$_keyActiveConsultationSessionIdPrefix$userId');
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

  // In-App Review / Rating Tracking
  int getSuccessfulScansCount() {
    return _prefs.getInt(_keySuccessfulScansCount) ?? 0;
  }

  Future<void> incrementSuccessfulScansCount() async {
    final current = getSuccessfulScansCount();
    await _prefs.setInt(_keySuccessfulScansCount, current + 1);
  }

  Future<void> setSuccessfulScansCount(int count) async {
    await _prefs.setInt(_keySuccessfulScansCount, count);
  }

  bool hasRatedApp() {
    return _prefs.getBool(_keyHasRatedApp) ?? false;
  }

  Future<void> setHasRatedApp(bool rated) async {
    await _prefs.setBool(_keyHasRatedApp, rated);
  }

  int? getLastRatingPromptTimestamp() {
    return _prefs.getInt(_keyLastRatingPromptTimestamp);
  }

  Future<void> setLastRatingPromptTimestamp(int timestamp) async {
    await _prefs.setInt(_keyLastRatingPromptTimestamp, timestamp);
  }

  // Generic Getters/Setters
  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  // Clear Preferences on Logout — NEVER delete pharmacy scans cache
  Future<void> clearUserSession(String userId) async {
    // We intentionally KEEP pharmacy_cache_$userId so offline medical scans are NEVER lost!
    await _prefs.remove('$_keyChatCachePrefix$userId');
    await _prefs.remove('reminders_cache_$userId');
    await _prefs.remove('credits_cache_$userId');
    await _prefs.remove(_keyAvatarCompleted);
    await _prefs.remove(_keyLocalAvatar);
    // Keep theme, language, deviceId, onboarding, and pharmacy scan history!
  }

  /// Retrieves scans saved during anonymous/guest trial mode ONLY.
  /// Strictly prevents cross-account data leakage.
  List<dynamic> getTrialScans() {
    final cacheStr = _prefs.getString('$_keyPharmacyCachePrefix' 'trial');
    if (cacheStr != null && cacheStr.isNotEmpty) {
      try {
        final decoded = json.decode(cacheStr);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  /// Clears anonymous trial scans after migration to a user account.
  Future<void> clearTrialScans() async {
    await _prefs.remove('$_keyPharmacyCachePrefix' 'trial');
    await _prefs.remove('pharmacy_cache_language_trial');
  }

  // Deleted Scans Tombstone / Blacklist (guarantees deleted scans NEVER re-appear)
  static const String _keyDeletedScanIds = 'medscan_deleted_scan_ids';

  Set<String> getDeletedScanIds() {
    final list = _prefs.getStringList(_keyDeletedScanIds);
    if (list != null) {
      return list.toSet();
    }
    return {};
  }

  Future<void> addDeletedScanId(String scanId) async {
    if (scanId.trim().isEmpty) return;
    final current = getDeletedScanIds();
    current.add(scanId.trim());
    await _prefs.setStringList(_keyDeletedScanIds, current.toList());
  }
}
