import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../screens/auth/login_screen.dart';
import '../../../../services/user_service.dart';
import '../../../../services/wallet_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text('Settings', style: AppTextStyles.headlineLarge),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _buildSection('Platform Settings', [
                  _buildSettingItem(Icons.percent_rounded, 'Commission Settings', '20% platform fee'),
                  FutureBuilder<double>(
                    future: WalletService().getMinWithdrawalThreshold(),
                    builder: (context, snapshot) {
                      final threshold = snapshot.data ?? 1000.0;
                      return _buildSettingItem(
                        Icons.currency_rupee_rounded,
                        'Withdrawal Threshold',
                        'Min payout limit: ₹${threshold.toInt()}',
                        onTap: () => _showThresholdConfigDialog(context, threshold),
                      );
                    },
                  ),
                  _buildSettingItem(Icons.policy_rounded, 'Content Policies', 'Update terms & conditions'),
                  _buildSettingItem(Icons.notifications_active_rounded, 'Global Notifications', 'Send alert to all users'),
                ]),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _buildSection('System', [
                  _buildSettingItem(Icons.security_rounded, 'Security & Roles', 'Manage admin access'),
                  _buildSettingItem(Icons.backup_rounded, 'Data Backup', 'Last backup: 2 days ago'),
                  _buildSettingItem(
                    Icons.logout_rounded,
                    'Logout',
                    'Sign out of admin session',
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return TapScale(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (icon == Icons.logout_rounded ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: icon == Icons.logout_rounded ? AppColors.error : AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: icon == Icons.logout_rounded ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        onTap: onTap ?? () {},
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 30),
                ),
                const SizedBox(height: 20),
                Text('Logout?', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to logout? You\'ll need to login again to access the admin dashboard.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TapScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Center(
                            child: Text('Cancel', style: AppTextStyles.titleMedium),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TapScale(
                        onTap: () async {
                          HapticFeedback.heavyImpact();
                          
                          // Clear login state
                          const storage = FlutterSecureStorage();
                          await storage.delete(key: 'isLoggedIn');
                          await storage.delete(key: 'role');
                          await storage.delete(key: 'userPhone');
                          await storage.delete(key: 'userId');
                          UserService.setCachedUserId(null);

                          if (!context.mounted) return;

                          Navigator.pop(context); // close dialog
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text('Logout', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThresholdConfigDialog(BuildContext context, double currentThreshold) {
    final controller = TextEditingController(text: currentThreshold.toInt().toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Row(
            children: [
              Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Text('Withdrawal Threshold'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the minimum wallet balance required for trainers to request a withdrawal.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Enter min limit (e.g. 1000)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a threshold';
                    }
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textHint)),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                final newVal = double.parse(controller.text);
                await WalletService().setMinWithdrawalThreshold(newVal);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Minimum withdrawal threshold updated to ₹${newVal.toInt()}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save Settings', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
