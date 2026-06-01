import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'gradient_button.dart';
import 'animations.dart';

/// A premium pricing card used for course/module/video purchase options.
class PricingCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final double price;
  final IconData icon;
  final Color accentColor;
  final bool isFeatured;
  final VoidCallback onTap;

  const PricingCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.price,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.isFeatured = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isFeatured ? accentColor : AppColors.divider,
            width: isFeatured ? 2 : 1,
          ),
          boxShadow: isFeatured ? AppShadows.cardHover : AppShadows.subtle,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label, style: AppTextStyles.titleMedium),
                      ),
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('BEST VALUE',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '₹${price.toInt()}',
              style: AppTextStyles.headlineSmall.copyWith(color: accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lock overlay shown on top of locked content.
class LockOverlay extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const LockOverlay({
    super.key,
    required this.onTap,
    this.label = 'Unlock',
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(label,
                    style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An upgrade plan card with gradient CTA.
class UpgradePlanCard extends StatelessWidget {
  final String title;
  final String description;
  final String ctaText;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const UpgradePlanCard({
    super.key,
    required this.title,
    required this.description,
    required this.ctaText,
    this.icon = Icons.rocket_launch_rounded,
    this.gradient = const LinearGradient(
      colors: [Color(0xFFFF6A3D), Color(0xFFFF8A65)],
    ),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(description,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
          const SizedBox(height: AppSpacing.xl),
          GradientButton(
            text: ctaText,
            gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// A free badge shown on free videos.
class FreeBadge extends StatelessWidget {
  const FreeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Text('FREE',
          style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 9)),
    );
  }
}

/// A price tag shown on paid videos/modules.
class PriceTag extends StatelessWidget {
  final double price;
  const PriceTag({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('₹${price.toInt()}',
          style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }
}
