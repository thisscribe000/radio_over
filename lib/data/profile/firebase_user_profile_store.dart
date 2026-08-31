import '../../models/user_profile.dart';
import 'user_profile_store.dart';
import 'firebase_service.dart';

/// Decorator store that saves user profiles locally first (via SharedPreferences),
/// then attempts to sync changes to Firebase Firestore if authentication is active.
class FirebaseUserProfileStore implements UserProfileStore {
  FirebaseUserProfileStore({
    required UserProfileStore localStore,
    required FirebaseService firebaseService,
  })  : _local = localStore,
        _firebase = firebaseService;

  final UserProfileStore _local;
  final FirebaseService _firebase;

  @override
  Future<UserProfile> loadProfile() async {
    // Always start with the local cached profile
    var profile = await _local.loadProfile();

    if (FirebaseService.isActive) {
      final String? uid = _firebase.currentUid;
      if (uid != null) {
        try {
          final cloudProfile = await _firebase.fetchCloudProfile(uid);
          if (cloudProfile != null) {
            profile = cloudProfile;
            // Update local cache with fetched cloud profile
            await _local.saveProfile(profile);
          }
        } catch (_) {
          // Fall back gracefully to local cache if network/fetch fails
        }
      }
    }
    return profile;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    // 1. Always save locally first
    await _local.saveProfile(profile);

    // 2. If authenticated and active, sync to Firestore
    if (FirebaseService.isActive) {
      final String? uid = _firebase.currentUid;
      if (uid != null) {
        try {
          await _firebase.saveCloudProfile(uid: uid, profile: profile);
        } catch (_) {
          // Graceful fallback for offline save mutations
        }
      }
    }
  }
}
