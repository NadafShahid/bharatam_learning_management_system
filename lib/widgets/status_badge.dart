import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum BadgeStatus { pending, approved, rejected, active, blocked }

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case BadgeStatus.pending:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
      case BadgeStatus.approved:
      case BadgeStatus.active:
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF10B981);
        label = status == BadgeStatus.active ? 'Active' : 'Approved';
        break;
      case BadgeStatus.rejected:
      case BadgeStatus.blocked:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFEF4444);
        label = status == BadgeStatus.blocked ? 'Blocked' : 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
