import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _storage = FlutterSecureStorage();
  static const _hasSeenOnboardingKey = 'hasSeenOnboarding';
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingData(
      emoji: '📖',
      title: 'Classical Knowledge',
      subtitle: 'Explore ancient wisdom through modern interactive lessons designed by expert scholars.',
      bgEmojis: ['🏛️', '🕉️', '📜'],
    ),
    _OnboardingData(
      emoji: '🎯',
      title: 'Learn at Your Pace',
      subtitle: 'Access video lectures, quizzes, and study materials anytime, anywhere on any device.',
      bgEmojis: ['⏱️', '🎧', '💡'],
    ),
    _OnboardingData(
      emoji: '🏆',
      title: 'Earn Certificates',
      subtitle: 'Complete courses and earn verified certificates to showcase your classical education.',
      bgEmojis: ['🎓', '⭐', '🎖️'],
    ),
  ];

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToLogin();
    }
  }

  Future<void> _navigateToLogin() async {
    await _storage.write(key: _hasSeenOnboardingKey, value: 'true');
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = i);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),

            // Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: AppColors.primary,
                  dotColor: AppColors.primary.withValues(alpha: 0.2),
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 4,
                  spacing: 6,
                ),
              ),
            ),

            // Button with animated text change
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxxl,
                vertical: AppSpacing.lg,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                child: GradientButton(
                  key: ValueKey(_currentPage == _pages.length - 1),
                  text: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  onPressed: _nextPage,
                  borderRadius: AppRadius.pill,
                  icon: _currentPage == _pages.length - 1
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatefulWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 30),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          children: [
            const Spacer(),
            // Illustration area with scale entrance
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.secondary.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    Text(widget.data.emoji, style: const TextStyle(fontSize: 72)),
                    ...List.generate(widget.data.bgEmojis.length, (i) {
                      final positions = [
                        const Offset(-20, -60),
                        const Offset(60, -30),
                        const Offset(-50, 40),
                      ];
                      return Positioned(
                        left: 120 + positions[i].dx,
                        top: 120 + positions[i].dy,
                        child: Text(
                          widget.data.bgEmojis[i],
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.huge),

            // Title with slide
            AnimatedBuilder(
              animation: _slideAnim,
              builder: (_, child) => Transform.translate(
                offset: _slideAnim.value,
                child: child,
              ),
              child: Column(
                children: [
                  Text(
                    widget.data.title,
                    style: AppTextStyles.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.data.subtitle,
                    style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> bgEmojis;

  const _OnboardingData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bgEmojis,
  });
}
