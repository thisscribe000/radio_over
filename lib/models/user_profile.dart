class UserProfile {
  final String username;
  final String bio;
  final List<String> interests;
  final bool isPremium;
  final bool hasCompletedOnboarding;
  final bool highQualityAudio;
  final bool enableNotifications;
  final bool newEpisodeAlerts;

  const UserProfile({
    this.username = '',
    this.bio = '',
    this.interests = const [],
    this.isPremium = false,
    this.hasCompletedOnboarding = false,
    this.highQualityAudio = true,
    this.enableNotifications = false,
    this.newEpisodeAlerts = false,
  });

  UserProfile copyWith({
    String? username,
    String? bio,
    List<String>? interests,
    bool? isPremium,
    bool? hasCompletedOnboarding,
    bool? highQualityAudio,
    bool? enableNotifications,
    bool? newEpisodeAlerts,
  }) {
    return UserProfile(
      username: username ?? this.username,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      isPremium: isPremium ?? this.isPremium,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      highQualityAudio: highQualityAudio ?? this.highQualityAudio,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      newEpisodeAlerts: newEpisodeAlerts ?? this.newEpisodeAlerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'bio': bio,
      'interests': interests,
      'isPremium': isPremium,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'highQualityAudio': highQualityAudio,
      'enableNotifications': enableNotifications,
      'newEpisodeAlerts': newEpisodeAlerts,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isPremium: json['isPremium'] as bool? ?? false,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      highQualityAudio: json['highQualityAudio'] as bool? ?? true,
      enableNotifications: json['enableNotifications'] as bool? ?? false,
      newEpisodeAlerts: json['newEpisodeAlerts'] as bool? ?? false,
    );
  }
}
