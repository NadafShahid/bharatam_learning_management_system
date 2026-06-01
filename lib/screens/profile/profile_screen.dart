import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../auth/login_screen.dart';
import '../my_courses/my_courses_screen.dart';
import '../../core/localization.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import '../chat/student_chat_screen.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../services/student_learning_service.dart';
import '../../models/app_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  int _purchasedCoursesCount = 0;
  int _completedCoursesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final userService = UserService();
        final user = await userService.getUserByPhone(phone);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
          await _fetchPurchasedCounts();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPurchasedCounts() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userService = UserService();
      final courseService = CourseService();
      final learningService = StudentLearningService();

      final purchases = await userService.getUserPurchases(_currentUser!.id);
      final allCourses = await courseService.getCourses();

      // Filter unique purchased courses
      final purchasedIds = purchases.map((p) => p.courseId).toSet();
      final purchasedCourses = allCourses.where((c) => purchasedIds.contains(c.id)).toList();

      int completedCount = 0;
      for (final course in purchasedCourses) {
        await learningService.loadCourse(course.id);
        final purchase = purchases.firstWhere(
          (p) => p.courseId == course.id && p.purchaseType == PurchaseType.course,
          orElse: () => purchases.firstWhere(
            (p) => p.courseId == course.id,
            orElse: () => PurchaseRecord(
              userId: _currentUser!.id,
              courseId: course.id,
              purchaseType: PurchaseType.course,
              purchasedAt: DateTime.now(),
            ),
          ),
        );
        if (learningService.isCourseCompleted(
          course.id,
          course.totalVideos,
          purchase: purchase,
          limitedTimeDays: course.limitedTimeDays,
        )) {
          completedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _purchasedCoursesCount = purchasedCourses.length;
          _completedCoursesCount = completedCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching purchased counts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const SizedBox(height: 20),
                FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Text(T.get('profile'), style: AppTextStyles.headlineLarge),
            ),
            const SizedBox(height: 28),
            // Avatar
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.primary,
                    boxShadow: AppShadows.elevated,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                      child: const Center(child: Text('🧑‍🎓', style: TextStyle(fontSize: 44))),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Text(_currentUser?.name ?? (_isLoading ? 'Loading...' : 'Student'), style: AppTextStyles.headlineMedium),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_currentUser?.phoneNumber != null ? '+91 ${_currentUser!.phoneNumber}' : '', style: AppTextStyles.bodyMedium),
              ),
            ),
            const SizedBox(height: 28),
            // Stats — tappable
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.card,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _StatItem(
                    value: _isLoading ? '...' : '$_purchasedCoursesCount', label: T.get('courses'),
                    icon: Icons.menu_book_rounded, color: AppColors.primary,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCoursesScreen(initialTabIndex: 0))).then((_) {
                        _fetchPurchasedCounts();
                      });
                    },
                  ),
                  Container(width: 1, height: 40, color: AppColors.divider),
                  _StatItem(
                    value: _isLoading ? '...' : '$_completedCoursesCount', label: T.get('completed'),
                    icon: Icons.check_circle_rounded, color: AppColors.success,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCoursesScreen(initialTabIndex: 1))).then((_) {
                        _fetchPurchasedCounts();
                      });
                    },
                  ),
                  Container(width: 1, height: 40, color: AppColors.divider),
                  _StatItem(
                    value: _isLoading ? '...' : '$_completedCoursesCount', label: T.get('certificates'),
                    icon: Icons.workspace_premium_rounded, color: const Color(0xFFFFD700),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCoursesScreen(initialTabIndex: 1))).then((_) {
                        _fetchPurchasedCounts();
                      });
                    },
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            // Menu items with staggered entrance
            ..._buildMenuItems(context),
            const SizedBox(height: 32),
            FadeSlideIn(
              delay: const Duration(milliseconds: 950),
              child: Text('Bharatam LMS v1.0.0', style: AppTextStyles.labelSmall),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
      },
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final currentLangLabel = _getLanguageLabel(localeNotifier.value);

    final items = [
      _MenuData(Icons.person_outline_rounded, T.get('edit_profile'), null, false),
      _MenuData(Icons.language_rounded, T.get('language'), currentLangLabel, false),
      _MenuData(Icons.dark_mode_rounded, T.get('dark_mode'), null, false),
      _MenuData(Icons.notifications_none_rounded, T.get('notifications'), null, false),
      _MenuData(Icons.chat_bubble_outline_rounded, T.get('support_chat'), null, false),
      _MenuData(Icons.help_outline_rounded, T.get('help_support'), null, false),
      _MenuData(Icons.info_outline_rounded, T.get('about'), null, false),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      // Dark mode gets a special toggle widget
      if (items[i].label == T.get('dark_mode')) {
        widgets.add(
          FadeSlideIn(
            delay: Duration(milliseconds: 400 + i * 60),
            child: _DarkModeMenuItem(),
          ),
        );
        continue;
      }

      widgets.add(
        FadeSlideIn(
          delay: Duration(milliseconds: 400 + i * 60),
          child: _MenuItem(
            icon: items[i].icon,
            label: items[i].label,
            trailing: items[i].trailing,
            isDestructive: items[i].isDestructive,
            onTap: () => _handleMenuTap(context, items[i].label),
          ),
        ),
      );
    }
    // Logout with gap
    widgets.add(const SizedBox(height: 8));
    widgets.add(
      FadeSlideIn(
        delay: Duration(milliseconds: 400 + items.length * 60),
        child: _MenuItem(
          icon: Icons.logout_rounded,
          label: T.get('logout'),
          isDestructive: true,
          onTap: () => _showLogoutConfirmation(context),
        ),
      ),
    );
    return widgets;
  }

  void _handleMenuTap(BuildContext context, String label) {
    if (label == T.get('edit_profile')) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    } else if (label == T.get('language')) {
      _showLanguagePicker(context);
    } else if (label == T.get('notifications')) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } else if (label == T.get('support_chat')) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentChatScreen()));
    } else if (label == T.get('help_support')) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
    } else if (label == T.get('about')) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
    }
  }

  String _getLanguageLabel(String code) {
    switch (code) {
      case 'hi': return 'हिन्दी';
      case 'mr': return 'मराठी';
      default: return 'English';
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 30),
                ),
                const SizedBox(height: 20),
                Text(T.get('logout_confirm_title'), style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  T.get('logout_confirm_msg'),
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TapScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Center(
                            child: Text(T.get('cancel'), style: AppTextStyles.titleMedium),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TapScale(
                        onTap: () async {
                          HapticFeedback.heavyImpact();
                          
                          // Clear login state
                          const storage = FlutterSecureStorage();
                          await storage.delete(key: 'isLoggedIn');
                          await storage.delete(key: 'role');
                          await storage.delete(key: 'userId');
                          UserService.setCachedUserId(null);

                          if (!context.mounted) return;

                          Navigator.pop(context); // close dialog
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text('Logout', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(T.get('language'), style: AppTextStyles.titleLarge),
                const SizedBox(height: 16),
                const _LanguageTile(code: 'en', label: 'English', nativeLabel: 'English'),
                const _LanguageTile(code: 'hi', label: 'Hindi', nativeLabel: 'हिन्दी'),
                const _LanguageTile(code: 'mr', label: 'Marathi', nativeLabel: 'मराठी'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String code;
  final String label;
  final String nativeLabel;

  const _LanguageTile({
    required this.code,
    required this.label,
    required this.nativeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = localeNotifier.value == code;
    return ListTile(
      onTap: () async {
        HapticFeedback.selectionClick();
        localeNotifier.value = code;
        const storage = FlutterSecureStorage();
        await storage.write(key: 'appLanguage', value: code);
        if (context.mounted) Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(nativeLabel, style: AppTextStyles.titleMedium),
      subtitle: Text(label, style: AppTextStyles.bodySmall),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
    );
  }
}

class _MenuData {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  const _MenuData(this.icon, this.label, this.trailing, this.isDestructive);
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatItem({required this.value, required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.headlineMedium),
        Text(label, style: AppTextStyles.labelSmall),
      ]),
    );
  }
}

/// Dark mode toggle menu item with animated switch
class _DarkModeMenuItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ValueListenableBuilder<bool>(
        valueListenable: darkModeNotifier,
        builder: (context, isDark, _) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.subtle,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(T.get('dark_mode'), style: AppTextStyles.titleMedium)),
                Switch.adaptive(
                  value: isDark,
                  onChanged: (value) {
                    HapticFeedback.mediumImpact();
                    darkModeNotifier.value = value;
                  },
                  activeColor: AppColors.secondary,
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.trailing, this.isDestructive = false, required this.onTap});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? AppColors.error : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) {
          _tapController.reverse();
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => _tapController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.subtle,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (widget.isDestructive ? AppColors.error : AppColors.primary).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, size: 20, color: widget.isDestructive ? AppColors.error : AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(widget.label, style: AppTextStyles.titleMedium.copyWith(color: color))),
                if (widget.trailing != null)
                  Text(widget.trailing!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
