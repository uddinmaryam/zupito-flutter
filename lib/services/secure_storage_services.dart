import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user';
  static const _userIdKey = 'user_id';

  // Save token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Get token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Delete token
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Save user
  Future<void> saveUser(String userJson) async {
    await _storage.write(key: _userKey, value: userJson);
  }

  // Read user
  Future<String?> readUser() async {
    return await _storage.read(key: _userKey);
  }

  // Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  // Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // Delete user
  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }


}
