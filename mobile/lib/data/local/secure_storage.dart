import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService(this._storage);

  static const String _keyAuthToken = 'auth_token';
  static const String _keyDeviceId = 'mediscan_secure_device_id';

  // ── Auth Token ────────────────────────────────────────────────────────────

  /// Read the stored auth token (Firebase or trial JWT).
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _keyAuthToken);
    } catch (e) {
      debugPrint('SecureStorageService.getAuthToken error: $e');
      return null;
    }
  }

  /// Persist an auth token securely (Keychain on iOS, EncryptedSharedPrefs on Android).
  Future<void> setAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      debugPrint('SecureStorageService.setAuthToken error: $e');
    }
  }

  /// Remove the stored auth token (on sign-out).
  Future<void> clearAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
    } catch (e) {
      debugPrint('SecureStorageService.clearAuthToken error: $e');
    }
  }

  // ── Device ID ─────────────────────────────────────────────────────────────

  /// Returns a stable, cryptographically random device ID stored in the secure
  /// keystore/keychain. Generated once on first access and persisted forever.
  /// Stored in SecureStorage (not SharedPreferences) so it cannot be cleared
  /// without uninstalling the app or wiping the keystore.
  Future<String> getSecureDeviceId() async {
    try {
      String? id = await _storage.read(key: _keyDeviceId);
      if (id == null || id.isEmpty) {
        id = 'sd_${const Uuid().v4()}';
        await _storage.write(key: _keyDeviceId, value: id);
      }
      return id;
    } catch (e) {
      debugPrint('SecureStorageService.getSecureDeviceId error: $e');
      return 'sd_fallback_${const Uuid().v4()}';
    }
  }
}
