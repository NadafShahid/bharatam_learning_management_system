import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/student_learning_service.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../services/bunny_stream_service.dart';
import '../../models/app_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/video_list_item.dart';
import '../certificate/certificate_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String courseTitle;
  final String courseId;
  final String videoId;
  final int totalVideos;
  final bool isPdf;
  /// When provided the player uses this URL directly without fetching from
  /// Firestore. Used for trainer preview so already-loaded video URLs are
  /// not re-fetched (which can fail due to security rules or latency).
  final String? directVideoUrl;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.courseTitle,
    this.courseId = 'demo_course',
    this.videoId = 'demo_video',
    this.totalVideos = 1,
    this.isPdf = false,
    this.directVideoUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const MethodChannel _contentProtectionChannel =
      MethodChannel('bharatam_lms/content_protection');

  /// Bunny Stream library ID — must match BunnyStreamService.libraryId
  static const String _bunnyLibraryId = '663705';

  final StudentLearningService _learningService = StudentLearningService();
  String _studentName = 'Student';
  bool _isCompleted = false;
  bool _isCourseCompleted = false;
  int? _studentRating;
  PurchaseRecord? _coursePurchase;
  int? _limitedTimeDays;
  double _dbDurationMinutes = 0.0;

  // Video playing state variables
  String? _videoUrl;
  bool _isLoadingVideo = true;
  String? _errorMessage;
  VideoPlayerController? _videoPlayerController;
  WebViewController? _webViewController;
  bool _isBunnyUrl = false;
  String? _bunnyEmbedUrl;
  bool _isMuted = false;
  bool _isAudioOnly = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isFullscreen = false;

  Future<void> _enableContentProtection() async {
    try {
      await _contentProtectionChannel.invokeMethod<void>(
        'setProtectedContent',
        <String, bool>{'enabled': true},
      );
    } catch (_) {}
  }

  Future<void> _disableContentProtection() async {
    try {
      await _contentProtectionChannel.invokeMethod<void>(
        'setProtectedContent',
        <String, bool>{'enabled': false},
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _enableContentProtection();
    _loadLearningState();
    _fetchVideoUrl();
  }

  @override
  void dispose() {
    _disableContentProtection();
    _exitFullscreenMode();
    _controlsTimer?.cancel();
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _loadLearningState() async {
    await _learningService.reloadCourse(widget.courseId);
    final name = await _loadStudentName();

    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final user = await UserService().getUserByPhone(phone);
        if (user != null) {
          final purchases = await UserService().getUserPurchases(user.id);
          _coursePurchase = purchases.firstWhere(
            (p) => p.courseId == widget.courseId && p.purchaseType == PurchaseType.course,
            orElse: () => purchases.firstWhere(
              (p) => p.courseId == widget.courseId,
              orElse: () => PurchaseRecord(
                userId: user.id,
                courseId: widget.courseId,
                purchaseType: PurchaseType.course,
                purchasedAt: DateTime.now(),
              ),
            ),
          );
        }
      }
    } catch (_) {}

    try {
      final courses = await CourseService().getCourses();
      final course = courses.firstWhere((c) => c.id == widget.courseId);
      _limitedTimeDays = course.limitedTimeDays;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _studentName = name;
      _isCompleted = _learningService.isVideoCompleted(
            widget.courseId,
            widget.videoId,
          ) ||
          StudentLearningService.testingBypassCompletionGate;
      _isCourseCompleted = _learningService.isCourseCompleted(
        widget.courseId,
        widget.totalVideos,
        purchase: _coursePurchase,
        limitedTimeDays: _limitedTimeDays,
      );
      _studentRating = _learningService.studentRating(
        widget.courseId,
        widget.videoId,
      );
    });
  }

  Future<void> _fetchVideoUrl() async {
    // ── Trainer preview shortcut ──────────────────────────────────────────
    // If a URL was already loaded from Firestore by CourseService and passed
    // in directly, skip the redundant second fetch and use it immediately.
    if (widget.directVideoUrl != null && widget.directVideoUrl!.isNotEmpty) {
      final rawDirect = widget.directVideoUrl!.trim();
      // If the passed URL is a raw Bunny GUID (not a full URL), build the embed URL
      final resolvedDirect = (!rawDirect.startsWith('http') && rawDirect.isNotEmpty)
          ? 'https://iframe.mediadelivery.net/embed/$_bunnyLibraryId/$rawDirect'
          : rawDirect;
      setState(() {
        _videoUrl = resolvedDirect;
        _isLoadingVideo = false;
      });
      if (!widget.isPdf) {
        _initializeVideoPlayer(resolvedDirect);
      }
      return;
    }

    // ── Legacy demo bypass ────────────────────────────────────────────────
    if (widget.courseId == 'course_legacy' || widget.videoId.startsWith('legacy_')) {
      // Legacy bypass support to keep demo content working perfectly!
      setState(() {
        _videoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
        _isLoadingVideo = false;
      });
      if (!widget.isPdf) {
        _initializeVideoPlayer(_videoUrl!);
      }
      return;
    }

    setState(() {
      _isLoadingVideo = true;
      _errorMessage = null;
    });

    try {
      final docPath = widget.isPdf
          ? '/bharatam_courses/${widget.courseId}/pdfs/${widget.videoId}'
          : '/bharatam_courses/${widget.courseId}/videos/${widget.videoId}';
      
      final docSnapshot = await FirebaseFirestore.instance.doc(docPath).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        String? url;
        String? bunnyVideoId;
        if (data != null) {
          _dbDurationMinutes = data['durationMinutes'] != null
              ? (double.tryParse(data['durationMinutes'].toString()) ?? 0.0)
              : 0.0;
          if (data['bunnyVideoId'] != null && data['bunnyVideoId'].toString().isNotEmpty) {
            final rawId = data['bunnyVideoId'].toString().trim();
            bunnyVideoId = rawId;
            if (rawId.startsWith('http')) {
              url = rawId;
            } else {
              url = 'https://iframe.mediadelivery.net/embed/$_bunnyLibraryId/$rawId';
            }
          } else if (data['storageUrl'] != null && data['storageUrl'].toString().isNotEmpty) {
            url = data['storageUrl'].toString();
            if (_detectBunnyUrl(url)) {
              try {
                final uri = Uri.parse(url);
                final segments = uri.pathSegments;
                if (segments.isNotEmpty) {
                  bunnyVideoId = segments[0];
                }
              } catch (_) {}
            }
          }
        }

        if (url != null) {
          setState(() {
            _videoUrl = url;
            _isLoadingVideo = false;
          });
          if (!widget.isPdf) {
            _initializeVideoPlayer(url);
          }
          if (bunnyVideoId != null && bunnyVideoId.isNotEmpty && !bunnyVideoId.startsWith('http') && _dbDurationMinutes == 0.0) {
            _autoResolveBunnyDuration(bunnyVideoId);
          }
        } else {
          setState(() {
            _errorMessage = 'Video URL not found in database.';
            _isLoadingVideo = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Content metadata not found in database.';
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading content: $e';
        _isLoadingVideo = false;
      });
    }
  }

  void _autoResolveBunnyDuration(String bunnyVideoId) async {
    try {
      final lengthInSeconds = await BunnyStreamService().getVideoLength(bunnyVideoId);
      if (lengthInSeconds > 0) {
        final durationMinutes = lengthInSeconds / 60.0;
        _dbDurationMinutes = durationMinutes;
        await CourseService().updateVideoDuration(widget.courseId, widget.videoId, durationMinutes, isPdf: widget.isPdf);
      }
    } catch (e) {
      debugPrint('Error auto-resolving Bunny video duration in player: $e');
    }
  }

  void _autoResolveDirectDuration() async {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    try {
      final duration = _videoPlayerController!.value.duration;
      if (duration.inSeconds > 0) {
        final durationMinutes = duration.inSeconds / 60.0;
        _dbDurationMinutes = durationMinutes;
        await CourseService().updateVideoDuration(widget.courseId, widget.videoId, durationMinutes, isPdf: widget.isPdf);
      }
    } catch (e) {
      debugPrint('Error auto-resolving direct video duration in player: $e');
    }
  }

  /// Returns true if the given URL is a Bunny.net CDN/Stream URL
  bool _detectBunnyUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('mediadelivery.net') ||
        lower.contains('b-cdn.net') ||
        lower.contains('bunnycdn.com') ||
        lower.contains('bunny.net');
  }

  /// Converts any Bunny.net play/CDN URL into the official embed iframe URL
  String _toBunnyEmbedUrl(String url) {
    // Already an embed URL — return as-is
    if (url.contains('mediadelivery.net/embed/')) return url;

    // Convert /play/{libId}/{videoId} → /embed/{libId}/{videoId}
    if (url.contains('iframe.mediadelivery.net/play/')) {
      return url.replaceFirst('/play/', '/embed/');
    }
    if (url.contains('player.mediadelivery.net/embed/')) {
      return url; // already embed
    }

    // b-cdn.net pull-zone HLS URL: https://{zone}.b-cdn.net/{videoId}/playlist.m3u8
    // Extract the videoId from the path and build the proper embed URL.
    if (url.contains('.b-cdn.net/')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final videoId = segments[0]; // First path segment is the Bunny GUID
          return 'https://iframe.mediadelivery.net/embed/$_bunnyLibraryId/$videoId';
        }
      } catch (_) {}
    }

    // Fallback — return as-is and let the WebView try to load it
    return url;
  }

  void _initializeVideoPlayer(String url) {
    final isBunny = _detectBunnyUrl(url);

    if (isBunny) {
      // Use WebView with Bunny's official iframe embed player
      // This is the most reliable way — no 401/403, no HLS token issues
      final embedUrl = _toBunnyEmbedUrl(url);
      final htmlContent = _buildBunnyPlayerHtml(embedUrl);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() {});
          },
        ))
        ..loadHtmlString(htmlContent);

      setState(() {
        _webViewController = controller;
        _bunnyEmbedUrl = embedUrl;
        _isBunnyUrl = true;
      });
    } else {
      // Non-Bunny URL: use standard video_player (ExoPlayer on Android)
      // e.g. Firebase Storage direct MP4 URLs
      VideoFormat? formatHint;
      final urlLower = url.toLowerCase();
      if (urlLower.contains('.m3u8') || urlLower.contains('.hls')) {
        formatHint = VideoFormat.hls;
      } else if (urlLower.contains('.mpd')) {
        formatHint = VideoFormat.dash;
      }

      final uri = Uri.parse(url);
      _videoPlayerController = VideoPlayerController.networkUrl(
        uri,
        formatHint: formatHint,
        httpHeaders: const <String, String>{},
      )
        ..initialize().then((_) {
          if (!mounted) return;
          _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
          setState(() {});
          _videoPlayerController!.play();
          _startProgressListener();
          _resetControlsTimer();
          if (_dbDurationMinutes == 0.0) {
            _autoResolveDirectDuration();
          }
        }).catchError((error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Failed to load media: $error';
          });
        });

      setState(() {
        _bunnyEmbedUrl = null;
        _isBunnyUrl = false;
      });
    }
  }

  String _buildBunnyPlayerHtml(String embedUrl) {
    final muted = _isMuted ? 'true' : 'false';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe
    src="$embedUrl?autoplay=true&loop=false&muted=$muted&preload=true"
    allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
    loading="eager"
  ></iframe>
</body>
</html>''';
  }

  void _startProgressListener() {
    _videoPlayerController?.addListener(_videoPlayerListener);
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isBunnyUrl && _webViewController != null && _bunnyEmbedUrl != null) {
      _webViewController!.loadHtmlString(_buildBunnyPlayerHtml(_bunnyEmbedUrl!));
    } else if (_videoPlayerController != null) {
      _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
    }

    _resetControlsTimer();
  }

  void _toggleAudioOnly() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAudioOnly = !_isAudioOnly;
      _showControls = true;
    });
    _resetControlsTimer();
  }

  void _videoPlayerListener() {
    if (!mounted || _videoPlayerController == null) return;
    final value = _videoPlayerController!.value;
    
    // Check if video is finished
    if (value.isInitialized &&
        value.position >= value.duration &&
        !_isCompleted) {
      _markLectureComplete();
    }
    
    setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetControlsTimer();
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoPlayerController?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleFullscreen() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      _enterFullscreenMode();
    } else {
      _exitFullscreenMode();
    }
  }

  Future<void> _enterFullscreenMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreenMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _closeVideoScreen() async {
    HapticFeedback.lightImpact();

    if (_isFullscreen) {
      setState(() {
        _isFullscreen = false;
      });
      await _exitFullscreenMode();
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<String> _loadStudentName() async {
    const storage = FlutterSecureStorage();
    final phone = await storage.read(key: 'userPhone');
    if (phone != null) {
      final user = await UserService().getUserByPhone(phone);
      return user?.name ?? 'Student';
    }
    return 'Student';
  }

  Future<void> _markLectureComplete() async {
    HapticFeedback.mediumImpact();
    final completedCourse = await _learningService.completeVideo(
      courseId: widget.courseId,
      videoId: widget.videoId,
      totalVideos: widget.totalVideos,
      purchase: _coursePurchase,
      limitedTimeDays: _limitedTimeDays,
    );
    if (!mounted) return;
    setState(() {
      _isCompleted = true;
      _isCourseCompleted = completedCourse;
    });
    await _showRatingSheet();
  }

  Future<void> _showRatingSheet() async {
    int selectedRating = _studentRating ?? 5;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Rate this lecture', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedRating = value);
                      },
                      icon: Icon(
                        value <= selectedRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFFB300),
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await _learningService.submitRating(
                        courseId: widget.courseId,
                        videoId: widget.videoId,
                        rating: selectedRating,
                      );
                      if (!mounted) return;
                      setState(() => _studentRating = selectedRating);
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Thanks. Your lecture rating is saved.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Submit Rating'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayerArea() {
    if (widget.isPdf) {
      // PDF representation keeping the exact premium original design
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TapScale(
            onTap: () => HapticFeedback.lightImpact(),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'PDF learning resource',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white60),
            ),
          ),
        ],
      );
    }

    if (_isLoadingVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading lecture video...',
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchVideoUrl,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // --- Bunny.net Video: use WebView with official iframe embed player ---
    if (_isBunnyUrl && _webViewController != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: WebViewWidget(controller: _webViewController!),
            ),
          ),
          if (_isAudioOnly)
            Positioned.fill(child: _buildAudioOnlySurface()),
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAudioOnlyButton(),
                const SizedBox(width: 8),
                _buildMuteButton(),
                const SizedBox(width: 8),
                _buildFullscreenButton(),
              ],
            ),
          ),
        ],
      );
    }

    // --- Non-Bunny direct MP4 / Firebase Storage URL: use video_player ---
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing player...',
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: _isAudioOnly
                ? _buildAudioOnlySurface()
                : VideoPlayer(_videoPlayerController!),
          ),
          _buildPlayerControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildPlayerControlsOverlay() {
    if (_videoPlayerController == null) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black45, // Dim background for controls contrast
        child: Stack(
          children: [
            // Center Controls (10s seek and Play/Pause)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      final newPos = _videoPlayerController!.value.position - const Duration(seconds: 10);
                      _videoPlayerController!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                      _resetControlsTimer();
                    },
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: Icon(
                      _videoPlayerController!.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_videoPlayerController!.value.isPlaying) {
                          _videoPlayerController!.pause();
                        } else {
                          _videoPlayerController!.play();
                          _resetControlsTimer();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      final maxDuration = _videoPlayerController!.value.duration;
                      final newPos = _videoPlayerController!.value.position + const Duration(seconds: 10);
                      _videoPlayerController!.seekTo(newPos > maxDuration ? maxDuration : newPos);
                      _resetControlsTimer();
                    },
                  ),
                ],
              ),
            ),
            
            // Bottom Timeline & Volume/Fullscreen
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0x00000000), Color(0xD9000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _videoPlayerController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primary,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatDuration(_videoPlayerController!.value.position)} / ${_formatDuration(_videoPlayerController!.value.duration)}',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isAudioOnly
                                    ? Icons.headphones_rounded
                                    : Icons.headphones_outlined,
                                color: _isAudioOnly ? AppColors.primary : Colors.white,
                                size: 20,
                              ),
                              tooltip: _isAudioOnly ? 'Video mode' : 'Audio only',
                              onPressed: _toggleAudioOnly,
                            ),
                            IconButton(
                              icon: Icon(
                                _isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: _isMuted ? 'Unmute' : 'Mute',
                              onPressed: _toggleMute,
                            ),
                            IconButton(
                              icon: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOnlyButton() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        icon: Icon(
          _isAudioOnly ? Icons.headphones_rounded : Icons.headphones_outlined,
          color: _isAudioOnly ? AppColors.primary : Colors.white,
        ),
        tooltip: _isAudioOnly ? 'Video mode' : 'Audio only',
        onPressed: _toggleAudioOnly,
      ),
    );
  }

  Widget _buildMuteButton() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        icon: Icon(
          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
        ),
        tooltip: _isMuted ? 'Unmute' : 'Mute',
        onPressed: _toggleMute,
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        icon: Icon(
          _isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
        ),
        tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
        onPressed: _toggleFullscreen,
      ),
    );
  }

  Widget _buildAudioOnlySurface() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Audio only',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratingSummary = _learningService.ratingSummary(widget.videoId);

    // Fullscreen Layout
    if (_isFullscreen && !widget.isPdf) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _closeVideoScreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            top: false,
            bottom: false,
            child: SizedBox.expand(
              child: _buildVideoPlayerArea(),
            ),
          ),
        ),
      );
    }

    // Standard Portrait Layout
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 260,
                color: const Color(0xFF1A1D26),
                child: _buildVideoPlayerArea(),
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
                    onPressed: _closeVideoScreen,
                  ),
                ),
              ),
              if (!widget.isPdf && _videoUrl != null && _errorMessage == null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFullscreen,
                    ),
                  ),
                ),
            ],
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.courseTitle, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text(widget.title, style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _LectureStatusChip(
                        icon: _isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        label: _isCompleted ? 'Rating enabled' : 'Complete to rate',
                        color: _isCompleted ? AppColors.success : AppColors.primary,
                      ),
                      _LectureStatusChip(
                        icon: Icons.star_rounded,
                        label: ratingSummary.count == 0
                            ? 'No ratings yet'
                            : '${ratingSummary.average.toStringAsFixed(1)} (${ratingSummary.count})',
                        color: const Color(0xFFFFB300),
                      ),
                      if (_studentRating != null)
                        _LectureStatusChip(
                          icon: Icons.rate_review_rounded,
                          label: 'Your rating: $_studentRating',
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: StudentLearningService.testingBypassCompletionGate
                              ? _showRatingSheet
                              : (_isCompleted
                                  ? _showRatingSheet
                                  : _markLectureComplete),
                          icon: Icon(
                            _isCompleted
                                ? Icons.star_rounded
                                : Icons.done_all_rounded,
                          ),
                          label: Text(
                            StudentLearningService.testingBypassCompletionGate
                                ? (_studentRating == null ? 'Give Rating' : 'Update Rating')
                                : (_isCompleted ? 'Update Rating' : 'Mark Complete'),
                          ),
                        ),
                      ),
                      if (_isCourseCompleted) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CertificateScreen(
                                    courseName: widget.courseTitle,
                                    userName: _studentName,
                                    completedAt:
                                        _learningService.courseCompletionDate(
                                      widget.courseId,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.workspace_premium_rounded),
                            label: const Text('Certificate'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class _LectureStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LectureStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
