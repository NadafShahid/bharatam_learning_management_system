import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'bunny_storage_image.dart';

class CourseGridCard extends StatefulWidget {
  final String title;
  final String instructor;
  final String duration;
  final int lessons;
  final String thumbnailIcon;
  final Color thumbnailColor;
  final String? thumbnailUrl;
  final VoidCallback? onTap;
  final String? heroTag;
  final bool isCompact;

  const CourseGridCard({
    super.key,
    required this.title,
    required this.instructor,
    required this.duration,
    required this.lessons,
    this.thumbnailIcon = '📘',
    this.thumbnailColor = const Color(0xFFE8F0FE),
    this.thumbnailUrl,
    this.onTap,
    this.heroTag,
    this.isCompact = false,
  });

  @override
  State<CourseGridCard> createState() => _CourseGridCardState();
}

class _CourseGridCardState extends State<CourseGridCard>
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    final thumbnailHeight = widget.isCompact ? 95.0 : 120.0;

    // Thumbnail section — Image.network fills at any uploaded size via BoxFit.cover.
    // ClipRRect ensures image respects the card's top rounded corners.
    final thumbnailSection = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      child: SizedBox(
        width: double.infinity,
        height: thumbnailHeight,
        child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
            ? BunnyStorageImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: thumbnailHeight,
                errorBuilder: (_, __, ___) => Container(
                  color: widget.thumbnailColor,
                  child: Center(
                    child: Text(
                      widget.thumbnailIcon,
                      style: TextStyle(fontSize: widget.isCompact ? 32 : 40),
                    ),
                  ),
                ),
              )
            : Container(
                color: widget.thumbnailColor,
                child: Center(
                  child: Text(
                    widget.thumbnailIcon,
                    style: TextStyle(fontSize: widget.isCompact ? 32 : 40),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                widget.heroTag != null
                    ? Hero(tag: widget.heroTag!, child: thumbnailSection)
                    : thumbnailSection,

                Padding(
                  padding: EdgeInsets.all(widget.isCompact ? AppSpacing.sm : AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: widget.isCompact
                            ? AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.2,
                              )
                            : AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!widget.isCompact) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.instructor,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              widget.duration,
                              style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.lessons} Lec',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
