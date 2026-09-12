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
        _showError('INVALID EMAIL ADDRESS.');
        return;
      }
      if (password.length < 6) {
        _showError('PASSWORD MUST BE AT LEAST 6 CHARACTERS.');
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
        _showError(e.toString().toUpperCase());
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: colors.ink, width: 1.5),
        ),
        title: Text(
          'SIGN UP ERROR',
          style: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 16,
            color: colors.ink,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 12, color: colors.ink, fontFamily: 'Ahem'),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.background,
              backgroundColor: colors.ink,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              side: BorderSide(color: colors.ink, width: 1),
            ),
            child: const Text('OK', style: TextStyle(fontFamily: 'Ahem', fontSize: 12)),
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
      _showError(e.toString().toUpperCase());
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
                  Row(
                    children: [
                      Image.asset(
                        'assets/icon/splash_logo.png',
                        width: 24,
                        height: 24,
                        color: colors.ink,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'RADIO OVER',
                        style: TextStyle(
                          fontFamily: 'Ahem',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 12,
                        height: 2,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: _currentPage >= index ? colors.ink : colors.hairline,
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
                border: Border(top: BorderSide(color: colors.ink, width: 1.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      key: const ValueKey('onboarding-back'),
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.ink,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        side: BorderSide(color: colors.ink, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(fontFamily: 'Ahem', fontSize: 12),
                      ),
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
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: Text(
                      _currentPage == 2 ? 'COMPLETE' : 'CONTINUE',
                      style: const TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: 12,
                        letterSpacing: 1.5,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.ink, width: 1.5),
            ),
            child: Text(
              'CHAPTER I',
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 10,
                color: colors.ink,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'INDEPENDENT\nAUDIO\nNETWORK.',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 36,
              height: 1.2,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Explore high-fidelity radio broadcasts, discover independent podcast creators, and build your custom listening library for online or offline access.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.ink, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.download, color: colors.ink, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFLINE PLAYBACK FIRST',
                        style: TextStyle(
                          fontFamily: 'Ahem',
                          fontSize: 10,
                          color: colors.ink,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your episodes downloaded to stream even when off-grid.',
                        style: TextStyle(fontSize: 12, color: colors.ink),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.ink, width: 1.5),
            ),
            child: Text(
              'CHAPTER II',
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 10,
                color: colors.ink,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'WHAT\nINTERESTS\nYOU?',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 36,
              height: 1.2,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select your favorite genres to help tailor recommendations.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                    color: isSelected ? colors.ink : colors.background,
                    border: Border.all(
                      color: colors.ink,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    interest.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 10,
                      color: isSelected ? colors.background : colors.ink,
                      letterSpacing: 1.0,
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
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: colors.ink, width: 1.5),
              ),
              child: Text(
                'CHAPTER III',
                style: TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 10,
                  color: colors.ink,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SET UP YOUR\nPROFILE.',
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 36,
                height: 1.2,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 32),
            _buildEditorialTextField(
              'NICKNAME',
              _nameController,
              colors,
              key: const ValueKey('onboarding-name-input'),
            ),
            const SizedBox(height: 24),
            _buildEditorialTextField(
              'BIO',
              _bioController,
              colors,
              maxLines: 3,
              key: const ValueKey('onboarding-bio-input'),
            ),
            if (FirebaseService.isActive) ...[
              const SizedBox(height: 24),
              _buildEditorialTextField(
                'EMAIL ADDRESS',
                _emailController,
                colors,
                key: const ValueKey('onboarding-email-input'),
              ),
              const SizedBox(height: 24),
              _buildEditorialTextField(
                'PASSWORD',
                _passwordController,
                colors,
                obscureText: true,
                key: const ValueKey('onboarding-password-input'),
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                key: const ValueKey('onboarding-google-signin-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.ink, width: 1.5),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: _handleGoogleSignIn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SIGN IN WITH GOOGLE',
                      style: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialTextField(
    String label,
    TextEditingController controller,
    AppColors colors, {
    int maxLines = 1,
    bool obscureText = false,
    Key? key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Ahem',
            fontSize: 10,
            letterSpacing: 2.0,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.ink, width: 1.5),
          ),
          child: TextField(
            key: key,
            controller: controller,
            cursorColor: colors.ink,
            obscureText: obscureText,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              color: colors.ink,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
