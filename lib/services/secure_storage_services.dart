import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Consistent Keys
  static const _adminTokenKey = 'admin_token'; // Admin JWT token
  static const _userAuthTokenKey = 'user_auth_token'; // User JWT token
  static const _userProfileDataKey = 'user_profile_data'; // User profile JSON

  // --- Admin Token Methods ---

  Future<void> writeAdminToken(String token) async {
    await _storage.write(key: _adminTokenKey, value: token);
  }

  Future<String?> readAdminToken() async {
    return await _storage.read(key: _adminTokenKey);
  }

  Future<void> deleteAdminToken() async {
    await _storage.delete(key: _adminTokenKey);
  }

  // --- User Authentication Token Methods ---

  Future<void> writeUserAuthToken(String token) async {
    await _storage.write(key: _userAuthTokenKey, value: token);
  }

  Future<String?> readUserAuthToken() async {
    return await _storage.read(key: _userAuthTokenKey);
  }

  Future<void> deleteUserAuthToken() async {
    await _storage.delete(key: _userAuthTokenKey);
  }

  // --- User Profile Data Methods (the full user JSON) ---

  Future<void> writeUserProfile(String userJson) async {
    await _storage.write(key: _userProfileDataKey, value: userJson);
  }

  Future<String?> readUserProfile() async {
    return await _storage.read(key: _userProfileDataKey);
  }

  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _userProfileDataKey);
  }

  // --- General Clear Method ---
  /// Use this to clear ALL relevant secure storage (on logout/reset)
  Future<void> clearAllSecureData() async {
    await _storage.delete(key: _adminTokenKey);
    await _storage.delete(key: _userAuthTokenKey);
    await _storage.delete(key: _userProfileDataKey);
    // Add more deletes here if you add more secure keys
  }

  // --- (Optional) One-time migration/cleanup for old keys ---
  /// Call this once if you had previously used wrong keys
  Future<void> cleanupOldKeys() async {
    await _storage.delete(key: 'admin_auth_token');
    // Add any other old/legacy keys here if needed
  }

  Future readUser() async {}
}
