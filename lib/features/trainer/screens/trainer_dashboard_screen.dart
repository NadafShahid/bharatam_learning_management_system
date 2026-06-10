import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/bunny_storage_image.dart';
import '../../../../services/trainer_service.dart';
import '../../../../services/course_service.dart';
import '../../../../services/user_service.dart';
import '../../../../models/app_models.dart';
import 'package:intl/intl.dart';
import '../../../../screens/course_detail/course_detail_screen_v2.dart';
import 'package:flutter/services.dart';

class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  // Track which course IDs are currently loading to show per-item indicator
  final Set<String> _loadingCourseIds = {};

  /// Fetches the full course (with modules + videos + PDFs) and opens the
  /// student-style course detail view. The TrainerService returns lightweight
  /// CourseModel objects without sub-collections, so we re-fetch via
  /// CourseService which loads everything from Firestore sub-collections.
  Future<void> _openCoursePreview(BuildContext context, CourseModel lightCourse) async {
    HapticFeedback.mediumImpact();

    setState(() => _loadingCourseIds.add(lightCourse.id));

    try {
      // Fetch the full course with modules/videos/PDFs populated
      final allCourses = await CourseService().getCoursesByTrainer(lightCourse.trainerId);
      final fullCourse = allCourses.firstWhere(
        (c) => c.id == lightCourse.id,
        orElse: () => lightCourse, // fallback to lightweight version
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreenV2(
            course: fullCourse,
            isTrainerPreview: true,
          ),
        ),
      );
    } catch (_) {
      // On error, still open with lightweight course object
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreenV2(
            course: lightCourse,
            isTrainerPreview: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingCourseIds.remove(lightCourse.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerService = TrainerService();
    final userService = UserService();
    final trainerId = userService.currentUserId;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<TrainerStats>(
          stream: trainerService.getTrainerStatsStream(trainerId),
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting && stats == null;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xxl,
                            AppSpacing.xl,
                            AppSpacing.xxl,
                            AppSpacing.xxl,
                          ),
                          decoration: const BoxDecoration(
                            gradient: AppGradients.orangeSunset,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(AppRadius.xxl),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trainer Panel',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Dashboard',
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back, Instructor!', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Earnings',
                              isLoading ? '...' : currencyFormat.format(stats?.totalEarnings ?? 0),
                              Icons.account_balance_wallet_rounded,
                              AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: _buildStatCard(
                              'Students',
                              isLoading ? '...' : (stats?.totalStudents ?? 0).toString(),
                              Icons.people_alt_rounded,
                              AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: _buildStatCard(
                        'Total Courses',
                        isLoading ? '...' : '${stats?.totalCourses ?? 0} Active',
                        Icons.library_books_rounded,
                        AppColors.secondary,
                        isFullWidth: true,
                      ),
                    ),
                  ),
                ),

                // Recent Uploads Header
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Uploads', style: AppTextStyles.titleLarge),
                          TextButton(
                            onPressed: () {},
                            child: Text('View All', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Recent Uploads List
                if (isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                else if (stats == null || stats.recentCourses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        'No recent uploads found.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final course = stats.recentCourses[index];
                          final isItemLoading = _loadingCourseIds.contains(course.id);

                          return FadeSlideIn(
                            delay: Duration(milliseconds: 350 + (index * 80)),
                            child: TapScale(
                              onTap: isItemLoading
                                  ? null
                                  : () => _openCoursePreview(context, course),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  boxShadow: AppShadows.subtle,
                                ),
                                child: Row(
                                  children: [
                                    _buildCourseThumbnail(course),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(course.title, style: AppTextStyles.titleMedium),
                                          const SizedBox(height: 4),
                                          Text(course.category, style: AppTextStyles.bodySmall),
                                        ],
                                      ),
                                    ),
                                    // Show loader while fetching full course, else show status badge
                                    if (isItemLoading)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: course.isApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                        ),
                                        child: Text(
                                          course.isApproved ? 'Approved' : 'Pending',
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: course.isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: stats.recentCourses.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a 48×48 thumbnail for the course card in the Insights list.
  /// Shows the actual network image when thumbnailUrl is present,
  /// falls back to the course emoji, or styled initials if neither exists.
  Widget _buildCourseThumbnail(CourseModel course) {
    final hasUrl = course.thumbnailUrl.isNotEmpty;
    final hasEmoji = course.emoji.isNotEmpty;

    Widget fallback;
    if (hasEmoji) {
      fallback = Center(
        child: Text(course.emoji, style: const TextStyle(fontSize: 24)),
      );
    } else {
      final initials = course.title.isNotEmpty
          ? course.title.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
          : '?';
      fallback = Center(
        child: Text(
          initials,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.primary.withValues(alpha: 0.1),
        child: hasUrl
            ? BunnyStorageImage(
                imageUrl: course.thumbnailUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return TapScale(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  Text(value, style: AppTextStyles.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
