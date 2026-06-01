import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../screens/auth/login_screen.dart';
import 'admin_create_course_screen.dart';
import 'admin_update_course_screen.dart';
import 'admin_manage_content_screen.dart';
import 'admin_manage_ads_screen.dart';
import 'admin_chat_list_screen.dart';
import 'admin_categories_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<_AdminDashboardStats> _loadDashboardStats() async {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db
          .collection('bharatam_users')
          .where('role', isEqualTo: 'student')
          .count()
          .get(),
      db
          .collection('bharatam_users')
          .where('role', isEqualTo: 'trainer')
          .count()
          .get(),
      db
          .collection('bharatam_courses')
          .where('isApproved', isEqualTo: true)
          .count()
          .get(),
      db.collection('purchases').where('status', isEqualTo: 'success').get(),
    ]);

    final purchasesSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
    double revenue = 0;
    for (final doc in purchasesSnapshot.docs) {
      final amount = doc.data()['amountPaid'];
      if (amount is num) {
        revenue += amount.toDouble();
      } else if (amount != null) {
        revenue += double.tryParse(amount.toString()) ?? 0;
      }
    }

    return _AdminDashboardStats(
      totalUsers: (results[0] as AggregateQuerySnapshot).count ?? 0,
      totalTrainers: (results[1] as AggregateQuerySnapshot).count ?? 0,
      activeCourses: (results[2] as AggregateQuerySnapshot).count ?? 0,
      revenue: revenue,
    );
  }

  String _formatCount(int count) => NumberFormat.decimalPattern('en_IN').format(count);

  String _formatRevenue(double amount) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return currencyFormat.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard', style: AppTextStyles.headlineLarge),
                          const SizedBox(height: AppSpacing.sm),
                          Text('System Overview', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<_AdminDashboardStats>(
                  future: _loadDashboardStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshot.hasError) ...[
                          Text(
                            'Unable to load live dashboard stats',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total Users',
                                  isLoading ? '...' : _formatCount(stats?.totalUsers ?? 0),
                                  Icons.people_alt_rounded,
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Trainers',
                                  isLoading ? '...' : _formatCount(stats?.totalTrainers ?? 0),
                                  Icons.school_rounded,
                                  AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Revenue',
                                  isLoading ? '...' : _formatRevenue(stats?.revenue ?? 0),
                                  Icons.account_balance_wallet_rounded,
                                  AppColors.success,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: _buildStatCard(
                                  'Active Courses',
                                  isLoading ? '...' : _formatCount(stats?.activeCourses ?? 0),
                                  Icons.library_books_rounded,
                                  const Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // Quick Actions
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 280),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreateCourseScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Create Course',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUpdateCourseScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.secondary,
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Update Course',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageContentScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Promote Courses',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageAdsScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.ads_click_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Manage Ads',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.category_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Add Category',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TapScale(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatListScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.elevated,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Student Chats',
                                        style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.cardHover,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 20,
                            getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final style = TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.bold);
                                  Widget text;
                                  switch (value.toInt()) {
                                    case 0: text = Text('Jan', style: style); break;
                                    case 2: text = Text('Mar', style: style); break;
                                    case 4: text = Text('May', style: style); break;
                                    case 6: text = Text('Jul', style: style); break;
                                    case 8: text = Text('Sep', style: style); break;
                                    case 10: text = Text('Nov', style: style); break;
                                    default: text = Text('', style: style); break;
                                  }
                                  return SideTitleWidget(meta: meta, space: 8, child: text);
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 11,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 20),
                                FlSpot(1, 35),
                                FlSpot(2, 40),
                                FlSpot(3, 30),
                                FlSpot(4, 55),
                                FlSpot(5, 60),
                                FlSpot(6, 45),
                                FlSpot(7, 80),
                                FlSpot(8, 75),
                                FlSpot(9, 90),
                                FlSpot(10, 85),
                                FlSpot(11, 100),
                              ],
                              isCurved: true,
                              gradient: AppGradients.primary,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.3),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppColors.primary,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) => LineTooltipItem(
                                  '₹${(spot.y * 10).toInt()}k',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )).toList();
                              },
                            ),
                          ),
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return TapScale(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(value, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardStats {
  final int totalUsers;
  final int totalTrainers;
  final int activeCourses;
  final double revenue;

  const _AdminDashboardStats({
    required this.totalUsers,
    required this.totalTrainers,
    required this.activeCourses,
    required this.revenue,
  });
}
