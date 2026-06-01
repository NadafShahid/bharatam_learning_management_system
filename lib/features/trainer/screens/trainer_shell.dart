import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';
import 'trainer_dashboard_screen.dart';
import 'trainer_courses_screen.dart';
import 'video_upload_screen.dart';
import 'earnings_screen.dart';
import 'trainer_profile_screen.dart';

class TrainerShell extends StatefulWidget {
  const TrainerShell({super.key});

  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  final _screens = const [
    TrainerDashboardScreen(),
    TrainerCoursesScreen(),
    EarningsScreen(),
    TrainerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isForward = _currentIndex > _previousIndex;
          final slideIn = Tween<Offset>(
            begin: Offset(isForward ? 0.05 : -0.05, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideIn, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: AppShadows.bottomNav,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.analytics_rounded, 'HOme'),
                _buildNavItem(1, Icons.auto_stories_rounded, 'Course'),
                _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Revenue'),
                _buildNavItem(3, Icons.account_circle_rounded, 'profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index != _currentIndex) {
          HapticFeedback.selectionClick();
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
