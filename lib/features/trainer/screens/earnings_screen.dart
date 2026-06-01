import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../services/trainer_service.dart';
import '../../../../services/user_service.dart';
import '../../../../models/app_models.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trainerService = TrainerService();
    final userService = UserService();
    final trainerId = userService.currentUserId;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<TrainerStats>(
          stream: trainerService.getTrainerStatsStream(trainerId),
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting && stats == null;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text('Earnings', style: AppTextStyles.headlineLarge),
                    ),
                  ),
                ),
                
                // Total Earnings Card
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                          boxShadow: AppShadows.elevated,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Balance', style: AppTextStyles.labelMedium.copyWith(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              isLoading ? '...' : currencyFormat.format(stats?.totalEarnings ?? 0), 
                              style: AppTextStyles.displayLarge.copyWith(color: Colors.white)
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            GradientButton(
                              text: 'Withdraw Funds',
                              icon: Icons.account_balance_rounded,
                              gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
                              onPressed: () => HapticFeedback.heavyImpact(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // History
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                      child: Text('Transaction History', style: AppTextStyles.titleLarge),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final purchase = stats!.recentPurchases[index];
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 450 + (index * 50)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              boxShadow: AppShadows.subtle,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        purchase.purchaseType == PurchaseType.course ? 'Course Purchase' : 
                                        purchase.purchaseType == PurchaseType.module ? 'Module Purchase' : 'Video Purchase', 
                                        style: AppTextStyles.titleMedium
                                      ),
                                      Text('Trx ID: ${purchase.transactionId}', style: AppTextStyles.labelSmall),
                                    ],
                                  ),
                                ),
                                Text('+${currencyFormat.format(purchase.trainerShare)}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success)),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: stats?.recentPurchases.length ?? 0,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
              ],
            );
          },
        ),
      ),
    );
  }
}
