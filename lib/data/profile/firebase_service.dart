import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_profile.dart';

/// Service managing Firebase Authentication and Firestore database operations.
///
/// Designed to gracefully bypass operations and return simulated fallback
/// responses if Firebase Core has not been initialized.
class FirebaseService {
  static bool get isActive {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? (isActive ? FirebaseAuth.instance : null) as dynamic,
        _firestore = firestore ?? (isActive ? FirebaseFirestore.instance : null) as dynamic;

  /// Returns current user ID if logged in.
  String? get currentUid {
    if (!isActive) return null;
    return _auth.currentUser?.uid;
  }

  /// Registers a new user with email and password, then creates their Firestore profile.
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String username,
    required String bio,
    required List<String> interests,
  }) async {
    if (!isActive) return null;

    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final User? user = credential.user;
    if (user != null) {
      await saveCloudProfile(
        uid: user.uid,
        profile: UserProfile(
          username: username,
          bio: bio,
          interests: interests,
          hasCompletedOnboarding: true,
        ),
      );
    }
    return credential;
  }

  /// Authenticates using Google Sign-In and links credential to Firebase.
  Future<UserCredential?> signInWithGoogle({
    required List<String> interests,
    String? bio,
  }) async {
    if (!isActive) return null;

    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      final existingProfile = await fetchCloudProfile(user.uid);
      if (existingProfile == null) {
        await saveCloudProfile(
          uid: user.uid,
          profile: UserProfile(
            username: user.displayName ?? 'Google User',
            bio: bio ?? '',
            interests: interests,
            hasCompletedOnboarding: true,
          ),
        );
      }
    }
    return userCredential;
  }

  /// Logs in an existing user with email and password.
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isActive) return null;
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    if (!isActive) return;
    await _auth.signOut();
  }

  /// Stores profile state under the Firestore /users/{uid} document.
  Future<void> saveCloudProfile({
    required String uid,
    required UserProfile profile,
  }) async {
    if (!isActive) return;
    await _firestore.collection('users').doc(uid).set({
      'username': profile.username,
      'bio': profile.bio,
      'interests': profile.interests,
      'isPremium': profile.isPremium,
      'hasCompletedOnboarding': profile.hasCompletedOnboarding,
      'highQualityAudio': profile.highQualityAudio,
      'enableNotifications': profile.enableNotifications,
      'newEpisodeAlerts': profile.newEpisodeAlerts,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches profile state from Firestore.
  Future<UserProfile?> fetchCloudProfile(String uid) async {
    if (!isActive) return null;
    final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      username: data['username'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      interests: (data['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isPremium: data['isPremium'] as bool? ?? false,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      highQualityAudio: data['highQualityAudio'] as bool? ?? true,
      enableNotifications: data['enableNotifications'] as bool? ?? false,
      newEpisodeAlerts: data['newEpisodeAlerts'] as bool? ?? false,
    );
  }
}
