import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/course_grid_card.dart';
import '../../widgets/animations.dart';
import '../course_detail/course_detail_screen_v2.dart';
import '../../models/app_models.dart';
import '../../services/course_service.dart';
import '../../services/category_service.dart';
import '../../core/localization.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  int _selectedFilter = 0;
  List<String> _filters = ['All'];
  
  static const _storage = FlutterSecureStorage();
  static const _recentSearchesKey = 'recent_searches';
  List<String> _recentSearches = [];
  bool _hasQuery = false;
  
  List<CourseModel> _allCourses = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadRecentSearches();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService().getCategories();
      if (mounted) {
        setState(() {
          _filters = ['All', ...categories];
        });
      }
    } catch (e) {
      debugPrint('Error loading categories in SearchScreen: $e');
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final jsonStr = await _storage.read(key: _recentSearchesKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        if (mounted) {
          setState(() {
            _recentSearches = decoded.cast<String>();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      await _storage.write(
        key: _recentSearchesKey,
        value: jsonEncode(_recentSearches),
      );
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await CourseService().getCourses();
      if (mounted) {
        setState(() {
          _allCourses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading courses in SearchScreen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _triggerSearch(String query) {
    setState(() {
      _searchController.text = query;
      _hasQuery = query.isNotEmpty;
    });
    _addToRecent(query);
  }

  void _addToRecent(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 5) {
        _recentSearches.removeLast();
      }
    });
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
    _saveRecentSearches();
  }

  List<CourseModel> get _filteredCourses {
    final query = _searchController.text.trim().toLowerCase();
    
    // 1. Filter by query
    List<CourseModel> list = _allCourses;
    if (query.isNotEmpty) {
      list = list.where((course) {
        final titleMatch = course.title.toLowerCase().contains(query);
        final trainerMatch = course.trainerName.toLowerCase().contains(query);
        final descMatch = course.description.toLowerCase().contains(query);
        final catMatch = course.category.toLowerCase().contains(query);
        return titleMatch || trainerMatch || descMatch || catMatch;
      }).toList();
    }
    
    // 2. Filter by selected category chip filter
    if (_selectedFilter == 0) {
      return list;
    }
    
    final filterName = _filters[_selectedFilter];
    return list.where((c) =>
      c.category.toLowerCase().contains(filterName.toLowerCase())
    ).toList();
  }

  bool get _shouldShowResults => _hasQuery || _selectedFilter != 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(children: [
              // Search bar with Back button
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppShadows.card,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _hasQuery = v.isNotEmpty),
                      onSubmitted: (v) => _triggerSearch(v),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: T.get('search_placeholder'),
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textPrimary,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                        ),
                        suffixIcon: _hasQuery
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _searchController.clear();
                                  setState(() => _hasQuery = false);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Filter chips
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                slideOffset: const Offset(20, 0),
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final filterText = _filters[i];
                      final label = filterText == 'All' ? T.get('filter_all') : filterText;
                      return CategoryChip(
                        label: label,
                        isSelected: _selectedFilter == i,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = i);
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Content with animated transition
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _shouldShowResults
                      ? _buildResults(key: const ValueKey('results'))
                      : _buildRecent(key: const ValueKey('recent')),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRecent({Key? key}) {
    if (_recentSearches.isEmpty) {
      return Center(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            T.get('type_to_search'),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(T.get('recent_searches'), style: AppTextStyles.titleLarge),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _clearRecentSearches();
            },
            child: Text(T.get('clear_all'), style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 8),
        ...List.generate(_recentSearches.length, (i) {
          final s = _recentSearches[i];
          return FadeSlideIn(
            delay: Duration(milliseconds: 100 + i * 60),
            child: TapScale(
              onTap: () {
                HapticFeedback.selectionClick();
                _triggerSearch(s);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
                    Icon(Icons.north_west_rounded, size: 16, color: AppColors.textHint),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildResults({Key? key}) {
    if (_isLoading) {
      return Center(
        key: key,
        child: const CircularProgressIndicator(),
      );
    }

    final results = _filteredCourses;
    
    if (results.isEmpty) {
      return Center(
        key: key,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.subtle,
                ),
                child: Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                T.get('no_courses_found'),
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                T.get('no_courses_found_desc'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      key: key,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        childAspectRatio: 1.05,
      ),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final course = results[i];
        final color = i % 2 == 0 ? const Color(0xFFE8F0FE) : const Color(0xFFFFF3E0);
        
        return FadeSlideIn(
          delay: Duration(milliseconds: 100 + i * 80),
          child: CourseGridCard(
            title: course.title,
            instructor: course.trainerName,
            duration: '${course.totalDurationMinutes.toInt()} mins',
            lessons: course.totalVideos,
            thumbnailIcon: course.emoji,
            thumbnailColor: color,
            thumbnailUrl: course.thumbnailUrl,
            heroTag: 'search_course_${course.id}',
            isCompact: true,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => CourseDetailScreenV2(
                  course: course,
                  heroTag: 'search_course_${course.id}',
                ),
                transitionsBuilder: (_, animation, _, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            ),
          ),
        );
      },
    );
  }
}
