import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../../core/localization.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _coursePush = true;
  bool _promotions = false;
  bool _newVideos = true;
  bool _reminders = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(T.get('notifications'), style: AppTextStyles.headlineSmall),
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
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      boxShadow: AppShadows.elevated,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(T.get('stay_updated'), style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(T.get('manage_notif_pref'), style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Text(T.get('push_notifications'), style: AppTextStyles.titleLarge),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Column(
                      children: [
                        _buildToggle(T.get('course_updates'), T.get('get_notif_enrolled_courses'), Icons.menu_book_rounded, _coursePush, (v) => setState(() => _coursePush = v)),
                        Divider(height: 1, color: AppColors.divider),
                        _buildToggle(T.get('new_videos'), T.get('new_videos_desc'), Icons.video_library_rounded, _newVideos, (v) => setState(() => _newVideos = v)),
                        Divider(height: 1, color: AppColors.divider),
                        _buildToggle(T.get('study_reminders'), T.get('study_reminders_desc'), Icons.alarm_rounded, _reminders, (v) => setState(() => _reminders = v)),
                        Divider(height: 1, color: AppColors.divider),
                        _buildToggle(T.get('promotions_offers'), T.get('promotions_offers_desc'), Icons.local_offer_rounded, _promotions, (v) => setState(() => _promotions = v)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggle(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.titleMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: Switch.adaptive(
        value: value,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        activeColor: AppColors.primary,
      ),
    );
  }
}
