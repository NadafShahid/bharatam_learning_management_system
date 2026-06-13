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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _activeMetric = 'Total Sales';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _graphKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<_AdminDashboardStats> _loadDashboardStats() async {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('bharatam_users').where('role', isEqualTo: 'student').get(),
      db.collection('bharatam_users').where('role', isEqualTo: 'trainer').get(),
      db.collection('bharatam_courses').where('isApproved', isEqualTo: true).get(),
      db.collection('purchases').where('status', isEqualTo: 'success').get(),
      db
          .collection('bharatam_withdrawal_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get(),
    ]);

    final studentsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final trainersSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final coursesSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final purchasesSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;

    double totalSales = 0;
    double totalTrainerEarnings = 0;
    double totalPlatformRevenue = 0;

    final List<Map<String, dynamic>> purchaseData = [];

    for (final doc in purchasesSnapshot.docs) {
      final amount = doc.data()['amountPaid'];
      double amountPaid = 0.0;
      if (amount is num) {
        amountPaid = amount.toDouble();
      } else if (amount != null) {
        amountPaid = double.tryParse(amount.toString()) ?? 0.0;
      }
      totalSales += amountPaid;

      final purchasedAt = _parseDateTime(doc.data()['purchasedAt']) ?? DateTime.now();
      purchaseData.add({
        'date': purchasedAt,
        'amount': amountPaid,
      });

      final trainerShareVal = doc.data()['trainerShare'];
      double trainerShare = 0.0;
      if (trainerShareVal is num) {
        trainerShare = trainerShareVal.toDouble();
      } else if (trainerShareVal != null) {
        trainerShare = double.tryParse(trainerShareVal.toString()) ?? (amountPaid * 0.8);
      } else {
        trainerShare = amountPaid * 0.8;
      }
      totalTrainerEarnings += trainerShare;

      final platformCommissionVal = doc.data()['platformCommission'];
      double platformCommission = 0.0;
      if (platformCommissionVal is num) {
        platformCommission = platformCommissionVal.toDouble();
      } else if (platformCommissionVal != null) {
        platformCommission = double.tryParse(platformCommissionVal.toString()) ?? (amountPaid * 0.2);
      } else {
        platformCommission = amountPaid * 0.2;
      }
      totalPlatformRevenue += platformCommission;
    }

    final List<DateTime> userCreatedDates = [];
    for (final doc in studentsSnapshot.docs) {
      final dt = _parseDateTime(doc.data()['createdAt']);
      if (dt != null) userCreatedDates.add(dt);
    }

    final List<DateTime> trainerCreatedDates = [];
    for (final doc in trainersSnapshot.docs) {
      final dt = _parseDateTime(doc.data()['createdAt']);
      if (dt != null) trainerCreatedDates.add(dt);
    }

    final List<DateTime> courseCreatedDates = [];
    for (final doc in coursesSnapshot.docs) {
      final dt = _parseDateTime(doc.data()['createdAt']);
      if (dt != null) courseCreatedDates.add(dt);
    }

    return _AdminDashboardStats(
      totalUsers: studentsSnapshot.docs.length,
      totalTrainers: trainersSnapshot.docs.length,
      activeCourses: coursesSnapshot.docs.length,
      totalSales: totalSales,
      totalTrainerEarnings: totalTrainerEarnings,
      totalPlatformRevenue: totalPlatformRevenue,
      pendingWithdrawals: (results[4] as AggregateQuerySnapshot).count ?? 0,
      userCreatedDates: userCreatedDates,
      trainerCreatedDates: trainerCreatedDates,
      courseCreatedDates: courseCreatedDates,
      purchaseData: purchaseData,
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

  Color _getMetricColor() {
    switch (_activeMetric) {
      case 'Total Users':
        return AppColors.primary;
      case 'Total Trainers':
        return AppColors.secondary;
      case 'Total Sales':
        return AppColors.success;
      case 'Active Courses':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.primary;
    }
  }

  List<FlSpot> _generateChartSpots(_AdminDashboardStats stats) {
    final totalDays = _endDate.difference(_startDate).inDays;

    if (totalDays <= 31) {
      // Group by day
      List<FlSpot> spots = [];
      for (int i = 0; i <= totalDays; i++) {
        final currentDate = _startDate.add(Duration(days: i));
        final cutoff = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59, 999);
        double value = 0;

        if (_activeMetric == 'Total Users') {
          value = stats.userCreatedDates.where((d) => d.isBefore(cutoff)).length.toDouble();
        } else if (_activeMetric == 'Total Trainers') {
          value = stats.trainerCreatedDates.where((d) => d.isBefore(cutoff)).length.toDouble();
        } else if (_activeMetric == 'Active Courses') {
          value = stats.courseCreatedDates.where((d) => d.isBefore(cutoff)).length.toDouble();
        } else if (_activeMetric == 'Total Sales') {
          value = stats.purchaseData
              .where((p) =>
                  (p['date'] as DateTime).year == currentDate.year &&
                  (p['date'] as DateTime).month == currentDate.month &&
                  (p['date'] as DateTime).day == currentDate.day)
              .fold(0.0, (sum, p) => sum + (p['amount'] as double));
        }
        spots.add(FlSpot(i.toDouble(), value));
      }
      return spots;
    } else {
      // Group by month
      final months = _getMonthsInRange();
      List<FlSpot> spots = [];
      for (int i = 0; i < months.length; i++) {
        final m = months[i];
        final endOfMonth = DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999);
        double value = 0;

        if (_activeMetric == 'Total Users') {
          value = stats.userCreatedDates.where((d) => d.isBefore(endOfMonth)).length.toDouble();
        } else if (_activeMetric == 'Total Trainers') {
          value = stats.trainerCreatedDates.where((d) => d.isBefore(endOfMonth)).length.toDouble();
        } else if (_activeMetric == 'Active Courses') {
          value = stats.courseCreatedDates.where((d) => d.isBefore(endOfMonth)).length.toDouble();
        } else if (_activeMetric == 'Total Sales') {
          value = stats.purchaseData
              .where((p) =>
                  (p['date'] as DateTime).year == m.year &&
                  (p['date'] as DateTime).month == m.month)
              .fold(0.0, (sum, p) => sum + (p['amount'] as double));
        }
        spots.add(FlSpot(i.toDouble(), value));
      }
      return spots;
    }
  }

  List<DateTime> _getMonthsInRange() {
    List<DateTime> months = [];
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    DateTime endLimit = DateTime(_endDate.year, _endDate.month, 1);
    while (!current.isAfter(endLimit)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _onMetricCardTapped(String metric) {
    setState(() {
      _activeMetric = metric;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _graphKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _formatTooltipValue(double val) {
    if (_activeMetric == 'Total Sales') {
      return _formatRevenue(val);
    } else {
      return val.toInt().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
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
                                  isActive: _activeMetric == 'Total Users',
                                  onTap: () => _onMetricCardTapped('Total Users'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Trainers',
                                  isLoading ? '...' : _formatCount(stats?.totalTrainers ?? 0),
                                  Icons.school_rounded,
                                  AppColors.secondary,
                                  isActive: _activeMetric == 'Total Trainers',
                                  onTap: () => _onMetricCardTapped('Total Trainers'),
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
                                  'Total Sales',
                                  isLoading ? '...' : _formatRevenue(stats?.totalSales ?? 0),
                                  Icons.account_balance_wallet_rounded,
                                  AppColors.success,
                                  isActive: _activeMetric == 'Total Sales',
                                  onTap: () => _onMetricCardTapped('Total Sales'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: _buildStatCard(
                                  'Active Courses',
                                  isLoading ? '...' : _formatCount(stats?.activeCourses ?? 0),
                                  Icons.library_books_rounded,
                                  const Color(0xFF8B5CF6),
                                  isActive: _activeMetric == 'Active Courses',
                                  onTap: () => _onMetricCardTapped('Active Courses'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 260),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(color: AppColors.divider),
                              boxShadow: AppShadows.subtle,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Marketplace Revenue Splits', style: AppTextStyles.titleMedium),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSplitsCard(
                                        'Trainer Share (80%)',
                                        isLoading ? '...' : _formatRevenue(stats?.totalTrainerEarnings ?? 0),
                                        Icons.school_rounded,
                                        AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: _buildSplitsCard(
                                        'Platform Fee (20%)',
                                        isLoading ? '...' : _formatRevenue(stats?.totalPlatformRevenue ?? 0),
                                        Icons.percent_rounded,
                                        AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSplitsCard(
                                        'Pending Withdrawals',
                                        isLoading ? '...' : '${stats?.pendingWithdrawals ?? 0} Pending',
                                        Icons.pending_actions_rounded,
                                        AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Graph Container (Nested FutureBuilder to reload dynamically when date or active metric changes)
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: Container(
                            key: _graphKey,
                            height: 320,
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(color: AppColors.divider),
                              boxShadow: AppShadows.cardHover,
                            ),
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : stats == null
                                    ? const Center(child: Text('No stats data available'))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _activeMetric,
                                                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                                                  ),
                                                ],
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                                                onPressed: () => _selectDateRange(context),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                final spots = _generateChartSpots(stats);
                                                final metricColor = _getMetricColor();
                                                
                                                double maxVal = 0;
                                                for (final spot in spots) {
                                                  if (spot.y > maxVal) {
                                                    maxVal = spot.y;
                                                  }
                                                }
                                                double maxYVal = maxVal == 0 ? 10 : maxVal * 1.2;
                                                final totalDays = _endDate.difference(_startDate).inDays;
                                                double maxXVal = totalDays <= 31 
                                                    ? totalDays.toDouble() 
                                                    : (_getMonthsInRange().length > 1 ? (_getMonthsInRange().length - 1).toDouble() : 1.0);

                                                return LineChart(
                                                  LineChartData(
                                                    gridData: FlGridData(
                                                      show: true,
                                                      drawVerticalLine: false,
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
                                                          interval: 1,
                                                          getTitlesWidget: (value, meta) {
                                                            final style = TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold);
                                                            final index = value.toInt();
                                                            if (index < 0) return const SizedBox();

                                                            Widget text = const SizedBox();
                                                            if (totalDays <= 31) {
                                                              final interval = totalDays <= 7 ? 1 : (totalDays / 5).round();
                                                              if (index % interval == 0 && index <= totalDays) {
                                                                final date = _startDate.add(Duration(days: index));
                                                                text = Text(DateFormat('dd MMM').format(date), style: style);
                                                              }
                                                            } else {
                                                              final months = _getMonthsInRange();
                                                              if (index < months.length) {
                                                                final interval = months.length <= 6 ? 1 : 2;
                                                                if (index % interval == 0) {
                                                                  final date = months[index];
                                                                  text = Text(DateFormat('MMM yy').format(date), style: style);
                                                                }
                                                              }
                                                            }
                                                            return SideTitleWidget(meta: meta, space: 8, child: text);
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    borderData: FlBorderData(show: false),
                                                    minX: 0,
                                                    maxX: maxXVal,
                                                    minY: 0,
                                                    maxY: maxYVal,
                                                    lineBarsData: [
                                                      LineChartBarData(
                                                        spots: spots,
                                                        isCurved: true,
                                                        color: metricColor,
                                                        barWidth: 4,
                                                        isStrokeCapRound: true,
                                                        dotData: const FlDotData(show: false),
                                                        belowBarData: BarAreaData(
                                                          show: true,
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              metricColor.withValues(alpha: 0.3),
                                                              metricColor.withValues(alpha: 0.0),
                                                            ],
                                                            begin: Alignment.topCenter,
                                                            end: Alignment.bottomCenter,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    lineTouchData: LineTouchData(
                                                      touchTooltipData: LineTouchTooltipData(
                                                        getTooltipColor: (_) => metricColor,
                                                        getTooltipItems: (touchedSpots) {
                                                          return touchedSpots.map((spot) => LineTooltipItem(
                                                            _formatTooltipValue(spot.y),
                                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                          )).toList();
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  duration: const Duration(milliseconds: 500),
                                                  curve: Curves.easeOutCubic,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
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
            
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: isActive ? AppShadows.cardHover : AppShadows.card,
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.8) : AppColors.divider.withValues(alpha: 0.5),
            width: isActive ? 2.0 : 1.0,
          ),
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

  Widget _buildSplitsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardStats {
  final int totalUsers;
  final int totalTrainers;
  final int activeCourses;
  final double totalSales;
  final double totalTrainerEarnings;
  final double totalPlatformRevenue;
  final int pendingWithdrawals;
  final List<DateTime> userCreatedDates;
  final List<DateTime> trainerCreatedDates;
  final List<DateTime> courseCreatedDates;
  final List<Map<String, dynamic>> purchaseData;

  const _AdminDashboardStats({
    required this.totalUsers,
    required this.totalTrainers,
    required this.activeCourses,
    required this.totalSales,
    required this.totalTrainerEarnings,
    required this.totalPlatformRevenue,
    required this.pendingWithdrawals,
    required this.userCreatedDates,
    required this.trainerCreatedDates,
    required this.courseCreatedDates,
    required this.purchaseData,
  });
}
