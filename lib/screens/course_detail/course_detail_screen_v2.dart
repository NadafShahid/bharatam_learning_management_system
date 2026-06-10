import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';
import '../../widgets/purchase_sheets.dart';
import '../../widgets/commerce_widgets.dart';
import '../../widgets/bunny_storage_image.dart';
import '../../services/bunny_storage_helper.dart';
import '../video_player/video_player_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/student_learning_service.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../services/bunny_stream_service.dart';
import '../../services/course_service.dart';
import 'pdf_viewer_screen.dart';

/// Enhanced Course Detail Screen with modules, multi-level purchase, and access control.
class CourseDetailScreenV2 extends StatefulWidget {
  final CourseModel course;
  final String? heroTag;
  /// When true the screen is shown to the trainer as a read-only preview of
  /// their own course – all content is unlocked and the purchase bar is hidden.
  final bool isTrainerPreview;

  const CourseDetailScreenV2({
    super.key,
    required this.course,
    this.heroTag,
    this.isTrainerPreview = false,
  });

  @override
  State<CourseDetailScreenV2> createState() => _CourseDetailScreenV2State();
}

class _CourseDetailScreenV2State extends State<CourseDetailScreenV2>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AccessControl _accessControl;
  final StudentLearningService _learningService = StudentLearningService();
  final Set<String> _downloadedContentIds = {};

  late CourseModel _course;
  bool _isLoadingCourse = false;

  List<VideoModel> get _allVideos {
    final list = <VideoModel>[];
    for (final m in _course.modules) {
      list.addAll(m.videos.where((v) => v.contentType == CourseContentType.video));
    }
    list.addAll(_course.standaloneVideos.where((v) => v.contentType == CourseContentType.video));
    return list;
  }

  List<VideoModel> get _allPdfs {
    final list = <VideoModel>[];
    for (final m in _course.modules) {
      list.addAll(m.videos.where((v) => v.contentType == CourseContentType.pdf));
    }
    list.addAll(_course.standaloneVideos.where((v) => v.contentType == CourseContentType.pdf));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _tabController = TabController(length: 2, vsync: this);
    _accessControl = AccessControl(purchases: DummyData.userPurchases);
    _loadPurchases();
    _learningService.reloadCourse(_course.id).then((_) {
      if (mounted) setState(() {});
    });

    if (_course.modules.isEmpty && _course.standaloneVideos.isEmpty) {
      _loadFullCourseDetails();
    } else {
      _autoResolveVideoDurations();
    }
  }

  void _updateLocalVideoDuration(String videoId, double durationMinutes) {
    if (!mounted) return;

    final updatedStandalone = _course.standaloneVideos.map((v) {
      if (v.id == videoId) {
        return v.copyWith(durationMinutes: durationMinutes);
      }
      return v;
    }).toList();

    final updatedModules = _course.modules.map((m) {
      final updatedVideos = m.videos.map((v) {
        if (v.id == videoId) {
          return v.copyWith(durationMinutes: durationMinutes);
        }
        return v;
      }).toList();
      return m.copyWith(videos: updatedVideos);
    }).toList();

    setState(() {
      _course = _course.copyWith(
        standaloneVideos: updatedStandalone,
        modules: updatedModules,
      );
    });
  }

  void _autoResolveVideoDurations() async {
    final courseId = _course.id;
    final bunnyService = BunnyStreamService();
    final courseService = CourseService();

    final targetVideos = <VideoModel>[];
    for (final m in _course.modules) {
      for (final v in m.videos) {
        if (v.durationMinutes == 0.0 && v.bunnyVideoId.isNotEmpty && v.contentType == CourseContentType.video) {
          targetVideos.add(v);
        }
      }
    }
    for (final v in _course.standaloneVideos) {
      if (v.durationMinutes == 0.0 && v.bunnyVideoId.isNotEmpty && v.contentType == CourseContentType.video) {
        targetVideos.add(v);
      }
    }

    if (targetVideos.isEmpty) return;

    for (final video in targetVideos) {
      try {
        final lengthInSeconds = await bunnyService.getVideoLength(video.bunnyVideoId);
        if (lengthInSeconds > 0) {
          final durationMinutes = lengthInSeconds / 60.0;
          await courseService.updateVideoDuration(courseId, video.id, durationMinutes, isPdf: false);
          _updateLocalVideoDuration(video.id, durationMinutes);
        }
      } catch (e) {
        debugPrint('Error auto-resolving video duration for ${video.id}: $e');
      }
    }
  }

  Future<void> _loadFullCourseDetails() async {
    setState(() {
      _isLoadingCourse = true;
    });
    try {
      final fullCourse = await CourseService().getCourseById(widget.course.id);
      if (fullCourse != null && mounted) {
        setState(() {
          _course = fullCourse;
          _isLoadingCourse = false;
        });
        _autoResolveVideoDurations();
      } else if (mounted) {
        setState(() {
          _isLoadingCourse = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading full course details: $e');
      if (mounted) {
        setState(() {
          _isLoadingCourse = false;
        });
      }
    }
  }

  Future<void> _loadPurchases() async {
    try {
      final userId = UserService().currentUserId;
      final realPurchases = await UserService().getUserPurchases(userId);
      if (mounted) {
        setState(() {
          _accessControl = AccessControl(purchases: realPurchases);
        });
      }
    } catch (e) {
      // Keep legacy fallback defaults
    }
  }

  /// True when the current user is the trainer who owns this course.
  /// In that case all access checks should be bypassed.
  bool get _isTrainerViewing {
    if (widget.isTrainerPreview) return true;
    final uid = UserService().currentUserId;
    return uid == _course.trainerId;
  }

  bool get _isCoursePurchased {
    if (_isTrainerViewing) return true;
    for (final p in _accessControl.purchases) {
      if (p.courseId == _course.id && p.purchaseType == PurchaseType.course) {
        if (p.planType == 'limited') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 30) continue; // Expired!
        } else if (p.planType == 'onetime') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 365) continue; // Expired!
        }
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Panel: Course Info
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      right: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildThumbnail(context),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_course.title, style: AppTextStyles.headlineSmall),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(
                                            icon: Icons.access_time_rounded,
                                            label: '${_course.totalDurationMinutes.toInt()}m'),
                                        _InfoChip(
                                            icon: Icons.play_circle_outline_rounded,
                                            label: '${_course.totalVideos} videos'),
                                        _InfoChip(
                                            icon: Icons.folder_rounded,
                                            label: '${_course.modules.length} modules'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildPurchaseBar(context),
                    ],
                  ),
                ),
              ),
              // Right Panel: Tab Content (Playlist/PDFs)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
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
                            borderRadius: BorderRadius.circular(AppRadius.md)),
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
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildVideosTab(),
                          _buildPdfsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildThumbnail(context),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_course.title, style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    _InfoChip(
                        icon: Icons.access_time_rounded,
                        label: '${_course.totalDurationMinutes.toInt()}m'),
                    const SizedBox(width: 10),
                    _InfoChip(
                        icon: Icons.play_circle_outline_rounded,
                        label: '${_course.totalVideos} videos'),
                    const SizedBox(width: 10),
                    _InfoChip(
                        icon: Icons.folder_rounded,
                        label: '${_course.modules.length} modules'),
                  ]),
                ],
              ),
            ),
          ),
          // Tabs
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadius.md)),
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
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(),
                _buildPdfsTab(),
              ],
            ),
          ),
          _buildPurchaseBar(context),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final hasThumbnail = _course.thumbnailUrl.isNotEmpty;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bannerHeight = isLandscape ? 140.0 : 220.0;

    // The emoji/initials fallback widget shown only when there is no image URL
    final fallbackWidget = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Text(
          _course.emoji.isNotEmpty ? _course.emoji : '📘',
          style: const TextStyle(fontSize: 48),
        ),
      ),
    );

    // Trainer badge shown at the bottom of the hero area
    final trainerBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            _course.trainerName,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        // Full-width hero banner
        SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: hasThumbnail
              // Real thumbnail: fill the entire hero area, no duplicate small box
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.heroTag != null
                        ? Hero(
                            tag: widget.heroTag!,
                            child: BunnyStorageImage(
                              imageUrl: _course.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          )
                        : BunnyStorageImage(
                            imageUrl: _course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.textPrimary,
                            ),
                          ),
                    // Gradient scrim so text/icons are readable
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
                    // Trainer badge at the bottom-center
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(child: trainerBadge),
                    ),
                  ],
                )
              // No thumbnail: gradient background + emoji + trainer badge
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.textPrimary,
                        AppColors.textPrimary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.heroTag != null
                          ? Hero(tag: widget.heroTag!, child: fallbackWidget)
                          : fallbackWidget,
                      const SizedBox(height: 12),
                      trainerBadge,
                    ],
                  ),
                ),
        ),

        // Back button always on top
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
      ],
    );
  }

  Widget _buildVideosTab() {
    if (_isLoadingCourse) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    final videos = _allVideos;

    if (videos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.video_library_rounded,
        message: 'No video lectures available for this course.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final canPlay = _isTrainerViewing || _accessControl.canPlayVideo(
          video: video,
          courseId: _course.id,
          moduleId: video.moduleId.isNotEmpty ? video.moduleId : null,
        );

        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + index * 50),
          child: CourseContentRow(
            video: video,
            canPlay: canPlay,
            isDownloaded: _downloadedContentIds.contains(video.id),
            onTap: () => _playVideoOrPdf(video),
            onBuy: () => _showPurchaseSheet(
              highlightVideo: video,
              highlightModule: _course.modules.firstWhere(
                (m) => m.id == video.moduleId,
                orElse: () => _course.modules.isNotEmpty 
                    ? _course.modules.first 
                    : const ModuleModel(id: '', title: '', order: 0),
              ),
            ),
            onDownloadStart: (id) {},
            onDownloadComplete: (id) {
              setState(() {
                _downloadedContentIds.add(id);
              });
            },
            ratingSummary: _learningService.ratingSummary(video.id),
          ),
        );
      },
    );
  }

  Widget _buildPdfsTab() {
    if (_isLoadingCourse) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    final pdfs = _allPdfs;

    if (pdfs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.picture_as_pdf_rounded,
        message: 'No PDF materials available for this course.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: pdfs.length,
      itemBuilder: (context, index) {
        final pdf = pdfs[index];
        final canPlay = _isTrainerViewing || _accessControl.canPlayVideo(
          video: pdf,
          courseId: _course.id,
          moduleId: pdf.moduleId.isNotEmpty ? pdf.moduleId : null,
        );

        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + index * 50),
          child: CourseContentRow(
            video: pdf,
            canPlay: canPlay,
            isDownloaded: _downloadedContentIds.contains(pdf.id),
            onTap: () => _playVideoOrPdf(pdf),
            onBuy: () => _showPurchaseSheet(
              highlightVideo: pdf,
              highlightModule: _course.modules.firstWhere(
                (m) => m.id == pdf.moduleId,
                orElse: () => _course.modules.isNotEmpty 
                    ? _course.modules.first 
                    : const ModuleModel(id: '', title: '', order: 0),
              ),
            ),
            onDownloadStart: (id) {},
            onDownloadComplete: (id) {
              setState(() {
                _downloadedContentIds.add(id);
              });
            },
            ratingSummary: _learningService.ratingSummary(pdf.id),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(icon, size: 36, color: AppColors.textHint),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playVideoOrPdf(VideoModel content) async {
    HapticFeedback.mediumImpact();

    // Resolve the direct video URL from the already-loaded VideoModel so the
    // VideoPlayerScreen doesn't need to make a second Firestore round-trip.
    // Priority: bunnyVideoId (Bunny CDN) > storageUrl (Firebase Storage).
    String? directUrl;
    if (content.bunnyVideoId.isNotEmpty) {
      directUrl = content.bunnyVideoId;
    } else if (content.storageUrl.isNotEmpty) {
      directUrl = content.storageUrl;
    }

    // Debug: log raw URL to help diagnose CDN issues
    debugPrint('[BunnyDebug] Raw URL from Firebase: $directUrl');

    if (content.contentType == CourseContentType.pdf) {
      if (directUrl != null && directUrl.isNotEmpty) {
        // Fix broken bhartamproject.b-cdn.net URL → storage.bunnycdn.com
        final String fixedPdfUrl = BunnyStorageHelper.fixUrl(directUrl);
        final Map<String, String> pdfHeaders =
            BunnyStorageHelper.isStorageUrl(directUrl)
                ? BunnyStorageHelper.storageHeaders
                : const {};

        debugPrint('[BunnyDebug] Fixed PDF URL: $fixedPdfUrl');

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: content.title,
              pdfUrl: fixedPdfUrl,
              headers: pdfHeaders,
            ),
          ),
        );

        PurchaseRecord? coursePurchase;
        try {
          coursePurchase = _accessControl.purchases.firstWhere(
            (p) => p.courseId == _course.id && p.purchaseType == PurchaseType.course,
          );
        } catch (_) {}

        await _learningService.completeVideo(
          courseId: _course.id,
          videoId: content.id,
          totalVideos: _course.totalVideos,
          purchase: coursePurchase,
          limitedTimeDays: _course.limitedTimeDays,
        );
        
        if (mounted) setState(() {});
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF URL not found.')),
          );
        }
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: content.title,
          courseTitle: _course.title,
          courseId: _course.id,
          videoId: content.id,
          totalVideos: _course.totalVideos,
          isPdf: content.contentType == CourseContentType.pdf,
          directVideoUrl: directUrl,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildPurchaseBar(BuildContext context) {
    if (_isCoursePurchased) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: AppShadows.bottomNav,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From', style: AppTextStyles.labelSmall),
              Text('₹${_course.price.toInt()}',
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GradientButton(
              text: 'View Plans',
              borderRadius: AppRadius.pill,
              icon: Icons.shopping_cart_rounded,
              onPressed: () => _showPurchaseSheet(),
            ),
          ),
        ]),
      ),
    );
  }

  void _showPurchaseSheet({ModuleModel? highlightModule, VideoModel? highlightVideo}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseBottomSheet(
        course: _course,
        highlightModule: highlightModule,
        highlightVideo: highlightVideo,
        onPurchaseSuccess: _loadPurchases,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          boxShadow: AppShadows.subtle),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textPrimary)),
      ]),
    );
  }
}

