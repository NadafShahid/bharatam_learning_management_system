import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../services/student_learning_service.dart';
import 'commerce_widgets.dart';
import 'animations.dart';
import 'bunny_storage_image.dart';

/// An expandable module card that shows its videos when tapped.
class ModuleAccordion extends StatefulWidget {
  final ModuleModel module;
  final bool isUnlocked;
  final String courseId;
  final AccessControl accessControl;
  final void Function(VideoModel video) onVideoTap;
  final void Function(ModuleModel module) onBuyModule;
  final void Function(VideoModel video) onBuyVideo;

  const ModuleAccordion({
    super.key,
    required this.module,
    required this.isUnlocked,
    required this.courseId,
    required this.accessControl,
    required this.onVideoTap,
    required this.onBuyModule,
    required this.onBuyVideo,
  });

  @override
  State<ModuleAccordion> createState() => _ModuleAccordionState();
}

class _ModuleAccordionState extends State<ModuleAccordion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _iconController;
  final StudentLearningService _learningService = StudentLearningService();

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeVideos = widget.module.videos
        .where((v) => v.status == VideoStatus.active)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: _expanded
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.divider,
        ),
        boxShadow: _expanded ? AppShadows.cardHover : AppShadows.subtle,
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Module number
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: widget.isUnlocked
                          ? AppGradients.primary
                          : null,
                      color: widget.isUnlocked ? null : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.module.order}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: widget.isUnlocked
                              ? Colors.white
                              : AppColors.textHint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Title + info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.module.title,
                            style: AppTextStyles.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${activeVideos.length} videos',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  // Price / Unlocked tag
                  if (!widget.isUnlocked && widget.module.price != null)
                    PriceTag(price: widget.module.price!)
                  else if (widget.isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('Unlocked',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Expand icon
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5)
                        .animate(CurvedAnimation(
                            parent: _iconController,
                            curve: Curves.easeOutCubic)),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: AppColors.divider),
                // Buy module button (if not unlocked)
                if (!widget.isUnlocked && widget.module.price != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                    child: TapScale(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onBuyModule(widget.module);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Buy Module – ₹${widget.module.price!.toInt()}',
                              style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Video list
                ...activeVideos.map((video) {
                  final canPlay = widget.accessControl.canPlayVideo(
                    video: video,
                    courseId: widget.courseId,
                    moduleId: widget.module.id,
                  );
                  return VideoRow(
                    video: video,
                    canPlay: canPlay,
                    ratingSummary: _learningService.ratingSummary(video.id),
                    onTap: () => widget.onVideoTap(video),
                    onBuy: () => widget.onBuyVideo(video),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single video row inside a module accordion or standalone list.
class VideoRow extends StatelessWidget {
  final VideoModel video;
  final bool canPlay;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final LectureRatingSummary? ratingSummary;

  const VideoRow({super.key, 
    required this.video,
    required this.canPlay,
    required this.onTap,
    required this.onBuy,
    this.ratingSummary,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        if (canPlay) {
          onTap();
        } else {
          onBuy();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Play/Lock icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canPlay
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                image: (video.resolvedThumbnailUrl.isNotEmpty && video.contentType == CourseContentType.video)
                    ? DecorationImage(
                        image: bunnyStorageNetworkImage(video.resolvedThumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (video.resolvedThumbnailUrl.isNotEmpty && video.contentType == CourseContentType.video)
                  ? (!canPlay
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        )
                      : null)
                  : Icon(
                      !canPlay
                          ? Icons.lock_rounded
                          : (video.contentType == CourseContentType.pdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.play_circle_outline_rounded),
                      size: 18,
                      color: canPlay ? AppColors.primary : AppColors.textHint,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Title + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color:
                          canPlay ? AppColors.textPrimary : AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(video.durationFormatted, style: AppTextStyles.labelSmall),
                      if (ratingSummary != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFFFB300),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              ratingSummary!.count == 0
                                  ? 'No ratings'
                                  : '${ratingSummary!.average.toStringAsFixed(1)} (${ratingSummary!.count})',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Badges
            if (video.isFree)
              const FreeBadge()
            else if (!canPlay && video.price != null)
              PriceTag(price: video.price!),
          ],
        ),
      ),
    );
  }
}
