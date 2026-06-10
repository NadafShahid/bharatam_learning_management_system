import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../core/firestore_seed.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/main_shell.dart';
import '../../features/trainer/screens/trainer_shell.dart';
import '../../services/user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _hasSeenOnboardingKey = 'hasSeenOnboarding';
  late AnimationController _bgController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  bool _hasSeenOnboarding = false;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // Load onboarding state first
    final hasSeenOnboarding = await _storage.read(key: _hasSeenOnboardingKey) == 'true';
    
    // Load login state
    final isLoggedIn = await _storage.read(key: 'isLoggedIn') == 'true';
    final role = await _storage.read(key: 'role');
    final userId = await _storage.read(key: 'userId');
    if (userId != null) {
      UserService.setCachedUserId(userId);
    }

    if (!mounted) return;
    setState(() => _hasSeenOnboarding = hasSeenOnboarding);

    // If logged in, auto-redirect after a short delay to show splash animation
    if (isLoggedIn) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      
      Widget nextScreen = (role == 'trainer') ? const TrainerShell() : const MainShell();
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          settings: const RouteSettings(name: '/home'),
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
        alignment:
        Alignment.center,
          children: [
          // Animated background
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.splash),
          ),

          // Floating shapes
          ...List.generate(6, (i) => _FloatingShape(
            controller: _bgController,
            index: i,
          )),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Illustration
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.secondary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(180, 180),
                            painter: LogoPainter(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Title
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          Text(
                            'Bharatam LMS',
                            style: AppTextStyles.displayLarge.copyWith(
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ).createShader(const Rect.fromLTWH(0, 0, 250, 40)),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'A Classical Education\nfor the Future',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Start button
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.primary,
                          boxShadow: AppShadows.elevated,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(40),
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              
                              // Check persistent login state
                              const storage = FlutterSecureStorage();
                              final isLoggedIn = await storage.read(key: 'isLoggedIn');
                              final role = await storage.read(key: 'role');

                              if (!context.mounted) return;

                              Widget nextScreen;
                              if (isLoggedIn == 'true') {
                                if (role == 'trainer') {
                                  nextScreen = const TrainerShell();
                                } else {
                                  nextScreen = const MainShell();
                                }
                              } else {
                                nextScreen = _hasSeenOnboarding
                                    ? const LoginScreen()
                                    : const OnboardingScreen();
                              }

                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  settings: const RouteSettings(name: '/home'),
                                  pageBuilder: (_, __, ___) => nextScreen,
                                  transitionsBuilder: (_, animation, __, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                  transitionDuration: const Duration(milliseconds: 600),
                                ),
                              );
                            },
                            onLongPress: () async {
                              HapticFeedback.heavyImpact();
                              try {
                                await FirestoreSeed.seedAll();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Firestore DB seeded successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Seed failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Center(
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      'Start Learning',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _FloatingShape extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _FloatingShape({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final random = Random(index * 42);
    final size = 40.0 + random.nextDouble() * 80;
    final startX = random.nextDouble() * MediaQuery.of(context).size.width;
    final startY = random.nextDouble() * MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = (controller.value + index * 0.15) % 1.0;
        final dx = sin(progress * 2 * pi) * 30;
        final dy = cos(progress * 2 * pi) * 20;

        return Positioned(
          left: startX + dx,
          top: startY + dy,
          child: Opacity(
            opacity: 0.06,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: index.isEven ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: index.isOdd ? BorderRadius.circular(AppRadius.xl) : null,
                gradient: index % 3 == 0
                    ? AppGradients.primary
                    : index % 3 == 1
                        ? AppGradients.secondary
                        : AppGradients.purpleBlue,
              ),
            ),
          ),
        );
      },
    );
  }
}

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green Chevron (Left) - Sized and positioned to perfectly align
    final paintGreen = Paint()
      ..color = const Color(0xFF007A33) // Rich green representing heritage
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pathGreen = Path();
    pathGreen.moveTo(w * 0.24, h * 0.25);
    pathGreen.lineTo(w * 0.47, h * 0.50);
    pathGreen.lineTo(w * 0.24, h * 0.75);
    pathGreen.lineTo(w * 0.33, h * 0.50);
    pathGreen.close();

    // Orange Chevron (Right) - Perfect offset to create uniform white spacer
    final paintOrange = Paint()
      ..color = const Color(0xFFF89A1C) // Vibrant saffron/orange
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pathOrange = Path();
    pathOrange.moveTo(w * 0.45, h * 0.15);
    pathOrange.lineTo(w * 0.76, h * 0.50);
    pathOrange.lineTo(w * 0.45, h * 0.85);
    pathOrange.lineTo(w * 0.57, h * 0.50);
    pathOrange.close();

    canvas.drawPath(pathGreen, paintGreen);
    canvas.drawPath(pathOrange, paintOrange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
