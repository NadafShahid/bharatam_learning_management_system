import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../models/app_models.dart';
import '../../../../services/trainer_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _courseNameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<Map<String, String>> _getTransactionDetails(String userId, String courseId) async {
    if (_userNameCache.containsKey(userId) && _courseNameCache.containsKey(courseId)) {
      return {
        'studentName': _userNameCache[userId]!,
        'courseName': _courseNameCache[courseId]!,
      };
    }

    String studentName = _userNameCache[userId] ?? 'Loading...';
    String courseName = _courseNameCache[courseId] ?? 'Loading Course...';

    try {
      final List<Future> requests = [];
      
      if (!_userNameCache.containsKey(userId)) {
        requests.add(
          FirebaseFirestore.instance.collection('bharatam_users').doc(userId).get().then((doc) {
            if (doc.exists) {
              final name = doc.data()?['name'] ?? 'Unknown Student';
              _userNameCache[userId] = name;
              studentName = name;
            } else {
              _userNameCache[userId] = 'Unknown Student';
            }
          }),
        );
      }
      
      if (!_courseNameCache.containsKey(courseId)) {
        requests.add(
          FirebaseFirestore.instance.collection('bharatam_courses').doc(courseId).get().then((doc) {
            if (doc.exists) {
              final name = doc.data()?['courseName'] ?? doc.data()?['title'] ?? 'Unknown Course';
              _courseNameCache[courseId] = name;
              courseName = name;
            } else {
              _courseNameCache[courseId] = 'Unknown Course';
            }
          }),
        );
      }

      if (requests.isNotEmpty) {
        await Future.wait(requests);
      }
    } catch (e) {
      debugPrint('Error fetching transaction details: $e');
    }

    return {
      'studentName': studentName,
      'courseName': courseName,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Payments Management', style: AppTextStyles.headlineSmall),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Trainer Payouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(currencyFormat),
          _buildTrainerPayoutsTab(currencyFormat),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(NumberFormat currencyFormat) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchases').orderBy('purchasedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No transactions found'));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amountPaid = (data['amountPaid'] ?? 0).toDouble();
            final transactionId = data['transactionId'] ?? '';
            final purchaseType = data['purchaseType'] ?? 'course';
            final purchasedAt = (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            final userId = data['userId'] ?? '';
            final courseId = data['courseId'] ?? '';

            return FutureBuilder<Map<String, String>>(
              future: _getTransactionDetails(userId, courseId),
              builder: (context, detailsSnapshot) {
                final details = detailsSnapshot.data;
                final studentName = details?['studentName'] ?? 'Loading...';
                final courseName = details?['courseName'] ?? 'Loading Course...';
                final purchaseTypeSuffix = purchaseType == 'course' ? '' : ' (${purchaseType.toString().toUpperCase()})';

                final displayTitle = studentName;
                final displaySubtitle = '$courseName$purchaseTypeSuffix • Trx: $transactionId';

                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + index * 50),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle, 
                                style: AppTextStyles.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displaySubtitle, 
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('+${currencyFormat.format(amountPaid)}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success)),
                            Text(dateFormat.format(purchasedAt), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTrainerPayoutsTab(NumberFormat currencyFormat) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TrainerService().getTrainerRevenueList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final trainers = snapshot.data ?? [];

        if (trainers.isEmpty) {
          return const Center(child: Text('No trainers found'));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          itemCount: trainers.length,
          itemBuilder: (context, index) {
            final trainer = trainers[index];
            final revenue = trainer['totalRevenue'] as double;

            return FadeSlideIn(
              delay: Duration(milliseconds: 100 + index * 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trainer['name'], style: AppTextStyles.titleLarge),
                              Text(trainer['phone'], style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            currencyFormat.format(revenue),
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Bank Details', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.account_balance_rounded, 'Bank:', trainer['bankName'].toString().isEmpty ? 'Not provided' : trainer['bankName']),
                    const SizedBox(height: 4),
                    _buildDetailRow(Icons.numbers_rounded, 'Acc:', trainer['bankAccount'].toString().isEmpty ? 'Not provided' : trainer['bankAccount']),
                    const SizedBox(height: 4),
                    _buildDetailRow(Icons.code_rounded, 'IFSC:', trainer['ifscCode'].toString().isEmpty ? 'Not provided' : trainer['ifscCode']),
                    const SizedBox(height: 4),
                    _buildDetailRow(Icons.qr_code_rounded, 'UPI:', trainer['upiId'].toString().isEmpty ? 'Not provided' : trainer['upiId']),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: 'Trainer: ${trainer['name']}\nRevenue: ${currencyFormat.format(revenue)}\nBank: ${trainer['bankName']}\nAcc: ${trainer['bankAccount']}\nIFSC: ${trainer['ifscCode']}\nUPI: ${trainer['upiId']}'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details copied to clipboard')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
      ],
    );
  }
}
