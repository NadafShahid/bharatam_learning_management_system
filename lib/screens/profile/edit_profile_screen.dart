import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';
import '../../services/user_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/localization.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final user = await UserService().getUserByPhone(phone);
        if (mounted && user != null) {
          setState(() {
            _nameController.text = user.name;
            _phoneController.text = '+91 ${user.phoneNumber}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(T.get('edit_profile'), style: AppTextStyles.headlineSmall),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar with edit button
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppGradients.primary,
                            boxShadow: AppShadows.elevated,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                              ),
                              child: const Center(
                                child: Text('🧑‍🎓', style: TextStyle(fontSize: 44)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: TapScale(
                            onTap: () => HapticFeedback.mediumImpact(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: AppGradients.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 3),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form fields
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: _buildField(T.get('full_name'), _nameController, Icons.person_outline_rounded),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 260),
                  child: _buildField(T.get('phone_number'), _phoneController, Icons.phone_outlined, readOnly: true),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: _buildField(T.get('email_optional'), _emailController, Icons.email_outlined),
                ),

                const SizedBox(height: 48),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: GradientButton(
                    text: T.get('save_changes'),
                    borderRadius: AppRadius.pill,
                    icon: Icons.check_rounded,
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(T.get('profile_updated')),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.subtle,
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: AppTextStyles.titleMedium,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: readOnly ? AppColors.textHint : AppColors.primary, size: 20),
              suffixIcon: readOnly
                  ? Icon(Icons.lock_outline_rounded, color: AppColors.textHint, size: 16)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
