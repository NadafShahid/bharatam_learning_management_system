import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import 'commerce_widgets.dart';
import 'animations.dart';

import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../services/whatsapp_service.dart';
import '../screens/course_detail/course_plan_details_screen.dart';

/// A premium bottom sheet that shows pricing tiers for a course.
class PurchaseBottomSheet extends StatelessWidget {
  final CourseModel course;
  final ModuleModel? highlightModule;
  final VideoModel? highlightVideo;
  final VoidCallback? onPurchaseSuccess;

  const PurchaseBottomSheet({
    super.key,
    required this.course,
    this.highlightModule,
    this.highlightVideo,
    this.onPurchaseSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Text('Choose Your Plan', style: AppTextStyles.headlineMedium),
            ),
            const SizedBox(height: 4),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Text(
                'Unlock content that fits your learning goals',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 1. Limited Time Access Plan (1 Month)
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: PricingCard(
                label: 'Limited Time Access',
                subtitle: '30 Days full access to all ${course.totalVideos} videos',
                price: course.limitedTimePrice ?? (course.price * 0.5),
                icon: Icons.access_time_rounded,
                accentColor: AppColors.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePlanDetailsScreen(
                        course: course,
                        planType: 'limited',
                        price: course.limitedTimePrice ?? (course.price * 0.5),
                        onPurchaseSuccess: onPurchaseSuccess,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. One Time Access Plan (1 Year)
            FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: PricingCard(
                label: 'One Time Access',
                subtitle: '1 Year full access to all ${course.totalVideos} videos',
                price: course.oneTimePrice ?? course.price,
                icon: Icons.calendar_today_rounded,
                accentColor: AppColors.primary,
                isFeatured: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePlanDetailsScreen(
                        course: course,
                        planType: 'onetime',
                        price: course.oneTimePrice ?? course.price,
                        onPurchaseSuccess: onPurchaseSuccess,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Life Time Access Plan (Lifetime)
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: PricingCard(
                label: 'Life Time Access',
                subtitle: 'Forever access to all ${course.totalVideos} videos',
                price: course.lifetimePrice ?? (course.price * 1.5),
                icon: Icons.all_inclusive_rounded,
                accentColor: AppColors.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePlanDetailsScreen(
                        course: course,
                        planType: 'lifetime',
                        price: course.lifetimePrice ?? (course.price * 1.5),
                        onPurchaseSuccess: onPurchaseSuccess,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Module Options
            if (highlightModule != null) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: PricingCard(
                  label: highlightModule!.title,
                  subtitle: '${highlightModule!.videos.length} videos in this module',
                  price: highlightModule!.price ?? 0,
                  icon: Icons.folder_rounded,
                  accentColor: AppColors.primary,
                  onTap: () => _handlePurchase(
                      context, PurchaseType.module, highlightModule!.id, null),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Single Video Option
            if (highlightVideo != null && highlightVideo!.price != null) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: PricingCard(
                  label: highlightVideo!.title,
                  subtitle: 'Single video • ${highlightVideo!.durationFormatted}',
                  price: highlightVideo!.price!,
                  icon: Icons.play_circle_rounded,
                  accentColor: AppColors.info,
                  onTap: () => _handlePurchase(
                      context, PurchaseType.video, highlightModule?.id, highlightVideo!.id),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            const SizedBox(height: AppSpacing.lg),
            // Secure payment note
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded,
                      size: 14,
                      color: AppColors.success.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Secure Payment • 30-Day Refund Policy',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _handlePurchase(
      BuildContext context, PurchaseType type, String? moduleId, String? videoId, {String? planType}) async {
    HapticFeedback.heavyImpact();
    Navigator.pop(context);

    double amountPaid = 0;
    if (type == PurchaseType.course) {
      if (planType == 'limited') {
        amountPaid = course.limitedTimePrice ?? (course.price * 0.5);
      } else if (planType == 'lifetime') {
        amountPaid = course.lifetimePrice ?? (course.price * 1.5);
      } else {
        amountPaid = course.oneTimePrice ?? course.price;
      }
    } else if (type == PurchaseType.module && highlightModule != null) {
      amountPaid = highlightModule!.price ?? 0;
    } else if (type == PurchaseType.video && highlightVideo != null) {
      amountPaid = highlightVideo!.price ?? 0;
    }

    final double trainerShare = amountPaid * 0.8;
    final double platformCommission = amountPaid * 0.2;
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    try {
      final purchaseRef = await FirebaseFirestore.instance.collection('purchases').add({
        'userId': UserService().currentUserId,
        'courseId': course.id,
        'moduleId': moduleId,
        'videoId': videoId,
        'purchaseType': type.toString().split('.').last,
        'amountPaid': amountPaid,
        'trainerId': course.trainerId,
        'trainerShare': trainerShare,
        'platformCommission': platformCommission,
        'transactionId': transactionId,
        'status': 'success',
        'purchasedAt': FieldValue.serverTimestamp(),
        'planType': planType, // Securely persist plan tier
      });

      // Credit trainer share into their wallet balance
      await WalletService().creditTrainerWallet(
        purchaseId: purchaseRef.id,
        trainerId: course.trainerId,
        trainerShare: trainerShare,
        amountPaid: amountPaid,
        description: 'Earnings from ${course.title} (${type.toString().split('.').last})',
      );

      final typeLabel = switch (type) {
        PurchaseType.course => planType == 'limited'
            ? 'Limited Time Access'
            : planType == 'lifetime'
                ? 'Life Time Access'
                : 'One Time Access',
        PurchaseType.module => 'Module',
        PurchaseType.video => 'Video',
      };

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$typeLabel purchase successful!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
      
      if (onPurchaseSuccess != null) {
        onPurchaseSuccess!();
      }

      // Send WhatsApp Receipt
      WhatsAppService.sendPurchaseReceipt(
        courseTitle: course.title,
        price: amountPaid,
        transactionId: transactionId,
        planType: planType ?? type.toString().split('.').last,
        purchaseType: type.toString().split('.').last,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// A bottom sheet for trainer upload plan selection.
class TrainerUploadPlanSheet extends StatelessWidget {
  const TrainerUploadPlanSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Text('Upload Plan Required', style: AppTextStyles.headlineMedium),
            ),
            const SizedBox(height: 4),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Text(
                'You have used all 5 free uploads. Choose a plan to continue.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: PricingCard(
                label: 'Per Video Upload',
                subtitle: 'Pay per video, no commitment',
                price: 49,
                icon: Icons.videocam_rounded,
                accentColor: AppColors.info,
                onTap: () => _handlePlan(context, 'Per Video'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: PricingCard(
                label: 'Monthly Unlimited',
                subtitle: 'Unlimited uploads • Best for active trainers',
                price: 499,
                icon: Icons.all_inclusive_rounded,
                accentColor: AppColors.secondary,
                isFeatured: true,
                onTap: () => _handlePlan(context, 'Monthly Unlimited'),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded,
                      size: 14,
                      color: AppColors.success.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Cancel anytime • No hidden fees',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _handlePlan(BuildContext context, String plan) {
    HapticFeedback.heavyImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$plan plan activated! (Demo)'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
