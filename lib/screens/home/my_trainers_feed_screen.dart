import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../video_player/video_player_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/course_service.dart';
import '../../services/trainer_service.dart';
import '../../models/app_models.dart';
import '../../widgets/instructor_avatar.dart';
import 'trainer_profile_screen.dart';
import 'package:intl/intl.dart';

class MyTrainersFeedScreen extends StatefulWidget {
  const MyTrainersFeedScreen({super.key});

  @override
  State<MyTrainersFeedScreen> createState() => _MyTrainersFeedScreenState();
}

class _MyTrainersFeedScreenState extends State<MyTrainersFeedScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final CourseService _courseService = CourseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedItems = [];
  List<InstructorData> _subscribedTrainers = [];
  final TrainerService _trainerService = TrainerService();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final subscribedIds = await _subscriptionService.getSubscribedTrainerIds();
      List<Map<String, dynamic>> allVideos = [];

      for (final trainerId in subscribedIds) {
        final courses = await _courseService.getCoursesByTrainer(trainerId);
        for (final course in courses) {
          // Fetch full course data including videos
          // Note: getCoursesByTrainer doesn't fetch videos by default in current implementation
          // I'll need a better way to fetch videos or update CourseService
          
          // For now, let's assume we can fetch the full course details
          // I'll use a modified approach to get videos
          final fullCourse = await _getFullCourse(course.id);
          
          for (final module in fullCourse.modules) {
            for (final video in module.videos) {
              allVideos.add(_mapVideoToFeedItem(fullCourse, video));
            }
          }
          for (final video in fullCourse.standaloneVideos) {
            allVideos.add(_mapVideoToFeedItem(fullCourse, video));
          }
        }
      }

      // Sort by views descending, then createdAt descending
      allVideos.sort((a, b) {
        final viewsA = a['views'] as int? ?? 0;
        final viewsB = b['views'] as int? ?? 0;
        if (viewsA != viewsB) {
          return viewsB.compareTo(viewsA);
        }
        final dateA = a['rawDate'] as DateTime?;
        final dateB = b['rawDate'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      final trainers = await _trainerService.getTrainersByIds(subscribedIds);

      if (mounted) {
        setState(() {
          _feedItems = allVideos;
          _subscribedTrainers = trainers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to fetch full course with modules and videos
  // Since CourseService.getCourses() does this, but for all courses.
  // I'll implement a single course fetcher if not exists, or just use the logic here.
  Future<CourseModel> _getFullCourse(String courseId) async {
    // This is a bit inefficient, but works for the prototype
    final allCourses = await _courseService.getCourses();
    return allCourses.firstWhere((c) => c.id == courseId);
  }

  Map<String, dynamic> _mapVideoToFeedItem(CourseModel course, VideoModel video) {
    final timeStr = video.createdAt != null 
        ? _getTimeAgo(video.createdAt!)
        : 'Recently';
    
    return {
      'trainer': course.trainerName,
      'time': timeStr,
      'course': course.title,
      'title': video.title,
      'emoji': course.emoji,
      'bg': const Color(0xFFF3E5F5), // Default or based on category
      'thumbnailColor': AppColors.primary,
      'rawDate': video.createdAt,
      'duration': video.durationFormatted,
      'views': video.views,
      'videoId': video.id,
      'courseId': course.id,
    };
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat.yMMMd().format(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Trainers', style: AppTextStyles.headlineSmall),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFeed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedItems.isEmpty && _subscribedTrainers.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (_subscribedTrainers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.md),
                              child: Text('My Subscriptions', style: AppTextStyles.titleMedium),
                            ),
                            InstructorAvatarList(
                              instructors: _subscribedTrainers,
                              onTap: (trainer) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrainerProfileScreen(instructor: trainer),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    
                    if (_feedItems.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _feedItems[index];
                              return FadeSlideIn(
                                delay: Duration(milliseconds: 100 + index * 100),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.xxl),
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.xl),
                                    boxShadow: AppShadows.cardHover,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: item['bg'] as Color,
                                            ),
                                            child: Center(child: Text(item['emoji'] as String, style: const TextStyle(fontSize: 24))),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['trainer'] as String, style: AppTextStyles.titleMedium),
                                                Text('Uploaded a new video • ${item['time']} • ${item['views']} views', style: AppTextStyles.labelSmall),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.more_vert_rounded, color: AppColors.textHint),
                                            onPressed: () => HapticFeedback.lightImpact(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      
                                      // Text Content
                                      Text(
                                        'New lesson added to ${item['course']}. In this video, we will cover ${item['title'].toString().toLowerCase()}. Make sure to complete the previous exercises first!',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      
                                      // Video Thumbnail
                                      TapScale(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (_, _, _) => VideoPlayerScreen(
                                                title: item['title'] as String,
                                                courseTitle: item['course'] as String,
                                              ),
                                              transitionsBuilder: (_, animation, _, child) {
                                                return FadeTransition(
                                                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                                                  child: child,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        child: Container(
                                          height: 180,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                (item['thumbnailColor'] as Color),
                                                (item['thumbnailColor'] as Color).withValues(alpha: 0.7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            boxShadow: AppShadows.subtle,
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 12,
                                                left: 12,
                                                right: 12,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: 0.6),
                                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                                      ),
                                                      child: Text(item['duration'] ?? '10:00', style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      item['title'] as String,
                                                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _feedItems.length,
                          ),
                        ),
                      ),
                    
                    if (_feedItems.isEmpty && _subscribedTrainers.isNotEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.slow_motion_video_rounded, size: 64, color: AppColors.textHint),
                                const SizedBox(height: AppSpacing.lg),
                                Text('No recent updates', style: AppTextStyles.titleMedium),
                                Text('Your trainers haven\'t posted anything recently.', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('No Subscriptions Yet', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Subscribe to your favorite trainers to see their latest lectures and updates here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