class CourseContentRow extends StatefulWidget {
  final VideoModel video;
  final bool canPlay;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final Function(String videoId) onDownloadStart;
  final Function(String videoId) onDownloadComplete;
  final LectureRatingSummary? ratingSummary;

  const CourseContentRow({
    super.key,
    required this.video,
    required this.canPlay,
    required this.isDownloaded,
    required this.onTap,
    required this.onBuy,
    required this.onDownloadStart,
    required this.onDownloadComplete,
    this.ratingSummary,
  });

  @override
  State<CourseContentRow> createState() => _CourseContentRowState();
}

class _CourseContentRowState extends State<CourseContentRow> {
  bool _isDownloading = false;
  double _progress = 0.0;

  void _simulateDownload() async {
    if (_isDownloading || widget.isDownloaded) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });
    widget.onDownloadStart(widget.video.id);

    // Simulate smooth progress updates
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _progress = i * 0.1;
      });
    }

    if (!mounted) return;
    setState(() {
      _isDownloading = false;
    });
    widget.onDownloadComplete(widget.video.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Downloaded "${widget.video.title}" successfully!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        if (widget.canPlay) {
          widget.onTap();
        } else {
          widget.onBuy();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            // Leading widget — shows video thumbnail with icon overlay,
            // PDF icon, or lock icon depending on content type and access.
            _buildLeadingWidget(),
            const SizedBox(width: AppSpacing.md),
            // Title + Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: widget.canPlay ? AppColors.textPrimary : AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        widget.video.durationFormatted,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                      ),
                      if (widget.ratingSummary != null && widget.ratingSummary!.count > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
                        const SizedBox(width: 2),
                        Text(
                          widget.ratingSummary!.average.toStringAsFixed(1),
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Trailing Action (Buy, Download progress, or Download complete checkmark)
            if (!widget.canPlay)
              // Locked: show Price tag or Free badge
              (widget.video.isFree
                  ? const FreeBadge()
                  : (widget.video.price != null
                      ? PriceTag(price: widget.video.price!)
                      : Icon(Icons.lock_outline_rounded, color: AppColors.textHint, size: 20)))
            else
              // Unlocked: Download controls
              _buildDownloadControl(),
          ],
        ),
      ),
    );
  }

  /// Builds the 44×44 leading widget for a content row.
  /// • Videos: shows the thumbnail image (if available) with a play/lock
  ///   icon overlaid on top. Falls back to icon-only when no thumbnail.
  /// • PDFs & locked items: shows a plain icon, same as before.
  Widget _buildLeadingWidget() {
    final isPdf = widget.video.contentType == CourseContentType.pdf;
    final hasThumbnail = widget.video.resolvedThumbnailUrl.isNotEmpty && !isPdf;

    // Plain icon fallback (also used as the overlay icon)
    final IconData iconData = !widget.canPlay
        ? Icons.lock_rounded
        : (isPdf ? Icons.picture_as_pdf_rounded : Icons.play_arrow_rounded);
    final Color iconColor = widget.canPlay ? AppColors.primary : AppColors.textHint;

    if (!hasThumbnail) {
      // Original icon-only layout
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.canPlay
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(iconData, size: 22, color: iconColor),
      );
    }

    // Thumbnail with icon overlay
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BunnyStorageImage(
              imageUrl: widget.video.resolvedThumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(iconData, size: 22, color: iconColor),
              ),
            ),
            // Semi-transparent scrim so the icon is readable
            Container(
              color: widget.canPlay
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.5),
            ),
            Center(
              child: Icon(iconData, size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadControl() {
    return const SizedBox.shrink();
  }
}
