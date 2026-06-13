import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final double? width;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final bool isLoading;
  final Color? textColor;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.width,
    this.height = 56,
    this.borderRadius = AppRadius.md,
    this.icon,
    this.isLoading = false,
    this.textColor,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    return IgnorePointer(
      ignoring: isDisabled || widget.isLoading,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: widget.gradient ?? AppGradients.primary,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: (widget.gradient != null
                                  ? AppColors.secondary
                                  : AppColors.primary)
                              .withValues(alpha: 0.25 * _elevationAnimation.value),
                          blurRadius: 20 * _elevationAnimation.value,
                          offset: Offset(0, 8 * _elevationAnimation.value),
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: child,
            ),
          ),
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            },
            onTapCancel: () => _controller.reverse(),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: widget.textColor ?? Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: AppTextStyles.button.copyWith(color: widget.textColor ?? Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
