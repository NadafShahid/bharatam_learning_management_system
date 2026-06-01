import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  
  bool _isTrainer = false;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    HapticFeedback.heavyImpact();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid name and 10-digit phone number.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if phone number already exists in the unified bharatam_users collection
      final unifiedQuery = await FirebaseFirestore.instance
          .collection('bharatam_users')
          .where('phoneNumber', isEqualTo: phone)
          .get();

      bool exists = unifiedQuery.docs.isNotEmpty;

      if (!exists) {
        // Fallback check in legacy collections for old accounts
        final learnerQuery = await FirebaseFirestore.instance
            .collection('learners')
            .where('phoneNumber', isEqualTo: phone)
            .get();
            
        final trainerQuery = await FirebaseFirestore.instance
            .collection('trainers')
            .where('phoneNumber', isEqualTo: phone)
            .get();

        if (learnerQuery.docs.isNotEmpty || trainerQuery.docs.isNotEmpty) {
          exists = true;
        }
      }

      if (exists) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account with this phone number already exists!')),
        );
        return;
      }

      final role = _isTrainer ? 'trainer' : 'student';
      
      // Save to unified collection 'bharatam_users'
      final unifiedDocRef = FirebaseFirestore.instance.collection('bharatam_users').doc();
      final userId = unifiedDocRef.id;

      final userData = {
        'name': name,
        'phoneNumber': phone,
        'role': role,
        'profileImageUrl': '',
        'isBlocked': false,
        'preferredLanguage': 'en',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await unifiedDocRef.set(userData);

      // Write to legacy collections for seamless backward compatibility
      if (_isTrainer) {
        await FirebaseFirestore.instance.collection('trainers').doc(userId).set(userData);
        await FirebaseFirestore.instance.collection('bharatam_trainers').doc(userId).set(userData);
      } else {
        await FirebaseFirestore.instance.collection('learners').doc(userId).set(userData);
      }

      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.')),
      );
      
      Navigator.pop(context, role); // Go back to login and pass role
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
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
                  const SizedBox(height: 20),

                  // Animated Logo
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.primary,
                        boxShadow: AppShadows.elevated,
                      ),
                      child: const Center(
                        child: Text('📝', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text('Create Account', style: AppTextStyles.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Join Bharatam LMS today',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Full Name'),
                        _buildTextField(hint: 'Enter your full name', icon: Icons.person_outline_rounded, controller: _nameController),
                        const SizedBox(height: AppSpacing.lg),
                        
                        _buildLabel('Phone Number'),
                        _buildTextField(hint: 'Enter phone number', icon: Icons.phone_outlined, isPhone: true, controller: _phoneController),
                        const SizedBox(height: AppSpacing.xxl),

                        _buildLabel('I want to register as a:'),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: _buildRoleCard('Learner', '👨‍🎓', !_isTrainer, () => setState(() => _isTrainer = false))),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: _buildRoleCard('Trainer', '👨‍🏫', _isTrainer, () => setState(() => _isTrainer = true))),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : GradientButton(
                                text: 'Sign Up',
                                onPressed: _registerUser,
                                borderRadius: AppRadius.pill,
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: AppTextStyles.bodySmall),
                      TextButton(
                        onPressed: () { 
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.labelLarge),
    );
  }

  Widget _buildTextField({required String hint, required IconData icon, bool isPhone = false, required TextEditingController controller}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isPhone 
              ? Row(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text('+91', style: AppTextStyles.titleMedium),
                  ],
                )
              : Icon(icon, color: AppColors.textHint, size: 20),
          ),
          Container(width: 1, height: 24, color: AppColors.border),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isPhone ? TextInputType.phone : TextInputType.name,
              inputFormatters: isPhone ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ] : null,
              style: AppTextStyles.titleMedium,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String title, String emoji, bool isSelected, VoidCallback onTap) {
    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

