import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/app_models.dart';
import '../../../../services/course_service.dart';
import '../../../../services/bunny_storage_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/status_badge.dart';
import 'admin_video_upload_screen.dart';
import '../../trainer/screens/create_course_screen.dart';

/// Admin screen — lists all courses and lets the admin:
///   • Add Video  → AdminVideoUploadScreen
///   • Add PDF    → _AdminAddPdfScreen (lightweight inline screen)
///   • Edit       → CreateCourseScreen (trainer's edit-enabled screen)
///   • Delete     → confirmation dialog + CourseService.deleteCourse
class AdminUpdateCourseScreen extends StatefulWidget {
  const AdminUpdateCourseScreen({super.key});

  @override
  State<AdminUpdateCourseScreen> createState() =>
      _AdminUpdateCourseScreenState();
}

class _AdminUpdateCourseScreenState extends State<AdminUpdateCourseScreen> {
  final _courseService = CourseService();
  int _reloadToken = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Delete ─────────────────────────────────────────────────────────
  Future<void> _deleteCourse(CourseModel course) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Delete Course?', style: AppTextStyles.titleLarge),
        content: Text(
          'Are you sure you want to delete "${course.title}"?\nThis action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _courseService.deleteCourse(course.id);
        if (mounted) {
          setState(() => _reloadToken++);
          _showSnack('Course deleted successfully', isError: false);
        }
      } catch (_) {
        if (mounted) _showSnack('Failed to delete course', isError: true);
      }
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────
  void _goAddVideo(CourseModel course) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminVideoUploadScreen(course: course)),
    ).then((_) {
      if (mounted) setState(() => _reloadToken++);
    });
  }

  void _goAddPdf(CourseModel course) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AdminAddPdfScreen(course: course)),
    ).then((_) {
      if (mounted) setState(() => _reloadToken++);
    });
  }

  void _goEdit(CourseModel course) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateCourseScreen(existingCourse: course)),
    ).then((_) {
      if (mounted) setState(() => _reloadToken++);
    });
  }

  // ── Snack helper ───────────────────────────────────────────────────
  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Update Course', style: AppTextStyles.headlineSmall),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, 0),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.bodyMedium,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  hintStyle:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.textHint),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.textHint),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Course list ────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<CourseModel>>(
              key: ValueKey(_reloadToken),
              future: _courseService.getAllCoursesForAdmin(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 48),
                        const SizedBox(height: AppSpacing.md),
                        Text('Failed to load courses',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textHint)),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () => setState(() => _reloadToken++),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final all = snapshot.data ?? [];

                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_books_rounded,
                            color: AppColors.textHint.withValues(alpha: 0.4),
                            size: 64),
                        const SizedBox(height: AppSpacing.lg),
                        Text('No courses found.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textHint)),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Create a course first from the dashboard.',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textHint)),
                      ],
                    ),
                  );
                }

                final courses = _searchQuery.isEmpty
                    ? all
                    : all
                        .where((c) =>
                            c.title.toLowerCase().contains(_searchQuery) ||
                            c.trainerName.toLowerCase().contains(_searchQuery) ||
                            c.category.toLowerCase().contains(_searchQuery))
                        .toList();

                if (courses.isEmpty) {
                  return Center(
                    child: Text('No courses match "$_searchQuery"',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textHint)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0,
                      AppSpacing.xxl, AppSpacing.xxl),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final c = courses[index];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 150 + index * 70),
                      child: _buildCourseCard(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Course card ────────────────────────────────────────────────────
  Widget _buildCourseCard(CourseModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.cardHover,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Thumbnail / emoji
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    image: c.thumbnailUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(c.thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: c.thumbnailUrl.isNotEmpty
                      ? null
                      : Center(
                          child: Text(c.emoji,
                              style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        'By ${c.trainerName} · ${c.category}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusBadge(
                              status: c.isApproved
                                  ? BadgeStatus.approved
                                  : BadgeStatus.pending),
                          const SizedBox(width: 8),
                          _priceBadge(c),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.divider),

          // Actions row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(
                  Icons.video_call_rounded,
                  'Add Video',
                  color: AppColors.primary,
                  onTap: () => _goAddVideo(c),
                ),
                _vDivider(),
                _actionBtn(
                  Icons.picture_as_pdf_rounded,
                  'Add PDF',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _goAddPdf(c),
                ),
                _vDivider(),
                _actionBtn(
                  Icons.edit_rounded,
                  'Edit',
                  color: AppColors.secondary,
                  onTap: () => _goEdit(c),
                ),
                _vDivider(),
                _actionBtn(
                  Icons.delete_outline_rounded,
                  'Delete',
                  color: AppColors.error,
                  onTap: () => _deleteCourse(c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBadge(CourseModel c) {
    final isFree = c.price <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isFree ? AppColors.primary : AppColors.success)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isFree ? 'Free' : '₹${c.price.toStringAsFixed(0)}',
        style: AppTextStyles.labelSmall.copyWith(
          color: isFree ? AppColors.primary : AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 36, color: AppColors.divider);

  Widget _actionBtn(IconData icon, String label,
      {required Color color, required VoidCallback onTap}) {
    return TapScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight PDF-upload screen scoped to a single course (admin, auto-approve)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminAddPdfScreen extends StatefulWidget {
  final CourseModel course;
  const _AdminAddPdfScreen({required this.course});

  @override
  State<_AdminAddPdfScreen> createState() => _AdminAddPdfScreenState();
}

class _AdminAddPdfScreenState extends State<_AdminAddPdfScreen> {
  final _courseService = CourseService();
  final _titleController = TextEditingController();
  File? _selectedPdfFile;
  bool _isFree = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    HapticFeedback.mediumImpact();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedPdfFile = File(file.path!);
            if (_titleController.text.trim().isEmpty) {
              _titleController.text = file.name.replaceAll('.pdf', '');
            }
          });
        }
      }
    } catch (_) {
      _showSnack('Unable to pick PDF file.', isError: true);
    }
  }

  Future<void> _upload() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('Please enter a PDF title.', isError: true);
      return;
    }
    if (_selectedPdfFile == null) {
      _showSnack('Please select a PDF file.', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_selectedPdfFile!.path.split('/').last.split('\\').last}';
      final bunnyStorage = BunnyStorageService();
      final url = await bunnyStorage.uploadFile(
        file: _selectedPdfFile!,
        path: 'bharatm_library/pdfs/$fileName',
      );
      if (url == null) throw Exception('Failed to upload PDF');

      await _courseService.uploadCourseContent(
        courseId: widget.course.id,
        title: title,
        contentType: CourseContentType.pdf,
        storageUrl: url,
        fileName: fileName,
        autoApprove: true,
        isFree: _isFree,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      _showSnack('PDF uploaded successfully!', isError: false);
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to upload PDF: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.course.title, style: AppTextStyles.headlineSmall),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Admin upload — PDF will be auto-approved.',
                        style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Title
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PDF Title', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _titleController,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'e.g. Chapter 3: Advanced Concepts',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // File picker
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PDF File', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: _pickPdf,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _selectedPdfFile == null
                                  ? 'Tap to select PDF file from device'
                                  : _selectedPdfFile!.path
                                      .split('/')
                                      .last
                                      .split('\\')
                                      .last,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _selectedPdfFile == null
                                    ? AppColors.textHint
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedPdfFile != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.error),
                              onPressed: () =>
                                  setState(() => _selectedPdfFile = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Free toggle
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Free Preview', style: AppTextStyles.titleMedium),
                          Text('Users can access without purchase',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isFree,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _isFree = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.huge),

            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: GradientButton(
                text: _isUploading ? 'Uploading...' : 'Upload PDF',
                icon: Icons.cloud_upload_rounded,
                borderRadius: AppRadius.pill,
                isLoading: _isUploading,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  if (!_isUploading) _upload();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
