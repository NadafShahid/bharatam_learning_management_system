import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CourseCard extends StatefulWidget {
  final String title;
  final String instructor;
  final String duration;
  final int lessons;
  final String thumbnailIcon;
  final Color thumbnailColor;
  final String? thumbnailUrl;
  final double? progress;
  final VoidCallback? onTap;
  final bool showProgress;
  final String? heroTag;
  final bool isCompact;

  const CourseCard({
    super.key,
    required this.title,
    required this.instructor,
    required this.duration,
    required this.lessons,
    this.thumbnailIcon = '📘',
    this.thumbnailColor = const Color(0xFFE8F0FE),
    this.thumbnailUrl,
    this.progress,
    this.onTap,
    this.showProgress = false,
    this.heroTag,
    this.isCompact = false,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailSize = widget.isCompact ? 70.0 : 80.0;

    // Build thumbnail — uses Image.network for proper BoxFit.cover
    // at any uploaded image size, wrapped in ClipRRect for rounded corners
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: thumbnailSize,
        height: thumbnailSize,
        child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
            ? Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: thumbnailSize,
                height: thumbnailSize,
                errorBuilder: (_, __, ___) => Container(
                  color: widget.thumbnailColor,
                  child: Center(
                    child: Text(
                      widget.thumbnailIcon,
                      style: TextStyle(fontSize: widget.isCompact ? 30 : 36),
                    ),
                  ),
                ),
              )
            : Container(
                color: widget.thumbnailColor,
                child: Center(
                  child: Text(
                    widget.thumbnailIcon,
                    style: TextStyle(fontSize: widget.isCompact ? 30 : 36),
                  ),
                ),
              ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapCancel: () => _tapController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(bottom: widget.isCompact ? AppSpacing.sm : AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(widget.isCompact ? AppRadius.lg : AppRadius.xl),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isCompact ? AppSpacing.md : AppSpacing.lg),
            child: Row(
              children: [
                // Thumbnail with optional Hero
                widget.heroTag != null
                    ? Hero(
                        tag: widget.heroTag!,
                        child: thumbnail,
                      )
                    : thumbnail,
                const SizedBox(width: AppSpacing.md),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: widget.isCompact
                            ? AppTextStyles.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold)
                            : AppTextStyles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!widget.isCompact) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.instructor,
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text(widget.duration, style: AppTextStyles.labelSmall),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text('${widget.lessons} lessons', style: AppTextStyles.labelSmall),
                              ],
                            ),
                          ],
                        ),
                        if (widget.showProgress && widget.progress != null) ...[
                          const SizedBox(height: 10),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: widget.progress!),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: AppColors.background,
                                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(widget.progress! * 100).toInt()}% completed',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                // Arrow
                if (!widget.showProgress && !widget.isCompact)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
