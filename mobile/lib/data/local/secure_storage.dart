import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService(this._storage);

  static const String _keyAuthToken = 'auth_token';

  // Read Auth Token
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  // Save Auth Token
  Future<void> setAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  // Clear Auth Token
  Future<void> clearAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }
}
