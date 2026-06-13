import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../models/app_models.dart';
import '../../../../services/wallet_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _courseNameCache = {};
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<String> _getTrainerName(String trainerId) async {
    if (_userNameCache.containsKey(trainerId)) {
      return _userNameCache[trainerId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('bharatam_users').doc(trainerId).get();
      if (doc.exists) {
        final name = doc.data()?['name'] ?? 'Unknown Trainer';
        _userNameCache[trainerId] = name;
        return name;
      }
    } catch (_) {}
    return 'Unknown Trainer';
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
        title: Text('Payments & Payouts', style: AppTextStyles.headlineSmall),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Withdrawals'),
            Tab(text: 'Trainer Wallets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(currencyFormat),
          _buildWithdrawalsTab(currencyFormat),
          _buildTrainerWalletsTab(currencyFormat),
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
            final trainerShare = (data['trainerShare'] ?? (amountPaid * 0.8)).toDouble();
            final platformCommission = (data['platformCommission'] ?? (amountPaid * 0.2)).toDouble();
            
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
                final displaySubtitle = '$courseName$purchaseTypeSuffix\nTrainer Share: ${currencyFormat.format(trainerShare)} • Platform: ${currencyFormat.format(platformCommission)}\nTrx: $transactionId';

                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + index * 50),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.subtle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
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
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint, height: 1.4),
                                maxLines: 3,
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
                            const SizedBox(height: 4),
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

  Widget _buildWithdrawalsTab(NumberFormat currencyFormat) {
    final df = DateFormat('MMM dd, yyyy • hh:mm a');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _walletService.getAllWithdrawalsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No withdrawal requests found'));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final req = WithdrawalRequestModel.fromMap(doc.data(), doc.id);

            return FutureBuilder<String>(
              future: _getTrainerName(req.trainerId),
              builder: (context, trainerSnapshot) {
                final trainerName = trainerSnapshot.data ?? 'Loading...';
                final isPending = req.status == 'pending';
                
                Color statusColor = AppColors.warning;
                if (req.status == 'approved') statusColor = AppColors.success;
                if (req.status == 'rejected') statusColor = AppColors.error;

                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + index * 50),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                      border: Border.all(color: AppColors.divider),
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
                                  Text(trainerName, style: AppTextStyles.titleLarge),
                                  const SizedBox(height: 2),
                                  Text(
                                    df.format(req.requestedAt),
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(req.amount),
                                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    req.status.toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Bank Account / Destination Details', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (req.bankAccount.isNotEmpty) ...[
                          _buildDetailRow(Icons.account_balance_rounded, 'Bank:', req.bankName),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.numbers_rounded, 'Account:', req.bankAccount),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.code_rounded, 'IFSC:', req.ifscCode),
                        ],
                        if (req.bankAccount.isEmpty && req.upiId.isNotEmpty) ...[
                          _buildDetailRow(Icons.qr_code_rounded, 'UPI ID:', req.upiId),
                        ],
                        if (req.status == 'rejected' && req.rejectionReason != null) ...[
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reason: ${req.rejectionReason}',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isPending) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _rejectRequestDialog(context, req.id),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _approveRequestConfirm(context, req.id, trainerName, req.amount, currencyFormat),
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const Text('Approve Payout'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildTrainerWalletsTab(NumberFormat currencyFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bharatam_wallets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No trainer wallets found'));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final trainerId = data['trainerId'] ?? doc.id;
            
            final balance = (data['balance'] ?? 0.0).toDouble();
            final totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
            final totalWithdrawn = (data['totalWithdrawn'] ?? 0.0).toDouble();
            final pendingWithdrawal = (data['pendingWithdrawal'] ?? 0.0).toDouble();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('bharatam_users').doc(trainerId).get(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final trainerName = userData?['name'] ?? 'Loading...';
                final phone = userData?['phoneNumber'] ?? '...';
                
                final bankName = userData?['bankName'] ?? '';
                final bankAccount = userData?['bankAccount'] ?? userData?['accountNumber'] ?? '';
                final ifscCode = userData?['ifscCode'] ?? '';
                final upiId = userData?['upiId'] ?? '';

                return FadeSlideIn(
                  delay: Duration(milliseconds: 100 + index * 50),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                      border: Border.all(color: AppColors.divider),
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
                                  Text(trainerName, style: AppTextStyles.titleLarge),
                                  Text(phone, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
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
                                'Bal: ${currencyFormat.format(balance)}',
                                style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        
                        // Wallet Stats Breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('Total Earnings', currencyFormat.format(totalEarnings)),
                            _buildStatItem('Total Withdrawn', currencyFormat.format(totalWithdrawn)),
                            _buildStatItem('Pending Payout', currencyFormat.format(pendingWithdrawal)),
                          ],
                        ),
                        const Divider(height: 20),

                        Text('Registered Payout Destination', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (bankAccount.isNotEmpty) ...[
                          _buildDetailRow(Icons.account_balance_rounded, 'Bank:', bankName),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.numbers_rounded, 'Acc No:', bankAccount),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.code_rounded, 'IFSC:', ifscCode),
                        ],
                        if (bankAccount.isEmpty && upiId.isNotEmpty) ...[
                          _buildDetailRow(Icons.qr_code_rounded, 'UPI ID:', upiId),
                        ],
                        if (bankAccount.isEmpty && upiId.isEmpty) ...[
                          Text('No payout accounts configured.', style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(
                                text: 'Trainer: $trainerName\nPhone: $phone\n'
                                      'Wallet Balance: ${currencyFormat.format(balance)}\n'
                                      'Total Earnings: ${currencyFormat.format(totalEarnings)}\n'
                                      'Total Withdrawn: ${currencyFormat.format(totalWithdrawn)}\n'
                                      'Pending Payouts: ${currencyFormat.format(pendingWithdrawal)}\n'
                                      'Bank: $bankName\nAcc: $bankAccount\nIFSC: $ifscCode\nUPI: $upiId'
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trainer Wallet details copied to clipboard')));
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy Wallet & Bank Info'),
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
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
      ],
    );
  }

  void _approveRequestConfirm(BuildContext context, String requestId, String trainerName, double amount, NumberFormat currencyFormat) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Confirm Payout'),
            ],
          ),
          content: Text(
            'Are you sure you have transferred ${currencyFormat.format(amount)} to $trainerName and want to approve this withdrawal request?',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textHint)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _walletService.approveWithdrawal(requestId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payout for $trainerName successfully approved!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Confirm & Approve', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _rejectRequestDialog(BuildContext context, String requestId) {
    HapticFeedback.heavyImpact();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Row(
            children: [
              Icon(Icons.cancel_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 10),
              Text('Reject Withdrawal'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please specify a reason for rejecting this withdrawal request. The funds will be restored to the trainer available balance.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Invalid bank credentials',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a rejection reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textHint)),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                final reason = reasonController.text.trim();
                try {
                  await _walletService.rejectWithdrawal(requestId, reason: reason);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Withdrawal request successfully rejected.'), backgroundColor: AppColors.error),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Reject Payout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
