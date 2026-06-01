import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';

class PaymentSheet extends StatefulWidget {
  final String courseTitle;
  const PaymentSheet({super.key, required this.courseTitle});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  int _selectedPlan = 1;

  final _plans = [
    {'name': 'Basic', 'price': '₹499', 'duration': '1 Month', 'popular': false},
    {'name': 'Standard', 'price': '₹1,499', 'duration': '6 Months', 'popular': true},
    {'name': 'Premium', 'price': '₹2,499', 'duration': '1 Year', 'popular': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Text('Choose Plan', style: AppTextStyles.headlineMedium),
          ),
          const SizedBox(height: 6),
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Text(widget.courseTitle, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          // Plans
          ...List.generate(_plans.length, (i) {
            final p = _plans[i];
            final isSelected = _selectedPlan == i;
            final isPopular = p['popular'] as bool;
            return FadeSlideIn(
              delay: Duration(milliseconds: 200 + i * 80),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPlan = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? AppShadows.subtle : [],
                  ),
                  child: Row(children: [
                    // Radio
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.textHint, width: 2),
                      ),
                      child: AnimatedScale(
                        scale: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(p['name'] as String, style: AppTextStyles.titleMedium),
                        if (isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                            child: Text('Popular', style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      Text(p['duration'] as String, style: AppTextStyles.bodySmall),
                    ])),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: AppTextStyles.headlineSmall.copyWith(color: isSelected ? AppColors.primary : AppColors.textPrimary),
                      child: Text(p['price'] as String),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 500),
            child: GradientButton(
              text: 'Proceed to Pay ${_plans[_selectedPlan]['price']}',
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
              },
              borderRadius: AppRadius.pill,
              icon: Icons.payment_rounded,
            ),
          ),
        ]),
      ),
    );
  }
}
