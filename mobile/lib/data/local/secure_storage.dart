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
    return await _storage.read(key: _keyAuthToken);
  }

  /// Persist an auth token securely (Keychain on iOS, EncryptedSharedPrefs on Android).
  Future<void> setAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  /// Remove the stored auth token (on sign-out).
  Future<void> clearAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }

  // ── Device ID ─────────────────────────────────────────────────────────────

  /// Returns a stable, cryptographically random device ID stored in the secure
  /// keystore/keychain.  Generated once on first access and persisted forever.
  /// Stored in SecureStorage (not SharedPreferences) so it cannot be cleared
  /// without uninstalling the app or wiping the keystore.
  Future<String> getSecureDeviceId() async {
    String? id = await _storage.read(key: _keyDeviceId);
    if (id == null || id.isEmpty) {
      id = 'sd_${const Uuid().v4()}';
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }
}
