import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../services/user_service.dart';
import '../../services/student_learning_service.dart';
import '../../services/course_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/gradient_button.dart';
import 'certificate_screen.dart';

class MyCertificatesScreen extends StatefulWidget {
  const MyCertificatesScreen({super.key});

  @override
  State<MyCertificatesScreen> createState() => _MyCertificatesScreenState();
}

class _MyCertificatesScreenState extends State<MyCertificatesScreen> {
  final _courseService = CourseService();
  final _userService = UserService();
  final _learningService = StudentLearningService();

  List<CourseModel> _purchasedCompleted = [];
  bool _isLoading = true;
  UserModel? _currentUser;

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
          await _fetchCompletedCourses();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCompletedCourses() async {
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
      final purchasedCourses = allCourses.where((c) => purchasedIds.contains(c.id)).toList();

      final completed = <CourseModel>[];

      for (final course in purchasedCourses) {
        await _learningService.reloadCourse(course.id);
        final purchase = purchases.firstWhere(
          (p) => p.courseId == course.id && p.purchaseType == PurchaseType.course,
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
        }
      }

      if (mounted) {
        setState(() {
          _purchasedCompleted = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching completed courses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Certificates',
          style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCompletedCourses,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _purchasedCompleted.isEmpty
                  ? _buildEmptyState()
                  : _buildCertificatesList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.card,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 72,
                      color: Color(0xFFD4AF37), // Premium Gold
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'No Certificates Earned Yet',
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Complete 100% of the lectures in any of your purchased courses to unlock your verified, downloadable certificate!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificatesList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _purchasedCompleted.length,
      itemBuilder: (context, index) {
        final course = _purchasedCompleted[index];
        final compDate = _learningService.courseCompletionDate(course.id) ?? DateTime.now();
        final formattedDate = DateFormat('dd MMMM yyyy').format(compDate);
        final color = index % 2 == 0 ? const Color(0xFFE8F0FE) : const Color(0xFFFFF3E0);

        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + index * 100),
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.card,
              border: Border.all(
                color: const Color(0xFFFFD480).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Emoji backdrop
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            course.emoji.isNotEmpty ? course.emoji : '📚',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded, size: 10, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Certificate',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              course.title,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Instructor: ${course.trainerName}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Earned On',
                            style: AppTextStyles.labelSmall.copyWith(fontSize: 9),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      GradientButton(
                        text: 'View & Download',
                        height: 38,
                        borderRadius: AppRadius.pill,
                        gradient: AppGradients.gold,
                        icon: Icons.workspace_premium_rounded,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, _, _) => CertificateScreen(
                                courseName: course.title,
                                userName: _currentUser?.name ?? 'Student',
                                completedAt: compDate,
                              ),
                              transitionsBuilder: (_, animation, _, child) {
                                return FadeTransition(
                                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 450),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
