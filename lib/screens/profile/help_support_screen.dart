import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../../core/localization.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(T.get('help_support'), style: AppTextStyles.headlineSmall),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Support Banner
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppGradients.purpleBlue,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  boxShadow: AppShadows.elevated,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.support_agent_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(T.get('how_can_we_help'), style: AppTextStyles.headlineMedium.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      T.get('here_to_assist'),
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // FAQ Section
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Text(T.get('faqs'), style: AppTextStyles.titleLarge),
            ),
            const SizedBox(height: 12),
            ..._buildFAQs(),

            const SizedBox(height: 28),

            // Contact Section
            FadeSlideIn(
              delay: const Duration(milliseconds: 500),
              child: Text(T.get('contact_us'), style: AppTextStyles.titleLarge),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 550),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  children: [
                    _buildContactTile(Icons.email_outlined, T.get('email_support'), 'support@bharatamlms.com'),
                    Divider(height: 1, color: AppColors.divider),
                    _buildContactTile(Icons.phone_outlined, T.get('call_us'), '+91 1800-XXX-XXXX'),
                    Divider(height: 1, color: AppColors.divider),
                    _buildContactTile(Icons.chat_bubble_outline_rounded, T.get('whatsapp'), '+91 98765 43210'),
                  ],
                ),
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

  List<Widget> _buildFAQs() {
    final faqs = [
      {'q': T.get('faq_q1'), 'a': T.get('faq_a1')},
      {'q': T.get('faq_q2'), 'a': T.get('faq_a2')},
      {'q': T.get('faq_q3'), 'a': T.get('faq_a3')},
      {'q': T.get('faq_q4'), 'a': T.get('faq_a4')},
    ];

    return faqs.asMap().entries.map((entry) {
      final i = entry.key;
      final faq = entry.value;
      return FadeSlideIn(
        delay: Duration(milliseconds: 250 + i * 60),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.subtle,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 18),
            ),
            title: Text(faq['q']!, style: AppTextStyles.titleMedium),
            children: [
              Text(faq['a']!, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildContactTile(IconData icon, String title, String subtitle) {
    return TapScale(
      onTap: () => HapticFeedback.lightImpact(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.info, size: 20),
        ),
        title: Text(title, style: AppTextStyles.titleMedium),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
      ),
    );
  }
}
