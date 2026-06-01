import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../models/app_models.dart';
import '../../../../services/course_service.dart';

class AdminManageContentScreen extends StatefulWidget {
  const AdminManageContentScreen({super.key});

  @override
  State<AdminManageContentScreen> createState() => _AdminManageContentScreenState();
}

class _AdminManageContentScreenState extends State<AdminManageContentScreen> {
  final _courseService = CourseService();
  bool _isLoading = true;
  List<CourseModel> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _courseService.getAllCoursesForAdmin();
      final approvedCourses = courses.where((c) => c.isApproved).toList();
      
      approvedCourses.sort((a, b) => b.views.compareTo(a.views));

      if (mounted) {
        setState(() {
          _courses = approvedCourses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _promoteCourse(String courseId, int currentViews) async {
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      builder: (context) {
        int increment = 1000;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              title: Text('Promote Course', style: AppTextStyles.headlineSmall),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Increase views to make this course appear higher in the student feed.', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Add Views: $increment', style: AppTextStyles.titleMedium),
                  Slider(
                    value: increment.toDouble(),
                    min: 100,
                    max: 10000,
                    divisions: 99,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setDialogState(() {
                        increment = val.toInt();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textHint)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    await _courseService.incrementCourseViews(courseId, increment);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Added $increment views successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _loadCourses();
                  },
                  child: Text('Promote', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Promote Courses', style: AppTextStyles.headlineSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Text(
                    'No active courses found.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
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
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  course.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.title,
                                    style: AppTextStyles.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${course.trainerName} • ${course.category}',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '👁️ ${course.views} views',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            ElevatedButton(
                              onPressed: () => _promoteCourse(course.id, course.views),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                              ),
                              child: const Text('Promote'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
