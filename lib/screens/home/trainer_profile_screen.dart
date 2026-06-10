import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/course_card.dart';
import '../../widgets/course_grid_card.dart';
import '../../widgets/animations.dart';
import '../../widgets/instructor_avatar.dart';
import '../../widgets/bunny_storage_image.dart';
import '../../models/app_models.dart';
import '../../services/course_service.dart';
import '../../services/subscription_service.dart';
import '../../services/trainer_service.dart';
import '../course_detail/course_detail_screen_v2.dart';

class TrainerProfileScreen extends StatefulWidget {
  final InstructorData instructor;

  const TrainerProfileScreen({super.key, required this.instructor});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  final CourseService _courseService = CourseService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  List<CourseModel> _courses = [];
  bool _isLoading = true;
  bool _isSubscribed = false;
  int _subscriberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _courseService.getCoursesByTrainer(widget.instructor.id),
        _subscriptionService.isSubscribed(widget.instructor.id),
        _subscriptionService.getSubscriberCount(widget.instructor.id),
      ]);

      if (mounted) {
        setState(() {
          _courses = results[0] as List<CourseModel>;
          _isSubscribed = results[1] as bool;
          _subscriberCount = results[2] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSubscription() async {
    HapticFeedback.mediumImpact();
    final previousState = _isSubscribed;
    setState(() {
      _isSubscribed = !previousState;
      _subscriberCount += previousState ? -1 : 1;
    });

    try {
      if (previousState) {
        await _subscriptionService.unsubscribe(widget.instructor.id);
      } else {
        await _subscriptionService.subscribe(widget.instructor.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubscribed = previousState;
          _subscriberCount += previousState ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update subscription')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildHeader(),
          _buildCoursesTitle(),
          _buildCoursesList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(widget.instructor.name, style: AppTextStyles.titleLarge),
      centerTitle: true,
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: widget.instructor.imageUrl.isNotEmpty
                          ? ClipOval(
                              child: BunnyStorageImage(
                                imageUrl: widget.instructor.imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  widget.instructor.emoji,
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                            )
                          : Text(
                              widget.instructor.emoji,
                              style: const TextStyle(fontSize: 48),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // Name & Bio
              Text(
                widget.instructor.name,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Expert Instructor in Traditional Sciences',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem('Courses', _courses.length.toString()),
                  const SizedBox(width: AppSpacing.xxl),
                  _buildStatItem('Subscribers', _subscriberCount.toString()),
                  const SizedBox(width: AppSpacing.xxl),
                  _buildStatItem('Rating', widget.instructor.rating > 0 ? '${widget.instructor.rating} \u2605' : 'New'),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // Subscribe Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _toggleSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubscribed ? AppColors.surface : AppColors.primary,
                    foregroundColor: _isSubscribed ? AppColors.primary : Colors.white,
                    elevation: _isSubscribed ? 0 : 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      side: _isSubscribed 
                        ? BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
                        : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    _isSubscribed ? 'Subscribed' : 'Subscribe to Updates',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: _isSubscribed ? AppColors.primary : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleLarge),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
      ],
    );
  }


  Widget _buildCoursesTitle() {
    if (_isLoading || _courses.isEmpty) return const SliverToBoxAdapter();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.md),
        child: Row(
          children: [
            Text('Courses', style: AppTextStyles.headlineSmall),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _courses.length.toString(),
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      );
    }

    if (_courses.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text('No courses available yet.', style: AppTextStyles.bodyMedium),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final course = _courses[index];
            final color = index % 2 == 0 ? const Color(0xFFE8F0FE) : const Color(0xFFFFF3E0);
            
            return FadeSlideIn(
              delay: Duration(milliseconds: 200 + index * 100),
              child: CourseGridCard(
                title: course.title,
                instructor: course.trainerName,
                duration: '${course.totalDurationMinutes.toInt()} mins',
                lessons: course.totalVideos,
                thumbnailIcon: course.emoji,
                thumbnailColor: color,
                thumbnailUrl: course.thumbnailUrl,
                heroTag: 'trainer_course_$index',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreenV2(
                        course: course,
                        heroTag: 'trainer_course_$index',
                      ),
                    ),
                  );
                },
              ),
            );
          },
          childCount: _courses.length,
        ),
      ),
    );
  }
}
