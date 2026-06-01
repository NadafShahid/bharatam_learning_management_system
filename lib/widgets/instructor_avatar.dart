import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InstructorAvatarList extends StatelessWidget {
  final List<InstructorData> instructors;
  final Function(InstructorData)? onTap;

  const InstructorAvatarList({super.key, required this.instructors, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        itemCount: instructors.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, index) {
          final instructor = instructors[index];
          return _InstructorAvatar(
            data: instructor,
            onTap: () => onTap?.call(instructor),
          );
        },
      ),
    );
  }
}

class _InstructorAvatar extends StatelessWidget {
  final InstructorData data;
  final VoidCallback? onTap;

  const _InstructorAvatar({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: data.imageUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            data.imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              data.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        )
                      : Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              data.name,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class InstructorData {
  final String id;
  final String name;
  final String emoji;
  final String imageUrl;
  final double rating;

  const InstructorData({
    required this.id,
    required this.name,
    required this.emoji,
    this.imageUrl = '',
    this.rating = 0.0,
  });
}
