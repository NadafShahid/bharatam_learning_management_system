import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/app_models.dart';
import '../../../../services/course_service.dart';
import '../../../../services/bunny_storage_helper.dart';
import '../../../../screens/course_detail/pdf_viewer_screen.dart';
import '../../../../screens/video_player/video_player_screen.dart';
import '../../../../widgets/status_badge.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/bunny_storage_image.dart';

class AdminCoursePreviewScreen extends StatefulWidget {
  final CourseModel course;
  final bool needsCourseApproval;

  const AdminCoursePreviewScreen({
    super.key,
    required this.course,
    required this.needsCourseApproval,
  });

  @override
  State<AdminCoursePreviewScreen> createState() => _AdminCoursePreviewScreenState();
}

class _AdminCoursePreviewScreenState extends State<AdminCoursePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CourseService _courseService = CourseService();
  bool _isActionInProgress = false;

  List<VideoModel> get _videos {
    final list = <VideoModel>[];
    for (final m in widget.course.modules) {
      list.addAll(m.videos.where((v) => v.contentType == CourseContentType.video));
    }
    list.addAll(widget.course.standaloneVideos.where((v) => v.contentType == CourseContentType.video));
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<VideoModel> get _pdfs {
    final list = <VideoModel>[];
    for (final m in widget.course.modules) {
      list.addAll(m.videos.where((v) => v.contentType == CourseContentType.pdf));
    }
    list.addAll(widget.course.standaloneVideos.where((v) => v.contentType == CourseContentType.pdf));
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveCourse() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    HapticFeedback.heavyImpact();
    try {
      await _courseService.approveCourse(widget.course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course review approved.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving course: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _rejectCourse() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    HapticFeedback.heavyImpact();
    try {
      await _courseService.rejectCourse(widget.course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course review rejected.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting course: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _playVideo(VideoModel video) async {
    HapticFeedback.mediumImpact();
    String? directUrl = video.bunnyVideoId.isNotEmpty ? video.bunnyVideoId : video.storageUrl;
    if (directUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video URL not available.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: video.title,
          courseTitle: widget.course.title,
          courseId: widget.course.id,
          videoId: video.id,
          totalVideos: widget.course.totalVideos,
          isPdf: false,
          directVideoUrl: directUrl,
        ),
      ),
    );
  }

  void _viewPdf(VideoModel pdf) async {
    HapticFeedback.mediumImpact();
    String? directUrl = pdf.bunnyVideoId.isNotEmpty ? pdf.bunnyVideoId : pdf.storageUrl;
    if (directUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF URL not available.')),
      );
      return;
    }

    final String fixedPdfUrl = BunnyStorageHelper.fixUrl(directUrl);
    final Map<String, String> pdfHeaders =
        BunnyStorageHelper.isStorageUrl(directUrl)
            ? BunnyStorageHelper.storageHeaders
            : const {};

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: pdf.title,
          pdfUrl: fixedPdfUrl,
          headers: pdfHeaders,
        ),
      ),
    );
  }

  BadgeStatus _getBadgeStatus(ApprovalStatus status) {
    return switch (status) {
      ApprovalStatus.pending => BadgeStatus.pending,
      ApprovalStatus.rejected => BadgeStatus.rejected,
      ApprovalStatus.approved => BadgeStatus.approved,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = widget.course.thumbnailUrl.isNotEmpty;
    final videos = _videos;
    final pdfs = _pdfs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header Section with cover image and back button
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 220,
                child: hasThumbnail
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          BunnyStorageImage(
                            imageUrl: widget.course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.textPrimary,
                              AppColors.textPrimary.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.course.emoji.isNotEmpty ? widget.course.emoji : '📘',
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        widget.course.category.isEmpty ? 'Uncategorized' : widget.course.category,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.course.title,
                      style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Course Description & Trainer Info
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course.trainerName,
                            style: AppTextStyles.titleMedium,
                          ),
                          Text(
                            'Trainer',
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${widget.course.price.toInt()}',
                      style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (widget.course.description.isNotEmpty) ...[
                  Text(
                    widget.course.description,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.labelLarge,
              tabs: const [
                Tab(text: 'Videos'),
                Tab(text: 'PDFs'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentList(videos, isPdf: false),
                _buildContentList(pdfs, isPdf: true),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: AppShadows.bottomNav,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isActionInProgress ? null : _rejectCourse,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: _isActionInProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                              ),
                            )
                          : const Text(
                              'Reject Course',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _isActionInProgress
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                              ),
                            ),
                          )
                        : GradientButton(
                            text: 'Approve Course',
                            height: 48,
                            borderRadius: AppRadius.pill,
                            gradient: const LinearGradient(
                              colors: [AppColors.success, Color(0xFF059669)],
                            ),
                            onPressed: _approveCourse,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(List<VideoModel> items, {required bool isPdf}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.video_library_rounded,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 8),
            Text(
              isPdf ? 'No PDFs uploaded' : 'No videos uploaded',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final badgeStatus = _getBadgeStatus(item.approvalStatus);

        return FadeSlideIn(
          delay: Duration(milliseconds: 50 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppShadows.subtle,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                onTap: () => isPdf ? _viewPdf(item) : _playVideo(item),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      // Thumbnail or Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: (!isPdf && item.resolvedThumbnailUrl.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: BunnyStorageImage(
                                  imageUrl: item.resolvedThumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    isPdf ? Icons.picture_as_pdf_rounded : Icons.play_arrow_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                isPdf ? Icons.picture_as_pdf_rounded : Icons.play_arrow_rounded,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Title & details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTextStyles.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (!isPdf) ...[
                                  Icon(Icons.access_time_rounded, size: 12, color: AppColors.textHint),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.durationFormatted,
                                    style: AppTextStyles.labelSmall,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (item.isFree)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'FREE',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 8,
                                      ),
                                    ),
                                  )
                                else if (item.price != null)
                                  Text(
                                    '₹${item.price!.toInt()}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Status Badge
                      StatusBadge(status: badgeStatus),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
