import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/status_badge.dart';
import '../../../../widgets/bunny_storage_image.dart';
import '../../../../services/course_service.dart';
import '../../../../services/user_service.dart';
import '../../../../models/app_models.dart';
import 'create_course_screen.dart';
import 'video_upload_screen.dart';
import 'package:file_picker/file_picker.dart';

class TrainerCoursesScreen extends StatefulWidget {
  const TrainerCoursesScreen({super.key});

  @override
  State<TrainerCoursesScreen> createState() => _TrainerCoursesScreenState();
}

class _TrainerCoursesScreenState extends State<TrainerCoursesScreen> {
  int _reloadToken = 0;

  Future<void> _deleteCourse(CourseModel course) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Course?', style: AppTextStyles.titleLarge),
        content: Text('Are you sure you want to delete "${course.title}"? This action cannot be undone.', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CourseService().deleteCourse(course.id);
      if (mounted) {
        setState(() => _reloadToken++);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course deleted successfully')));
      }
    }
  }

  Future<void> _pickAndUploadPdf(CourseModel course) async {
    HapticFeedback.mediumImpact();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final fileName = file.name;
      final titleController = TextEditingController(text: fileName.replaceAll('.pdf', ''));
      
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Upload PDF', style: AppTextStyles.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDF Title', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: titleController,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('File: $fileName', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Upload', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      );

      if (confirmed == true && titleController.text.trim().isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          await CourseService().uploadCourseContent(
            courseId: course.id,
            title: titleController.text.trim(),
            contentType: CourseContentType.pdf,
            storageUrl: file.path ?? fileName,
            fileName: fileName,
          );
          if (mounted) {
            Navigator.pop(context); // close progress
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF uploaded successfully')));
            setState(() => _reloadToken++);
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // close progress
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload PDF'), backgroundColor: AppColors.error));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseService = CourseService();
    final userService = UserService();
    final trainerId = userService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'My Courses',
                        style: AppTextStyles.headlineLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    TapScale(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen()))
                            .then((created) {
                          if (created == true && mounted) {
                            setState(() => _reloadToken++);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.elevated,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text('Create', style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Expanded(
              child: FutureBuilder<List<CourseModel>>(
                key: ValueKey(_reloadToken),
                future: courseService.getCoursesByTrainer(trainerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final courses = snapshot.data ?? [];
                  
                  if (courses.isEmpty) {
                    return Center(child: Text('No courses found.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)));
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final c = courses[index];
                      
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 200 + index * 80),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: AppShadows.cardHover,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 70, height: 70,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      image: c.thumbnailUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: bunnyStorageNetworkImage(c.thumbnailUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: c.thumbnailUrl.isNotEmpty
                                        ? null
                                        : Center(child: Text(c.emoji, style: const TextStyle(fontSize: 32))),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          style: AppTextStyles.titleMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            StatusBadge(status: c.isApproved ? BadgeStatus.approved : BadgeStatus.pending),
                                            const SizedBox(width: 12),
                                            Icon(Icons.people_alt_rounded, size: 14, color: AppColors.textHint),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                c.category.isEmpty ? 'Uncategorized' : c.category,
                                                style: AppTextStyles.labelSmall,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Divider(height: 1, color: AppColors.divider),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: _buildActionBtn(
                                      Icons.video_call_rounded,
                                      'Add Videos',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VideoUploadScreen(course: c),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildActionBtn(
                                      Icons.picture_as_pdf_rounded,
                                      'Add PDF',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VideoUploadScreen(course: c, initialIsPdf: true),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!c.isApproved)
                                    Expanded(
                                      child: _buildActionBtn(
                                        Icons.edit_rounded,
                                        'Edit',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreateCourseScreen(existingCourse: c),
                                          ),
                                        ).then((_) {
                                          setState(() => _reloadToken++);
                                        }),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: _buildActionBtn(
                                        Icons.edit_off_rounded,
                                        'Approved',
                                        isDisabled: true,
                                      ),
                                    ),
                                  if (!c.isApproved)
                                    Expanded(
                                      child: _buildActionBtn(Icons.delete_outline_rounded, 'Delete', isDanger: true, onTap: () => _deleteCourse(c)),
                                    )
                                  else
                                    Expanded(
                                      child: _buildActionBtn(Icons.delete_outline_rounded, 'Delete', isDisabled: true),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {bool isDanger = false, bool isDisabled = false, VoidCallback? onTap}) {
    return TapScale(
      onTap: () {
        if (isDisabled) return;
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, size: 22, color: isDisabled ? AppColors.textHint : (isDanger ? AppColors.error : AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: isDisabled ? AppColors.textHint : (isDanger ? AppColors.error : AppColors.textSecondary)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
