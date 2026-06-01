import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/course_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';
import '../certificate/certificate_screen.dart';
import '../../services/user_service.dart';
import '../../services/student_learning_service.dart';
import '../../services/course_service.dart';
import '../../models/app_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../course_detail/course_detail_screen_v2.dart';
import '../../core/localization.dart';

class MyCoursesScreen extends StatefulWidget {
  /// When true, shows only completed courses (used from "Completed Courses" drawer item).
  /// When false (default), shows only in-progress courses under "Progress Courses" heading.
  final bool showOnlyCompleted;

  // Keep initialTabIndex for backward compat — treated as showOnlyCompleted = (index == 1)
  final int initialTabIndex;

  const MyCoursesScreen({
    super.key,
    this.showOnlyCompleted = false,
    this.initialTabIndex = 0,
  });

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen>
    with AutomaticKeepAliveClientMixin {
  final _courseService = CourseService();
  final _userService = UserService();
  final _learningService = StudentLearningService();

  List<CourseModel> _purchasedInProgress = [];
  List<CourseModel> _purchasedCompleted = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  bool get _isCompletedView =>
      widget.showOnlyCompleted || widget.initialTabIndex == 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final user = await _userService.getUserByPhone(phone);
        if (mounted) {
          setState(() => _currentUser = user);
          await _fetchPurchasedCourses();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPurchasedCourses() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted && !_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final purchases = await _userService.getUserPurchases(_currentUser!.id);
      final allCourses = await _courseService.getCourses();

      // Filter unique purchased courses
      final purchasedIds = purchases.map((p) => p.courseId).toSet();
      final purchasedCourses =
          allCourses.where((c) => purchasedIds.contains(c.id)).toList();

      final inProgress = <CourseModel>[];
      final completed = <CourseModel>[];

      for (final course in purchasedCourses) {
        // Always force-reload to get fresh data from storage
        await _learningService.reloadCourse(course.id);
        final purchase = purchases.firstWhere(
          (p) =>
              p.courseId == course.id &&
              p.purchaseType == PurchaseType.course,
          orElse: () => purchases.firstWhere(
            (p) => p.courseId == course.id,
            orElse: () => PurchaseRecord(
              userId: _currentUser!.id,
              courseId: course.id,
              purchaseType: PurchaseType.course,
              purchasedAt: DateTime.now(),
            ),
          ),
        );
        final isCompleted = _learningService.isCourseCompleted(
          course.id,
          course.totalVideos,
          purchase: purchase,
          limitedTimeDays: course.limitedTimeDays,
        );
        if (isCompleted) {
          completed.add(course);
        } else {
          inProgress.add(course);
        }
      }

      if (mounted) {
        setState(() {
          _purchasedInProgress = inProgress;
          _purchasedCompleted = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching purchased courses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final displayList =
        _isCompletedView ? _purchasedCompleted : _purchasedInProgress;
    final totalCourses =
        _purchasedInProgress.length + _purchasedCompleted.length;

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final heading =
            _isCompletedView ? T.get('completed_courses') : T.get('progress_courses');

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPurchasedCourses,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: Column(children: [
            // Header
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
                child: Row(children: [
                  if (Navigator.of(context).canPop()) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      heading,
                      style: AppTextStyles.headlineLarge,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$totalCourses ${T.get('courses_suffix')}',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(displayList, _isCompletedView),
            ),
          ]),
        ),
      ),
    );
      },
    );
  }

  Widget _buildList(List<CourseModel> courses, bool isCompleted) {
    if (courses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.workspace_premium_outlined
                          : Icons.school_outlined,
                      size: 48,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isCompleted
                        ? T.get('no_completed_courses')
                        : T.get('no_courses_in_progress'),
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isCompleted
                        ? T.get('complete_lectures_to_earn')
                        : T.get('explore_catalog_to_start'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: courses.length,
      itemBuilder: (_, i) {
        final c = courses[i];
        final completedVideosCount = _learningService.completedCount(c.id);
        final totalVideos = c.totalVideos;
        final progress =
            totalVideos > 0 ? (completedVideosCount / totalVideos) : 0.0;
        final color = i % 2 == 0
            ? const Color(0xFFE8F0FE)
            : const Color(0xFFFFF3E0);

        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + i * 80),
          child: Column(children: [
            CourseCard(
              title: c.title,
              instructor: c.trainerName,
              duration: '${c.totalDurationMinutes.toInt()}m',
              lessons: totalVideos,
              thumbnailIcon: c.emoji,
              thumbnailColor: color,
              thumbnailUrl: c.thumbnailUrl,
              showProgress: true,
              progress: progress,
              isCompact: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreenV2(course: c),
                  ),
                ).then((_) => _fetchPurchasedCourses());
              },
            ),
            if (isCompleted ||
                StudentLearningService.testingBypassCompletionGate)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GradientButton(
                  text: T.get('view_certificate'),
                  height: 44,
                  borderRadius: AppRadius.pill,
                  gradient: AppGradients.secondary,
                  icon: Icons.workspace_premium_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) => CertificateScreen(
                          courseName: c.title,
                          userName: _currentUser?.name ?? 'Student',
                          completedAt:
                              _learningService.courseCompletionDate(c.id),
                        ),
                        transitionsBuilder: (_, animation, _, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                                parent: animation, curve: Curves.easeOut),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.95, end: 1.0)
                                  .animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GradientButton(
                  text: T.get('continue_learning'),
                  height: 44,
                  borderRadius: AppRadius.pill,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreenV2(course: c),
                      ),
                    ).then((_) => _fetchPurchasedCourses());
                  },
                ),
              ),
          ]),
        );
      },
    );
  }
}
