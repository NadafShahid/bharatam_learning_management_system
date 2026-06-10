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

  List<CourseModel> _purchasedCoursesList = [];
  Map<String, bool> _completionStatus = {};
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
      final purchasedIds = purchases.map((p) => p.courseId).toSet();

      final purchasedCourses = <CourseModel>[];
      for (final id in purchasedIds) {
        final fullCourse = await _courseService.getCourseById(id);
        if (fullCourse != null) {
          purchasedCourses.add(fullCourse);
        }
      }

      final completionStatus = <String, bool>{};

      final completedCourses = <CourseModel>[];

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
        
        completedCourses.add(course);
        completionStatus[course.id] = isCompleted;
      }

      if (mounted) {
        setState(() {
          _purchasedCoursesList = completedCourses;
          _completionStatus = completionStatus;
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchPurchasedCourses,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: _purchasedCoursesList.isEmpty
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
                    'No Purchased Courses Yet',
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Purchase a course and complete 100% of the lectures to unlock your verified, downloadable certificate!',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: _purchasedCoursesList.length,
      itemBuilder: (context, index) {
        final course = _purchasedCoursesList[index];
        final compDate = _learningService.courseCompletionDate(course.id) ?? DateTime.now();
        final formattedDate = DateFormat('MMMM dd, yyyy').format(compDate);
        final userName = _currentUser?.name ?? 'Student';
        final certificateId = 'BT-${DateFormat('yyyyMMdd').format(compDate)}-${userName.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}';

        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + index * 100),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              children: [
                // The actual certificate in portrait mode
                BharatamCertificateTemplate(
                  courseName: course.title,
                  userName: userName,
                  completionDate: formattedDate,
                  certificateId: certificateId,
                  isPortrait: true,
                ),
                const SizedBox(height: 16),
                // Button to view full landscape version or download
                GradientButton(
                  text: 'View Full Certificate',
                  height: 48,
                  borderRadius: AppRadius.pill,
                  gradient: AppGradients.gold,
                  icon: Icons.fullscreen_rounded,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) => CertificateScreen(
                          courseName: course.title,
                          userName: userName,
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
          ),
        );
      },
    );
  }
}
