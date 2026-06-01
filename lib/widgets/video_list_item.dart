import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class VideoListItem extends StatefulWidget {
  final String title;
  final String duration;
  final int index;
  final bool isLocked;
  final bool isPlaying;
  final VoidCallback? onTap;

  const VideoListItem({
    super.key,
    required this.title,
    required this.duration,
    required this.index,
    this.isLocked = false,
    this.isPlaying = false,
    this.onTap,
  });

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem>
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
    return GestureDetector(
      onTapDown: widget.isLocked ? null : (_) => _tapController.forward(),
      onTapUp: widget.isLocked ? null : (_) {
        _tapController.reverse();
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapCancel: () => _tapController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: widget.isPlaying ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
              width: widget.isPlaying ? 1.5 : 1,
            ),
            boxShadow: widget.isPlaying ? AppShadows.subtle : [],
          ),
          child: Row(
            children: [
              // Number / Playing indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isPlaying
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    child: widget.isPlaying
                        ? const Icon(Icons.play_arrow_rounded, key: ValueKey('play'), color: Colors.white, size: 18)
                        : Text(
                            '${widget.index + 1}',
                            key: ValueKey('num_${widget.index}'),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title & Duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: widget.isLocked ? AppColors.textHint : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(widget.duration, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              // Lock / Play icon
              if (widget.isLocked)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.lock_rounded, size: 16, color: AppColors.textHint),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    widget.isPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
                    key: ValueKey(widget.isPlaying),
                    color: widget.isPlaying ? AppColors.primary : AppColors.textHint,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
