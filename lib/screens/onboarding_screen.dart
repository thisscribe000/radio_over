import 'package:flutter/material.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../data/profile/firebase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
  });

  final PlaybackController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Interests state
  final List<String> _availableInterests = const [
    'Tech',
    'Talk',
    'Design',
    'Comedy',
    'Music',
    'News',
    'Sports',
    'Art',
    'Business',
    'Education',
    'Science',
    'History',
  ];
  final Set<String> _selectedInterests = {};

  // Form state
  final TextEditingController _nameController = TextEditingController(text: 'Connie');
  final TextEditingController _bioController = TextEditingController(
    text: "Calling me 'sir' is like putting an elevator in an outhouse, it don't belong. I'm Emmett",
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final String name = _nameController.text.trim();
    final String bio = _bioController.text.trim();
    final List<String> interests = _selectedInterests.toList();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (FirebaseService.isActive) {
      if (email.isEmpty || !email.contains('@')) {
        _showError('Please enter a valid email address.');
        return;
      }
      if (password.length < 6) {
        _showError('Password must be at least 6 characters.');
        return;
      }

      try {
        final FirebaseService firebase = FirebaseService();
        await firebase.signUp(
          email: email,
          password: password,
          username: name.isEmpty ? 'Anonymous' : name,
          bio: bio,
          interests: interests,
        );
      } catch (e) {
        _showError(e.toString());
        return;
      }
    }

    await widget.controller.updateUserProfile(
      name.isEmpty ? 'Anonymous' : name,
      bio,
      interests,
    );
    await widget.controller.completeOnboarding();
  }

  void _showError(String message) {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(side: BorderSide(color: colors.ink)),
        title: const Text('SIGN UP ERROR', style: TextStyle(fontFamily: 'Ahem', fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            child: Text('OK', style: TextStyle(color: colors.ink)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final List<String> interests = _selectedInterests.toList();
    final String bio = _bioController.text.trim();

    try {
      final FirebaseService firebase = FirebaseService();
      final userCredential = await firebase.signInWithGoogle(
        interests: interests,
        bio: bio,
      );

      if (userCredential != null) {
        final name = userCredential.user?.displayName ?? 'Google User';
        await widget.controller.updateUserProfile(
          name,
          bio,
          interests,
        );
        await widget.controller.completeOnboarding();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top branding indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RADIO OVER',
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: colors.ink,
                    ),
                  ),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? colors.podcastAccent
                              : colors.hairline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(colors),
                  _buildInterestsPage(colors),
                  _buildProfilePage(colors),
                ],
              ),
            ),
            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.hairline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      key: const ValueKey('onboarding-back'),
                      onPressed: _previousPage,
                      style: TextButton.styleFrom(foregroundColor: colors.muted),
                      child: const Text('BACK'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    key: const ValueKey('onboarding-next'),
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.ink,
                      foregroundColor: colors.background,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: Text(
                      _currentPage == 2 ? 'COMPLETE SIGN UP' : 'CONTINUE',
                      style: const TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'INDEPENDENT\nAUDIO NETWORK.',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Explore high-fidelity radio broadcasts, discover independent podcast creators, and build your custom listening library for online or offline access.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_pin_outlined, color: colors.podcastAccent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFLINE PLAYBACK FIRST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep your episodes downloaded to stream even when off-grid.',
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsPage(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WHAT INTERESTS\nYOU?',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your favorite genres to help tailor recommendations and configure your dashboard feed.',
            style: TextStyle(
              fontSize: 13,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableInterests.map((interest) {
              final bool isSelected = _selectedInterests.contains(interest);
              return GestureDetector(
                key: ValueKey('interest-chip-$interest'),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.podcastAccent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? colors.podcastAccent : colors.hairline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    interest.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colors.podcastAccent : colors.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Text(
              'SET UP YOUR\nPROFILE.',
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 32,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter a nickname and bio. This identity represents you in collections and creators you follow.',
              style: TextStyle(
                fontSize: 13,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 32),
            // Username Field
            Text(
              'NICKNAME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colors.muted,
              ),
            ),
            TextField(
              key: const ValueKey('onboarding-name-input'),
              controller: _nameController,
              cursorColor: colors.ink,
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.ink,
              ),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.hairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.ink),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 24),
            // Bio Field
            Text(
              'BIO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colors.muted,
              ),
            ),
            TextField(
              key: const ValueKey('onboarding-bio-input'),
              controller: _bioController,
              cursorColor: colors.ink,
              maxLines: 3,
              style: TextStyle(
                fontSize: 13,
                color: colors.ink,
              ),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.hairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.ink),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            if (FirebaseService.isActive) ...[
              const SizedBox(height: 24),
              Text(
                'EMAIL ADDRESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colors.muted,
                ),
              ),
              TextField(
                key: const ValueKey('onboarding-email-input'),
                controller: _emailController,
                cursorColor: colors.ink,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.ink,
                ),
                decoration: InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.hairline),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.ink),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'PASSWORD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colors.muted,
                ),
              ),
              TextField(
                key: const ValueKey('onboarding-password-input'),
                controller: _passwordController,
                obscureText: true,
                cursorColor: colors.ink,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.ink,
                ),
                decoration: InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.hairline),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.ink),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '— OR —',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('onboarding-google-signin-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.ink, width: 1.5),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _handleGoogleSignIn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.g_mobiledata, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'SIGN IN WITH GOOGLE',
                      style: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
