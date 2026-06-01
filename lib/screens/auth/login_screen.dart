import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../home/main_shell.dart';
import 'register_screen.dart';
import '../../features/trainer/screens/trainer_shell.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../services/user_service.dart';
import '../../services/student_learning_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  bool _showOtp = false;
  String _registeredRole = 'student'; // Default role
  String? _serverOtp;

  // Bypass Numbers
  static const String _trainerBypass = '9898989898';
  static const String _studentBypass = '9999999999';
  static const String _bypassOtp = '123456';
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    HapticFeedback.mediumImpact();
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number.')),
      );
      return;
    }

    // Bypass logic for testing
    if (phone == _trainerBypass || phone == _studentBypass) {
      _serverOtp = _bypassOtp;
      _registeredRole = (phone == _trainerBypass) ? 'trainer' : 'student';
      
      setState(() => _showOtp = true);
      _animController.reset();
      _animController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bypass Mode: Logged in as ${_registeredRole.toUpperCase()}')),
      );
      return;
    }

    final otp = (Random().nextInt(900000) + 100000).toString();
    final message = 'Your Verification Code for login is $otp. - Expertskill Technology.';
    final uri = Uri.https('mobicomm.dove-sms.com', '/submitsms.jsp', {
      'user': 'Experts',
      'key': 'ba9dcdcdfcXX',
      'mobile': phone,
      'message': message,
      'accusage': '1',
      'senderid': 'EXTSKL',
    });

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final normalizedResponse = body.toLowerCase();
      final isSuccess = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (normalizedResponse.contains('success') ||
              normalizedResponse.contains('submit_success') ||
              normalizedResponse.contains('submitted'));

      if (!mounted) return;

      if (!isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP API Error: $body')),
        );
        return;
      }

      _serverOtp = otp;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network Error. Please check internet.')),
      );
      return;
    }

    setState(() => _showOtp = true);
    _animController.reset();
    _animController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _otpFocusNodes[0].requestFocus();
    });
  }

  Future<void> _verifyOtp() async {
    HapticFeedback.heavyImpact();
    final enteredOtp = _otpControllers.map((controller) => controller.text).join();

    if (_serverOtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please send OTP first.')),
      );
      return;
    }

    if (enteredOtp.length != 6 || enteredOtp != _serverOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP! Please try again.')),
      );
      return;
    }

    // Persist login state
    const storage = FlutterSecureStorage();
    
    // Fetch actual user role and ID from DB
    String finalRole = _registeredRole;
    String finalUserId = '';
    final phone = _phoneController.text.trim();

    if (_serverOtp == _bypassOtp) {
      if (phone == _studentBypass) {
        finalUserId = 'bypass_student';
      } else if (phone == _trainerBypass) {
        finalUserId = 'bypass_trainer';
      }
    } else {
      final user = await UserService().getUserByPhone(phone);
      if (user != null) {
        finalRole = user.role;
        finalUserId = user.id;
      }
    }

    await storage.write(key: 'isLoggedIn', value: 'true');
    await storage.write(key: 'role', value: finalRole);
    await storage.write(key: 'userPhone', value: phone);
    if (finalUserId.isNotEmpty) {
      await storage.write(key: 'userId', value: finalUserId);
      UserService.setCachedUserId(finalUserId);
      // Also pre-warm the learning service cache so it never needs
      // an extra Firestore query to resolve the current student id.
      StudentLearningService.setCachedUserId(finalUserId);
    }

    if (finalRole == 'trainer') {
      _navigate(const TrainerShell());
    } else {
      _navigate(const MainShell());
    }
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Animated Logo
                  GestureDetector(
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin Mode Activated')),
                      );
                      _navigate(const AdminShell());
                    },
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.primary,
                          boxShadow: AppShadows.elevated,
                        ),
                        child: const Center(
                          child: Text('🎓', style: TextStyle(fontSize: 48)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Text('Welcome Back', style: AppTextStyles.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    child: Text(
                      _showOtp
                          ? 'Enter the 6-digit code sent to your phone'
                          : 'Sign in with your phone number',
                      key: ValueKey(_showOtp),
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.huge),

                  // Card with crossfade content
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      boxShadow: AppShadows.card,
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 400),
                      sizeCurve: Curves.easeInOutCubic,
                      firstCurve: Curves.easeOut,
                      secondCurve: Curves.easeOut,
                      crossFadeState: _showOtp ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: _buildPhoneInput(),
                      secondChild: _buildOtpInput(),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Resend
                  AnimatedOpacity(
                    opacity: _showOtp ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Didn't receive code? ", style: AppTextStyles.bodySmall),
                        TextButton(
                          onPressed: () { 
                            HapticFeedback.lightImpact();
                            for (final c in _otpControllers) { c.clear(); }
                            _sendOtp();
                          },
                          child: Text(
                            'Resend OTP',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  AnimatedOpacity(
                    opacity: _showOtp ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: AppTextStyles.bodySmall),
                        TextButton(
                          onPressed: () async {
                            if (!_showOtp) {
                              HapticFeedback.lightImpact();
                              final result = await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, _, _) => const RegisterScreen(),
                                  transitionsBuilder: (_, animation, _, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                        child: child,
                                      ),
                                    );
                                  },
                                ),
                              );
                              if (result != null && result is String) {
                                setState(() {
                                  _registeredRole = result;
                                });
                              }
                            }
                          },
                          child: Text(
                            'Sign Up',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Text(
                    'By continuing, you agree to our\nTerms of Service & Privacy Policy',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text('+91', style: AppTextStyles.titleMedium),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textHint),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: AppTextStyles.titleMedium,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        GradientButton(
          text: 'Send OTP',
          onPressed: _sendOtp,
          borderRadius: AppRadius.pill,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification Code', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
            controller: _otpControllers[i],
            focusNode: _otpFocusNodes[i],
            onChanged: (value) {
              HapticFeedback.selectionClick();
              if (value.isNotEmpty && i < 5) {
                _otpFocusNodes[i + 1].requestFocus();
              }
              if (value.isEmpty && i > 0) {
                _otpFocusNodes[i - 1].requestFocus();
              }
            },
          )),
        ),
        const SizedBox(height: AppSpacing.xxl),
        GradientButton(
          text: 'Verify & Continue',
          onPressed: _verifyOtp,
          borderRadius: AppRadius.pill,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _showOtp = false);
              _animController.reset();
              _animController.forward();
            },
            child: Text(
              'Change Phone Number',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 56,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (_, child) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: focusNode.hasFocus
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 0)]
                : [],
          ),
          child: child,
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.headlineMedium,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
