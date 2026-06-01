import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../../core/localization.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(T.get('about'), style: AppTextStyles.headlineSmall),
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
            // App Logo & Title
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 100, height: 100,
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
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Text('Bharatam LMS', style: AppTextStyles.headlineLarge),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Text('Version 1.0.0', style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: 32),

            // About the App
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _buildSection(
                T.get('about_app_title'),
                Icons.info_outline_rounded,
                T.get('about_app_desc'),
              ),
            ),
            const SizedBox(height: 20),

            // How to Use
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: _buildSection(
                T.get('how_to_use'),
                Icons.play_circle_outline_rounded,
                null,
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 430),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  children: [
                    _buildStep(1, T.get('browse_courses_step'), T.get('browse_courses_desc')),
                    Divider(height: 1, color: AppColors.divider),
                    _buildStep(2, T.get('purchase_content_step'), T.get('purchase_content_desc')),
                    Divider(height: 1, color: AppColors.divider),
                    _buildStep(3, T.get('watch_learn_step'), T.get('watch_learn_desc')),
                    Divider(height: 1, color: AppColors.divider),
                    _buildStep(4, T.get('earn_certificate_step'), T.get('earn_certificate_desc')),
                  ],
                ),
              ),
            ),

            // Features
            FadeSlideIn(
              delay: const Duration(milliseconds: 500),
              child: _buildSection(T.get('key_features'), Icons.star_rounded, null),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 530),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.subtle,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFeature(Icons.video_library_rounded, T.get('hd_video'), AppColors.primary),
                    const SizedBox(height: 16),
                    _buildFeature(Icons.workspace_premium_rounded, T.get('verified_certs'), const Color(0xFFFFD700)),
                    const SizedBox(height: 16),
                    _buildFeature(Icons.language_rounded, T.get('multi_lang'), AppColors.info),
                    const SizedBox(height: 16),
                    _buildFeature(Icons.lock_rounded, T.get('secure_content'), AppColors.success),
                    const SizedBox(height: 16),
                    _buildFeature(Icons.dark_mode_rounded, T.get('dark_mode'), AppColors.secondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            FadeSlideIn(
              delay: const Duration(milliseconds: 600),
              child: Column(
                children: [
                  Text(T.get('made_with_love'), style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(T.get('copyright'), style: AppTextStyles.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildSection(String title, IconData icon, String? description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleLarge),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.subtle,
            ),
            child: Text(description, style: AppTextStyles.bodyMedium.copyWith(height: 1.7)),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
      title: Text(title, style: AppTextStyles.titleMedium),
      subtitle: Text(description, style: AppTextStyles.bodySmall),
    );
  }

  Widget _buildFeature(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 16),
        Text(title, style: AppTextStyles.titleMedium),
      ],
    );
  }
}
