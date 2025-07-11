import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for different types of stored data
  static const _adminTokenKey =
      'admin_auth_token'; // Explicitly for admin JWT token
  static const _userAuthTokenKey =
      'user_auth_token'; // Explicitly for user JWT token
  static const _userProfileDataKey =
      'user_profile_data'; // For the full user JSON profile

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
  // This is for the JWT token received upon user login
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
  // This stores the full user object (e.g., {"_id": "...", "username": "...", "email": "..."})
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
  // This will clear all relevant keys for a full logout/reset
  Future<void> clearAllSecureData() async {
    await _storage.delete(key: _adminTokenKey);
    await _storage.delete(key: _userAuthTokenKey);
    await _storage.delete(key: _userProfileDataKey);
    // If you had any other specific keys like 'user_id', add them here too
  }

  Future readUser() async {}
}
