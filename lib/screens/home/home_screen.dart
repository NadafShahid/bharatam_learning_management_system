import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/course_card.dart';
import '../../widgets/course_grid_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/instructor_avatar.dart';
import '../../widgets/animations.dart';
import '../../core/localization.dart';
import '../course_detail/course_detail_screen_v2.dart';
import '../../models/app_models.dart';
import '../../services/course_service.dart';
import '../../services/trainer_service.dart';
import '../../services/user_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'trainer_profile_screen.dart';
import '../../services/ad_service.dart';
import '../search/search_screen.dart';
import '../certificate/certificate_screen.dart';
import '../certificate/my_certificates_screen.dart';
import '../my_courses/my_courses_screen.dart';
import '../../services/student_learning_service.dart';
import '../chat/student_chat_screen.dart';
import '../../services/category_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedCategory = 0;

  List<String> _categories = [
    'All',
    'Vedic Maths',
    'Sanskrit',
    'Philosophy',
    'History',
    'Yoga',
  ];

  final _categoryService = CategoryService();
  StreamSubscription<List<String>>? _categoryStreamSubscription;

  List<InstructorData> _instructors = [];
/*
    InstructorData(name: 'Dr. Sharma', emoji: '👨‍🏫'),
    InstructorData(name: 'Prof. Iyer', emoji: '👩‍🏫'),
    InstructorData(name: 'Guru Dev', emoji: '🧘'),
    InstructorData(name: 'Dr. Patel', emoji: '👨‍🎓'),
    InstructorData(name: 'Acharya Ji', emoji: '📚'),

*/
  List<CourseModel> _courses = [];
  List<CourseModel> _purchasedCourses = [];
  List<CourseModel> _purchasedInProgress = [];
  List<CourseModel> _purchasedCompleted = [];
  bool _isLoadingCourses = true;
  bool _isLoadingPurchased = true;
  UserModel? _currentUser;
  List<Advertisement> _advertisements = [];

  final _learningService = StudentLearningService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _courseService = CourseService();

  /// Subscription to the real-time Firestore course stream.
  /// Cancelled in dispose() to prevent memory leaks.
  StreamSubscription<List<CourseModel>>? _courseStreamSubscription;

  @override
  void initState() {
    super.initState();
    // Run all independent fetches in parallel for maximum speed
    Future.wait([
      _fetchTrainers(),
      _fetchAds(),
      _fetchUserData(),
    ]).then((_) => _fetchPurchasedCourses());
    // Subscribe to real-time course updates
    _subscribeToCourses();
    _subscribeToCategories();
  }

  @override
  void dispose() {
    _courseStreamSubscription?.cancel();
    _categoryStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAds() async {
    try {
      final service = AdService();
      final fetched = await service.getAdvertisements();
      if (mounted) {
        setState(() => _advertisements = fetched);
      }
    } catch (e) {
      debugPrint('Error fetching ads: $e');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final userService = UserService();
        final user = await userService.getUserByPhone(phone);
        if (mounted) {
          setState(() => _currentUser = user);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _fetchTrainers() async {
    try {
      final service = TrainerService();
      final fetched = await service.getTrainers();
      if (mounted) {
        setState(() => _instructors = fetched);
      }
    } catch (e, stack) {
      debugPrint('Error fetching trainers: $e\n$stack');
      if (mounted) {
        setState(() => _instructors = []);
      }
    }
  }

  /// Subscribes to the lightweight real-time Firestore course stream.
  /// The home screen updates automatically whenever courses change in Firestore.
  void _subscribeToCourses() {
    _courseStreamSubscription?.cancel();
    _courseStreamSubscription = _courseService
        .getCourseListStream()
        .listen(
      (fetched) {
        if (mounted) {
          setState(() {
            _courses = fetched;
            _isLoadingCourses = false;
          });
          // Re-evaluate purchased course status when course list updates
          if (_currentUser != null && _purchasedCourses.isNotEmpty) {
            _fetchPurchasedCourses();
          }
        }
      },
      onError: (e, stack) {
        debugPrint('Error in course stream: $e\n$stack');
        if (mounted) {
          setState(() => _isLoadingCourses = false);
        }
      },
    );
  }

  void _subscribeToCategories() {
    _categoryStreamSubscription?.cancel();
    _categoryStreamSubscription = _categoryService.watchCategories().listen(
      (fetched) {
        if (mounted) {
          setState(() {
            if (fetched.isNotEmpty) {
              _categories = ['All', ...fetched];
              if (_selectedCategory >= _categories.length) {
                _selectedCategory = 0;
              }
            }
          });
        }
      },
      onError: (e, stack) {
        debugPrint('Error in category stream: $e\n$stack');
      },
    );
  }

  Future<void> _fetchPurchasedCourses() async {
    if (_currentUser == null) return;
    try {
      final userService = UserService();

      final purchases = await userService.getUserPurchases(_currentUser!.id);

      // Reuse the courses already loaded by the stream — no extra Firestore fetch!
      final allCourses = _courses.isNotEmpty
          ? _courses
          : await _courseService.getCourseList();

      // Filter for unique courses purchased
      final purchasedIds = purchases.map((p) => p.courseId).toSet();
      final purchasedCourses = allCourses.where((c) => purchasedIds.contains(c.id)).toList();

      final inProgress = <CourseModel>[];
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
        } else {
          inProgress.add(course);
        }
      }

      if (mounted) {
        setState(() {
          _purchasedCourses = purchasedCourses;
          _purchasedInProgress = inProgress;
          _purchasedCompleted = completed;
          _isLoadingPurchased = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPurchased = false);
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  bool _isCategoryMatch(String courseCategory, String chipCategory) {
    if (chipCategory == 'All') return true;
    
    final normCourse = courseCategory.toLowerCase().trim();
    final normChip = chipCategory.toLowerCase().trim();
    
    if (normCourse == normChip) return true;
    
    // Map 'Vedic Maths' / 'Vedic Math' / 'Mathematics'
    if (normChip.contains('math') || normChip == 'vedic maths') {
      return normCourse.contains('math') || normCourse == 'mathematics';
    }
    
    // Map 'Sanskrit' / 'Language'
    if (normChip == 'sanskrit') {
      return normCourse == 'sanskrit' || normCourse == 'language';
    }
    
    // Map 'Yoga' / 'Yoga & Wellness'
    if (normChip == 'yoga') {
      return normCourse.contains('yoga');
    }
    
    return false;
  }

  List<CourseModel> get _filteredCourses {
    if (_selectedCategory == 0) return _courses;
    final categoryName = _categories[_selectedCategory];
    return _courses.where((c) => _isCategoryMatch(c.category, categoryName)).toList();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    // Re-subscribe to get a fresh snapshot immediately + restart the stream
    setState(() => _isLoadingCourses = true);
    _subscribeToCourses();
    _subscribeToCategories();
    await _fetchTrainers();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: _buildDrawer(),
          body: SafeArea(
            child: Column(
              children: [
            // Orange branded header bar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE65100), // deep orange
                    Color(0xFFFF8F00), // amber orange
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33E65100),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    // Drawer trigger (3-lined menu)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.menu_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Logo circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CustomPaint(
                            painter: const _HeaderLogoPainter(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Title text
                    Expanded(
                      child: Text(
                        T.get('welcome_header'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentChatScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _HeaderNotificationBell(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // Advertisement card
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 0,
                          ),
                          child: _AdvertisementCard(ad: _advertisements.isNotEmpty ? _advertisements.first : null),
                        ),
                      ),
                    ),

                    // Purchased Courses (My Learning)
                    if (_purchasedCourses.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xxl,
                              bottom: AppSpacing.md,
                              left: AppSpacing.xxl,
                              right: AppSpacing.xxl,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(T.get('my_learning'), style: AppTextStyles.headlineSmall),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _scaffoldKey.currentState?.openDrawer();
                                  },
                                  child: Text(
                                    T.get('view_all'),
                                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                              itemCount: _purchasedCourses.length,
                              itemBuilder: (context, index) {
                                final course = _purchasedCourses[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                                  child: SizedBox(
                                    width: 240,
                                    child: CourseCard(
                                      title: course.title,
                                      instructor: course.trainerName,
                                      duration: '${course.totalDurationMinutes.toInt()} mins',
                                      lessons: course.totalVideos,
                                      thumbnailUrl: course.thumbnailUrl,
                                      thumbnailIcon: course.emoji,
                                      showProgress: true,
                                      progress: (() {
                                        final completedVideos = _learningService.completedCount(course.id);
                                        final totalVideos = course.totalVideos;
                                        return totalVideos > 0 ? (completedVideos / totalVideos) : 0.0;
                                      })(),
                                      isCompact: true,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CourseDetailScreenV2(course: course),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Instructors
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xxl,
                            bottom: AppSpacing.md,
                            left: AppSpacing.xxl,
                          ),
                          child: Text(T.get('top_instructors'), style: AppTextStyles.headlineSmall),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 350),
                        slideOffset: const Offset(30, 0),
                        child: InstructorAvatarList(
                          instructors: _instructors,
                          onTap: (instructor) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrainerProfileScreen(instructor: instructor),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Categories
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 400),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xxl,
                            bottom: AppSpacing.md,
                            left: AppSpacing.xxl,
                          ),
                          child: Text(T.get('categories'), style: AppTextStyles.headlineSmall),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 450),
                        slideOffset: const Offset(20, 0),
                        child: SizedBox(
                          height: 46,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                            itemCount: _categories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              return CategoryChip(
                                label: _categories[index],
                                isSelected: _selectedCategory == index,
                                onTap: () => setState(() => _selectedCategory = index),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Course list header
                    SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 500),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xxl,
                            bottom: AppSpacing.md,
                            left: AppSpacing.xxl,
                            right: AppSpacing.xxl,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(T.get('featured_courses'), style: AppTextStyles.headlineSmall),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  T.get('see_all'),
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Course cards with staggered entrance
                    if (_isLoadingCourses)
                      const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (_filteredCourses.isEmpty)
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.xl),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    '${T.get('no_courses_in')} ${_categories[_selectedCategory]}',
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    T.get('explore_other_category'),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.lg,
                            crossAxisSpacing: AppSpacing.lg,
                            childAspectRatio: 1.05,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final course = _filteredCourses[index];
                              // Use a default color for dynamic courses, or map from category
                              final color = index % 2 == 0 ? const Color(0xFFE8F0FE) : const Color(0xFFFFF3E0);
                              
                              return FadeSlideIn(
                                delay: Duration(milliseconds: 100 + (index * 80)),
                                child: CourseGridCard(
                                  title: course.title,
                                  instructor: course.trainerName,
                                  duration: '${course.totalDurationMinutes.toInt()} mins',
                                  lessons: course.totalVideos,
                                  thumbnailIcon: course.emoji,
                                  thumbnailColor: color,
                                  thumbnailUrl: course.thumbnailUrl,
                                  heroTag: 'course_thumb_${course.id}',
                                  isCompact: true,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (_, _, _) => CourseDetailScreenV2(
                                          course: course,
                                          heroTag: 'course_thumb_${course.id}',
                                        ),
                                        transitionsBuilder: (_, animation, _, child) {
                                          return FadeTransition(
                                            opacity: CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOut,
                                            ),
                                            child: child,
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            childCount: _filteredCourses.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Drawer Header with User Profile info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE65100),
                  Color(0xFFFF8F00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🧑‍🎓',
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser?.name ?? 'Student',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.phoneNumber != null ? '+91 ${_currentUser!.phoneNumber}' : 'Bharatam Student',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Drawer Body: Streamlined Navigation
          Expanded(
            child: _isLoadingPurchased
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    children: [
                      _buildDrawerItem(
                        title: T.get('progress_courses'),
                        icon: Icons.book_outlined,
                        iconColor: AppColors.primary,
                        iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                        count: _purchasedInProgress.length,
                        onTap: () {
                          Navigator.pop(context); // Close Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyCoursesScreen(showOnlyCompleted: false),
                            ),
                          ).then((_) => _fetchPurchasedCourses());
                        },
                      ),
                      _buildDrawerItem(
                        title: T.get('completed_courses'),
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: AppColors.success,
                        iconBgColor: AppColors.success.withValues(alpha: 0.1),
                        count: _purchasedCompleted.length,
                        onTap: () {
                          Navigator.pop(context); // Close Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyCoursesScreen(showOnlyCompleted: true),
                            ),
                          ).then((_) => _fetchPurchasedCourses());
                        },
                      ),
                      _buildDrawerItem(
                        title: T.get('certificates'),
                        icon: Icons.workspace_premium_outlined,
                        iconColor: const Color(0xFFD4AF37),
                        iconBgColor: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                        count: _purchasedCompleted.length,
                        onTap: () {
                          Navigator.pop(context); // Close Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyCertificatesScreen(),
                            ),
                          ).then((_) => _fetchPurchasedCourses());
                        },
                      ),
                      _buildDrawerItem(
                        title: T.get('support_chat'),
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: AppColors.secondary,
                        iconBgColor: AppColors.secondary.withValues(alpha: 0.1),
                        count: 0,
                        onTap: () {
                          Navigator.pop(context); // Close Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentChatScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required int count,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon wrapper
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Badge count & Chevron
                if (count > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$count',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0), weight: 20),
    ]).animate(_shakeController);

    // Subtle bell shake on load
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _shakeController.forward();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _shakeController.forward(from: 0),
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.rotate(
          angle: _shakeAnim.value,
          child: child,
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.subtle,
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.notifications_none_rounded, size: 24),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notification bell variant styled for the orange header bar
class _HeaderNotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            Positioned(
              top: 8,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.yellowAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvertisementCard extends StatelessWidget {
  final Advertisement? ad;

  const _AdvertisementCard({this.ad});

  @override
  Widget build(BuildContext context) {
    final String imageUrl = (ad != null && ad!.imageUrl.isNotEmpty)
        ? ad!.imageUrl
        : 'https://images.unsplash.com/photo-1524178232363-1fb280714553?auto=format&fit=crop&q=80&w=1000';
    
    final String title = ad?.title ?? '';
    final String subtitle = ad?.subtitle ?? '';
    final String badgeText = ad?.badgeText ?? '';

    // If the ad object is present and it is a custom image ad (no text fields populated),
    // we should NOT overlay default texts and should hide the gradient overlay.
    // However, if the ad is null (fallback mode), we show the default promotional text.
    final bool showOverlay = ad == null || title.isNotEmpty || subtitle.isNotEmpty || badgeText.isNotEmpty;

    final String displayTitle = ad == null ? 'Unlock 50% Off\non Vedic Sciences' : title;
    final String displaySubtitle = ad == null ? 'Limited time offer for new students' : subtitle;
    final String displayBadge = ad == null ? 'SPECIAL OFFER' : badgeText;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Stack(
          children: [
            // Image Layer
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE65100),
                          Color(0xFFFF8F00),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),
            // Text and Gradient Overlay Layer
            if (showOverlay) ...[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayBadge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          displayBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (displayTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        displayTitle,
                        style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (displaySubtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displaySubtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderLogoPainter extends CustomPainter {
  const _HeaderLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green Chevron (Left) - Sized and positioned to perfectly align
    final paintGreen = Paint()
      ..color = const Color(0xFF007A33) // Rich green representing heritage
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pathGreen = Path();
    pathGreen.moveTo(w * 0.24, h * 0.25);
    pathGreen.lineTo(w * 0.47, h * 0.50);
    pathGreen.lineTo(w * 0.24, h * 0.75);
    pathGreen.lineTo(w * 0.33, h * 0.50);
    pathGreen.close();

    // Orange Chevron (Right) - Perfect offset to create uniform white spacer
    final paintOrange = Paint()
      ..color = const Color(0xFFF89A1C) // Vibrant saffron/orange
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pathOrange = Path();
    pathOrange.moveTo(w * 0.45, h * 0.15);
    pathOrange.lineTo(w * 0.76, h * 0.50);
    pathOrange.lineTo(w * 0.45, h * 0.85);
    pathOrange.lineTo(w * 0.57, h * 0.50);
    pathOrange.close();

    canvas.drawPath(pathGreen, paintGreen);
    canvas.drawPath(pathOrange, paintOrange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
