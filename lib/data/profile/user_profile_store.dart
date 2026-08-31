import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';

/// Persists the user profile settings and onboarding state across app launches.
abstract class UserProfileStore {
  Future<UserProfile> loadProfile();
  Future<void> saveProfile(UserProfile profile);
}

/// In-memory implementation of [UserProfileStore] for testing.
class InMemoryUserProfileStore implements UserProfileStore {
  InMemoryUserProfileStore({UserProfile? initial})
      : _profile = initial ?? const UserProfile();

  UserProfile _profile;

  @override
  Future<UserProfile> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }
}

/// SharedPreferences-backed implementation of [UserProfileStore] for production.
class SharedPreferencesUserProfileStore implements UserProfileStore {
  static const String _key = 'user-profile-v1';

  @override
  Future<UserProfile> loadProfile() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) {
        return const UserProfile();
      }
      final Map<String, dynamic> map = json.decode(jsonStr) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return const UserProfile();
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(profile.toJson());
      await prefs.setString(_key, jsonStr);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
