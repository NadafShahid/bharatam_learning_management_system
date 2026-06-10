import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/status_badge.dart';
import '../../../../services/course_service.dart';
import 'admin_course_preview_screen.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final _courseService = CourseService();
  int _reloadToken = 0;
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Approvals', style: AppTextStyles.headlineLarge),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _reloadToken++);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildApprovalQueue()),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalQueue() {
    return StreamBuilder<List<CourseApprovalItem>>(
      key: ValueKey('approval_queue_$_reloadToken'),
      stream: _courseService.getCourseApprovalQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return _emptyState('No courses waiting for approval.');

        final categorySet = items
            .map((item) => item.course.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final categories = ['All', ...categorySet];
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }

        final filteredItems = _selectedCategory == 'All'
            ? items
            : items
                .where((item) => item.course.category.trim() == _selectedCategory)
                .toList();

        return RefreshIndicator(
          onRefresh: () async => setState(() => _reloadToken++),
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            children: [
              _buildSummary(items),
              const SizedBox(height: AppSpacing.lg),
              _buildCategoryFilters(categories),
              const SizedBox(height: AppSpacing.lg),
              if (filteredItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.huge),
                  child: _emptyState('No approvals in this category.'),
                )
              else
                ...List.generate(
                  filteredItems.length,
                  (index) => _buildCourseCard(filteredItems[index], index),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(List<CourseApprovalItem> items) {
    final newCourses = items.where((item) => item.needsCourseApproval).length;
    final contentUpdates = items.where((item) => item.isContentUpdate).length;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            _summaryStat(
              'New Courses',
              newCourses,
              Icons.menu_book_rounded,
              AppColors.secondary,
            ),
            Container(width: 1, height: 44, color: AppColors.divider),
            _summaryStat(
              'Content Updates',
              contentUpdates,
              Icons.video_library_rounded,
              AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(List<String> categories) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _selectedCategory;
          return ChoiceChip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            selected: selected,
            selectedColor: AppColors.primary.withValues(alpha: 0.14),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.divider,
            ),
            labelStyle: AppTextStyles.labelMedium.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = category);
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseApprovalItem item, int index) {
    final course = item.course;
    final isNewCourse = item.needsCourseApproval;
    final subtitle = isNewCourse
        ? 'New course by ${course.trainerName}'
        : 'Updated by ${course.trainerName}';

    return FadeSlideIn(
      delay: Duration(milliseconds: 200 + index * 50),
      child: _ApprovalCard(
        icon: isNewCourse
            ? Icons.menu_book_rounded
            : Icons.playlist_add_check_rounded,
        iconColor: isNewCourse ? AppColors.secondary : AppColors.primary,
        title: course.title,
        subtitle: subtitle,
        category: course.category,
        pendingVideoCount: item.pendingVideoCount,
        pendingPdfCount: item.pendingPdfCount,
        reviewLabel: isNewCourse ? 'Course approval' : 'New content approval',
        onReject: () => _rejectCourse(course.id),
        onApprove: () => _approveCourse(course.id),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AdminCoursePreviewScreen(
                course: course,
                needsCourseApproval: isNewCourse,
              ),
            ),
          );
          if (result == true && mounted) {
            setState(() => _reloadToken++);
          }
        },
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      ),
    );
  }

  Future<void> _approveCourse(String courseId) async {
    HapticFeedback.heavyImpact();
    await _courseService.approveCourse(courseId);
    _showMessage('Course review approved.');
    if (mounted) setState(() => _reloadToken++);
  }

  Future<void> _rejectCourse(String courseId) async {
    HapticFeedback.heavyImpact();
    await _courseService.rejectCourse(courseId);
    _showMessage('Course review rejected.', isError: true);
    if (mounted) setState(() => _reloadToken++);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String category;
  final int pendingVideoCount;
  final int pendingPdfCount;
  final String reviewLabel;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final VoidCallback onTap;

  const _ApprovalCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.pendingVideoCount,
    required this.pendingPdfCount,
    required this.reviewLabel,
    required this.onReject,
    required this.onApprove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.cardHover,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(icon, size: 32, color: iconColor),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  const StatusBadge(status: BadgeStatus.pending),
                                  _InfoPill(
                                    icon: Icons.category_rounded,
                                    label: category.isEmpty ? 'Uncategorized' : category,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _InfoPill(icon: Icons.fact_check_rounded, label: reviewLabel),
                          if (pendingVideoCount > 0)
                            _InfoPill(
                              icon: Icons.videocam_rounded,
                              label: '$pendingVideoCount video${pendingVideoCount == 1 ? '' : 's'}',
                            ),
                          if (pendingPdfCount > 0)
                            _InfoPill(
                              icon: Icons.picture_as_pdf_rounded,
                              label: '$pendingPdfCount PDF${pendingPdfCount == 1 ? '' : 's'}',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onReject,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: GradientButton(
                        text: 'Approve',
                        height: 44,
                        borderRadius: AppRadius.pill,
                        gradient: const LinearGradient(
                          colors: [AppColors.success, Color(0xFF059669)],
                        ),
                        onPressed: onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final maxPillWidth = math.min(
      220.0,
      math.max(120.0, MediaQuery.sizeOf(context).width - 96),
    );

    return Container(
      constraints: BoxConstraints(maxWidth: maxPillWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
