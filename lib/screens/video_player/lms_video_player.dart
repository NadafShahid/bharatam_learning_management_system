import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player.dart';
import '../../theme/app_theme.dart';

/// A premium, production-level Video Player widget built using [better_player_plus].
/// Highly optimized for HLS streaming, caching, performance, and custom branding.
class LmsVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? subtitleUrl;
  final String title;
  final Duration? initialPosition;
  final VoidCallback? onVideoCompleted;
  final Function(Duration position, Duration duration)? onProgressChanged;
  final Function(bool isPlaying)? onPlayStateChanged;
  final Map<String, String>? qualities; // For fallback MP4 multiple qualities
  final String? drmToken; // DRM license token for future proofing

  const LmsVideoPlayer({
    super.key,
    required this.videoUrl,
    this.subtitleUrl,
    required this.title,
    this.initialPosition,
    this.onVideoCompleted,
    this.onProgressChanged,
    this.onPlayStateChanged,
    this.qualities,
    this.drmToken,
  });

  @override
  State<LmsVideoPlayer> createState() => _LmsVideoPlayerState();
}

class _LmsVideoPlayerState extends State<LmsVideoPlayer> with WidgetsBindingObserver {
  BetterPlayerController? _betterPlayerController;
  bool _isPlayerInitialized = false;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant LmsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video URL changes, reinitialize the player with the new video
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_betterPlayerController == null) return;

    if (state == AppLifecycleState.paused) {
      // Pause video when app goes to background to save memory and battery
      _betterPlayerController!.pause();
    }
  }

  void _disposePlayer() {
    if (_betterPlayerController != null) {
      _betterPlayerController!.removeEventsListener(_onPlayerEvent);
      _betterPlayerController!.dispose();
      _betterPlayerController = null;
    }
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isPlayerInitialized = false;
      _hasTriggeredCompletion = false;
    });

    // 1. Dispose old controller if any
    _disposePlayer();

    // 2. Set up buffering configuration for low-latency & smooth mobile streaming
    const bufferingConfig = BetterPlayerBufferingConfiguration(
      minBufferMs: 15000,       // 15 seconds minimum buffered to start playback
      maxBufferMs: 50000,       // 50 seconds maximum buffer
      bufferForPlaybackMs: 2500, // Wait for 2.5s of buffer when starting
      bufferForPlaybackAfterRebufferMs: 5000, // Wait for 5s of buffer after rebuffering
    );

    // 3. Set up player configuration with premium UI and custom behaviors
    final betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      allowedScreenSleep: false, // Keep screen awake during playback
      autoDetectFullscreenDeviceOrientation: true,
      
      // Auto-rotation handling
      deviceOrientationsOnFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
      ],

      // Buffering configuration
      bufferingConfiguration: bufferingConfig,

      // Custom Placeholder / Loading / Error states for premium UX
      placeholder: _buildPlaceholder(),
      
      // Custom material controls
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableSkips: true,
        skipBackMilliseconds: 10000,
        skipForwardMilliseconds: 10000,
        enableFullscreen: true,
        enableMute: true,
        enableProgressText: true,
        enablePlayPause: true,
        enableAudioTracks: true,
        enableQualities: true,
        enableSubtitles: widget.subtitleUrl != null,
        enablePlaybackSpeed: true,
        
        // Quality, Speeds, and overflow settings
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        
        // Brand Coloring & Styling (Matches App Theme)
        progressBarPlayedColor: AppColors.primary,
        progressBarHandleColor: AppColors.primary,
        progressBarBufferedColor: Colors.white24,
        progressBarBackgroundColor: Colors.white12,
        controlBarColor: Colors.black.withOpacity(0.6),
        loadingColor: AppColors.primary,
        
        // Custom Loaders
        loadingWidget: _buildLoadingWidget(),
        
        // Icons
        playIcon: Icons.play_arrow_rounded,
        pauseIcon: Icons.pause_rounded,
        fullscreenEnableIcon: Icons.fullscreen_rounded,
        fullscreenDisableIcon: Icons.fullscreen_exit_rounded,
        skipBackIcon: Icons.replay_10_rounded,
        skipForwardIcon: Icons.forward_10_rounded,
      ),
    );

    // 4. Determine DataSource type and options (HLS vs Progressive MP4)
    final bool isHls = widget.videoUrl.contains('.m3u8') || widget.videoUrl.contains('/hls/');
    
    // Caching configuration (Highly optimized for mobile streaming)
    // Caching is enabled for progressive formats. Note: HLS caching requires specific configuration on native side.
    final cacheConfig = BetterPlayerCacheConfiguration(
      useCache: !isHls, // Enable caching for progressive videos (like MP4)
      maxCacheSize: 200 * 1024 * 1024, // 200 MB maximum caching size
      maxCacheFileSize: 25 * 1024 * 1024, // 25 MB max per file
      key: widget.videoUrl,
    );

    // Subtitle setup if available
    List<BetterPlayerSubtitlesSource>? subtitles;
    if (widget.subtitleUrl != null && widget.subtitleUrl!.isNotEmpty) {
      subtitles = [
        BetterPlayerSubtitlesSource.single(
          type: BetterPlayerSubtitlesSourceType.network,
          url: widget.subtitleUrl!,
          name: "English",
          selectedByDefault: true,
        )
      ];
    }

    // Future-proof DRM integration structure
    BetterPlayerDrmConfiguration? drmConfiguration;
    if (widget.drmToken != null && widget.drmToken!.isNotEmpty) {
      drmConfiguration = BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.widevine,
        licenseUrl: "https://license.example.com/widevine",
        headers: {
          "Authorization": "Bearer ${widget.drmToken}",
        },
      );
    }

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.videoUrl,
      qualities: widget.qualities,
      subtitles: subtitles,
      cacheConfiguration: cacheConfig,
      drmConfiguration: drmConfiguration,
      // For Bunny Stream or Firebase Storage with security headers
      headers: {
        "Referer": "https://bharatamlms.example.com", // Bunny Stream Referer Header locking
        "User-Agent": "BharatAMLMS-App-Android-iOS",
      },
    );

    // 5. Build and attach the controller
    final controller = BetterPlayerController(betterPlayerConfiguration);
    await controller.setupDataSource(dataSource);
    
    // Resume position if provided
    if (widget.initialPosition != null && widget.initialPosition! > Duration.zero) {
      await controller.seekTo(widget.initialPosition!);
    }

    _betterPlayerController = controller;
    _betterPlayerController!.addEventsListener(_onPlayerEvent);

    if (mounted) {
      setState(() {
        _isPlayerInitialized = true;
      });
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (_betterPlayerController == null) return;

    // Monitor playback state for UI updates/callbacks
    if (event.betterPlayerEventType == BetterPlayerEventType.play) {
      widget.onPlayStateChanged?.call(true);
    } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
      widget.onPlayStateChanged?.call(false);
    }

    // Monitor progress
    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      final videoVal = _betterPlayerController!.videoPlayerController!.value;
      widget.onProgressChanged?.call(videoVal.position, videoVal.duration);
    }

    // Monitor completion
    if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
      if (!_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;
        widget.onVideoCompleted?.call();
      }
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white24,
          size: 72,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerInitialized || _betterPlayerController == null) {
      return Container(
        color: Colors.black,
        child: _buildLoadingWidget(),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: BetterPlayer(
        controller: _betterPlayerController!,
      ),
    );
  }
}
