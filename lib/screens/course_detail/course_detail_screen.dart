import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/video_list_item.dart';
import '../../widgets/animations.dart';
import '../video_player/video_player_screen.dart';
import '../payment/payment_sheet.dart';
import '../../services/subscription_service.dart';
import '../../services/student_learning_service.dart';
import '../../services/user_service.dart';
import '../../models/app_models.dart';

class CourseDetailScreen extends StatefulWidget {
  final String title;
  final String emoji;
  final String? heroTag;
  const CourseDetailScreen({super.key, required this.title, required this.emoji, this.heroTag});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _playingIndex = 0;
  bool _isSubscribed = false;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final StudentLearningService _learningService = StudentLearningService();
  final String _trainerId = 'trainer_001'; // Default for v1
  final String _courseId = 'course_legacy';
  List<PurchaseRecord> _purchases = [];

  final _videos = [
    {'id': 'legacy_v001', 'title': 'Introduction & Overview', 'duration': '12:30', 'locked': false},
    {'id': 'legacy_v002', 'title': 'History and Origins', 'duration': '18:45', 'locked': false},
    {'id': 'legacy_v003', 'title': 'Core Fundamentals', 'duration': '22:10', 'locked': false},
    {'id': 'legacy_v004', 'title': 'Advanced Part 1', 'duration': '25:00', 'locked': true},
    {'id': 'legacy_v005', 'title': 'Advanced Part 2', 'duration': '20:15', 'locked': true},
    {'id': 'legacy_v006', 'title': 'Practical Applications', 'duration': '28:30', 'locked': true},
    {'id': 'legacy_v007', 'title': 'Case Studies', 'duration': '15:40', 'locked': true},
    {'id': 'legacy_v008', 'title': 'Final Summary', 'duration': '10:20', 'locked': true},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _learningService.loadCourse(_courseId).then((_) {
      if (mounted) setState(() {});
    });
    _checkSubscription();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    try {
      final userId = UserService().currentUserId;
      final realPurchases = await UserService().getUserPurchases(userId);
      if (mounted) {
        setState(() {
          _purchases = realPurchases;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  bool get _isCoursePurchased {
    for (final p in _purchases) {
      if (p.courseId == _courseId && p.purchaseType == PurchaseType.course) {
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

  Future<void> _checkSubscription() async {
    final subscribed = await _subscriptionService.isSubscribed(_trainerId);
    if (mounted) {
      setState(() => _isSubscribed = subscribed);
    }
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

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
                                    Text(widget.title, style: AppTextStyles.headlineSmall),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(icon: Icons.access_time_rounded, label: '4h 30m'),
                                        _InfoChip(icon: Icons.play_circle_outline_rounded, label: '8 lessons'),
                                        _InfoChip(icon: Icons.star_rounded, label: '4.8'),
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
              // Right Panel: Tab Content (Playlist/Description)
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
                          Tab(text: 'Playlist'),
                          Tab(text: 'Description'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPlaylist(),
                          _buildDescription(),
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
          // Thumbnail
          _buildThumbnail(context),
          // Info
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    _InfoChip(icon: Icons.access_time_rounded, label: '4h 30m'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.play_circle_outline_rounded, label: '8 lessons'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.star_rounded, label: '4.8'),
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
                indicator: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.labelLarge,
                tabs: const [Tab(text: 'Playlist'), Tab(text: 'Description')],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(
            child: TabBarView(controller: _tabController, children: [
              _buildPlaylist(),
              _buildDescription(),
            ]),
          ),
          // Purchase bar
          _buildPurchaseBar(context),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bannerHeight = isLandscape ? 140.0 : 240.0;

    final emojiWidget = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 48))),
    );

    return Stack(children: [
      Container(
        width: double.infinity, height: bannerHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.textPrimary, AppColors.textPrimary.withValues(alpha: 0.8)]),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          widget.heroTag != null
              ? Hero(tag: widget.heroTag!, child: emojiWidget)
              : emojiWidget,
          const SizedBox(height: 16),
          TapScale(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => VideoPlayerScreen(
                    title: _videos[_playingIndex]['title'] as String,
                    courseTitle: widget.title,
                    courseId: _courseId,
                    videoId: _videos[_playingIndex]['id'] as String,
                    totalVideos: _videos.length,
                  ),
                  transitionsBuilder: (_, animation, _, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            },
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary, boxShadow: AppShadows.elevated),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
          ),
        ])),
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 8, left: 12,
        child: Container(
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
          child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
      ),
    ]);
  }

  Widget _buildPlaylist() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final v = _videos[index];
        final rating = _learningService.ratingSummary(v['id'] as String);
        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + index * 60),
          child: Column(
            children: [
              VideoListItem(
                title: v['title'] as String, duration: v['duration'] as String, index: index,
                isLocked: v['locked'] as bool, isPlaying: _playingIndex == index,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _playingIndex = index);
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 8, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB300)),
                    const SizedBox(width: 4),
                    Text(
                      rating.count == 0
                          ? 'No ratings yet'
                          : '${rating.average.toStringAsFixed(1)} (${rating.count} ratings)',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescription() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('About this course', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 10),
        Text(
          'This course takes you on a journey through classical Indian knowledge. '
          'Designed for all learners with interactive exercises, quizzes, and practical applications. '
          'Earn a verified certificate upon completion.',
          style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
        ),
        const SizedBox(height: 20),
        Text("What you'll learn", style: AppTextStyles.titleLarge),
        const SizedBox(height: 10),
        ...['Foundation concepts', 'Historical context', 'Practical applications', 'Advanced techniques'].map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.check_rounded, size: 14, color: AppColors.success)),
            const SizedBox(width: 10),
            Text(i, style: AppTextStyles.bodyMedium),
          ]),
        )),
        const SizedBox(height: AppSpacing.xxl),
        
        // Instructor Section
        Text('Instructor', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3E5F5)),
                child: const Center(child: Text('👨‍🏫', style: TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. Sharma', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 4),
                    Text('Vedic Math Expert', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                  ],
                ),
              ),
              TapScale(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final messenger = ScaffoldMessenger.of(context);
                  if (_isSubscribed) {
                    await _subscriptionService.unsubscribe(_trainerId);
                  } else {
                    await _subscriptionService.subscribe(_trainerId);
                  }
                  if (!mounted) return;
                  setState(() => _isSubscribed = !_isSubscribed);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(_isSubscribed 
                          ? 'Subscribed to Dr. Sharma! You will be notified of new videos.' 
                          : 'Unsubscribed from Dr. Sharma.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSubscribed ? AppColors.surface : AppColors.primary,
                    border: Border.all(color: _isSubscribed ? AppColors.border : AppColors.primary),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSubscribed ? Icons.notifications_active_rounded : Icons.person_add_rounded,
                        size: 16,
                        color: _isSubscribed ? AppColors.primary : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSubscribed ? 'Subscribed' : 'Subscribe',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: _isSubscribed ? AppColors.primary : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildPurchaseBar(BuildContext context) {
    if (_isCoursePurchased) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.bottomNav, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Price', style: AppTextStyles.labelSmall),
          Text('₹1,499', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: GradientButton(
          text: 'Purchase Now', borderRadius: AppRadius.pill, icon: Icons.shopping_cart_rounded,
          onPressed: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
              transitionAnimationController: AnimationController(
                vsync: Navigator.of(context),
                duration: const Duration(milliseconds: 400),
              ),
              builder: (_) => PaymentSheet(courseTitle: widget.title),
            );
          },
        )),
      ])),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(100), boxShadow: AppShadows.subtle),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.primary), const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary)),
      ]),
    );
  }
}
