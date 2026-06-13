import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../services/wallet_service.dart';
import '../../../../services/user_service.dart';
import '../../../../models/app_models.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final WalletService _walletService = WalletService();
  final UserService _userService = UserService();
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final trainerId = _userService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _walletService.getTrainerWalletStream(trainerId),
          builder: (context, walletSnapshot) {
            final walletData = walletSnapshot.data?.data();
            final double balance = (walletData?['balance'] ?? 0.0).toDouble();
            final double totalEarnings = (walletData?['totalEarnings'] ?? 0.0).toDouble();
            final double totalWithdrawn = (walletData?['totalWithdrawn'] ?? 0.0).toDouble();
            final double pendingWithdrawal = (walletData?['pendingWithdrawal'] ?? 0.0).toDouble();

            final isWalletLoading = walletSnapshot.connectionState == ConnectionState.waiting && walletData == null;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trainer Wallet', style: AppTextStyles.headlineLarge),
                          const SizedBox(height: 4),
                          Text('Manage your earnings & withdrawals', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Wallet Available Balance Card
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          gradient: AppGradients.orangeSunset,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                          boxShadow: AppShadows.elevated,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Available Balance',
                                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Secured',
                                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isWalletLoading ? '...' : currencyFormat.format(balance),
                              style: AppTextStyles.displayLarge.copyWith(color: Colors.white, fontSize: 38),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            GradientButton(
                              text: 'Withdraw Funds',
                              icon: Icons.account_balance_wallet_rounded,
                              gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
                              textColor: AppColors.primary,
                              onPressed: isWalletLoading
                                  ? null
                                  : () => _showWithdrawBottomSheet(context, balance, pendingWithdrawal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Grid Stats Card: Total Earnings, Total Withdrawn, Pending Payouts
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSmallStatsCard(
                              'Total Earnings',
                              isWalletLoading ? '...' : currencyFormat.format(totalEarnings),
                              Icons.trending_up_rounded,
                              AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildSmallStatsCard(
                              'Withdrawn',
                              isWalletLoading ? '...' : currencyFormat.format(totalWithdrawn),
                              Icons.check_circle_rounded,
                              AppColors.info,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildSmallStatsCard(
                              'Pending Payout',
                              isWalletLoading ? '...' : currencyFormat.format(pendingWithdrawal),
                              Icons.pending_actions_rounded,
                              AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Transaction Ledger Header
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transaction History', style: AppTextStyles.titleLarge),
                          const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),

                // Ledger Stream Builder
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _walletService.getTrainerLedgerStream(trainerId),
                  builder: (context, ledgerSnapshot) {
                    if (ledgerSnapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    final txDocs = ledgerSnapshot.data?.docs ?? [];

                    if (txDocs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.huge),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textHint.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions recorded yet.',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = txDocs[index];
                            final data = doc.data();
                            final tx = WalletTransactionModel.fromMap(data, doc.id);

                            return FadeSlideIn(
                              delay: Duration(milliseconds: 300 + (index * 50)),
                              child: _buildLedgerItem(tx),
                            );
                          },
                          childCount: txDocs.length,
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSmallStatsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerItem(WalletTransactionModel tx) {
    final df = DateFormat('MMM dd, yyyy • hh:mm a');
    
    IconData icon;
    Color color;
    String statusLabel = '';

    switch (tx.type) {
      case 'earnings_credit':
        icon = Icons.arrow_downward_rounded;
        color = AppColors.success;
        statusLabel = 'Credited';
        break;
      case 'withdrawal_request':
        icon = Icons.arrow_upward_rounded;
        color = AppColors.warning;
        statusLabel = 'Pending Review';
        break;
      case 'withdrawal_approval':
        icon = Icons.check_circle_outline_rounded;
        color = AppColors.info;
        statusLabel = 'Processed';
        break;
      case 'withdrawal_rejection':
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        statusLabel = 'Rejected';
        break;
      default:
        icon = Icons.receipt_long_rounded;
        color = AppColors.primary;
        statusLabel = tx.status;
    }

    final isCredit = tx.amount > 0 && tx.type == 'earnings_credit';
    final amountText = isCredit ? '+${currencyFormat.format(tx.amount)}' : currencyFormat.format(tx.amount);

    return Container(
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      statusLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        df.format(tx.timestamp),
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            amountText,
            style: AppTextStyles.titleLarge.copyWith(
              color: isCredit ? AppColors.success : (tx.type == 'withdrawal_rejection' ? AppColors.textHint : AppColors.textPrimary),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawBottomSheet(BuildContext context, double availableBalance, double pendingWithdrawal) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _WithdrawModal(
          availableBalance: availableBalance,
          pendingWithdrawal: pendingWithdrawal,
          walletService: _walletService,
          userService: _userService,
          currencyFormat: currencyFormat,
        );
      },
    );
  }
}

class _WithdrawModal extends StatefulWidget {
  final double availableBalance;
  final double pendingWithdrawal;
  final WalletService walletService;
  final UserService userService;
  final NumberFormat currencyFormat;

  const _WithdrawModal({
    required this.availableBalance,
    required this.pendingWithdrawal,
    required this.walletService,
    required this.userService,
    required this.currencyFormat,
  });

  @override
  State<_WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<_WithdrawModal> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  double _minThreshold = 1000.0;
  String? _backendError;
  Map<String, dynamic>? _bankDetails;

  @override
  void initState() {
    super.initState();
    _loadConfigAndProfile();
  }

  Future<void> _loadConfigAndProfile() async {
    setState(() => _isLoading = true);
    try {
      final threshold = await widget.walletService.getMinWithdrawalThreshold();
      final trainerId = widget.userService.currentUserId;
      final profileDoc = await FirebaseFirestore.instance.collection('bharatam_users').doc(trainerId).get();
      
      if (mounted) {
        setState(() {
          _minThreshold = threshold;
          if (profileDoc.exists) {
            _bankDetails = profileDoc.data();
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.heavyImpact();
    setState(() {
      _isLoading = true;
      _backendError = null;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final trainerId = widget.userService.currentUserId;

    try {
      // Execute the request via WalletService (which enforces validations inside Firestore Transaction)
      await widget.walletService.requestWithdrawal(
        trainerId: trainerId,
        amount: amount,
      );

      if (mounted) {
        Navigator.pop(context); // Close Bottom Sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Withdrawal request of ${widget.currencyFormat.format(amount)} submitted successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if duplicate requests exist locally as well
    final hasPendingRequest = widget.pendingWithdrawal > 0;
    
    final bankName = _bankDetails?['bankName'] ?? '';
    final bankAccount = _bankDetails?['bankAccount'] ?? _bankDetails?['accountNumber'] ?? '';
    final ifscCode = _bankDetails?['ifscCode'] ?? '';
    final upiId = _bankDetails?['upiId'] ?? '';
    final hasBankDetails = bankName.toString().isNotEmpty || bankAccount.toString().isNotEmpty || upiId.toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pull bar
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Request Payout', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 6),
            Text(
              'Specify the amount you wish to transfer to your bank account.',
              style: AppTextStyles.bodySmall,
            ),
            const Divider(height: 32),

            if (hasPendingRequest) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: AppColors.warning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You already have an active pending withdrawal request of ${widget.currencyFormat.format(widget.pendingWithdrawal)}. Please wait for Admin approval before requesting another.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.divider),
                  child: Text('Close', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            ] else if (widget.availableBalance < _minThreshold) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Minimum threshold of ${widget.currencyFormat.format(_minThreshold)} not reached. Your available balance is ${widget.currencyFormat.format(widget.availableBalance)}.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.divider),
                  child: Text('Close', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            ] else if (!hasBankDetails && !_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No bank account details or UPI ID found in your profile. Please configure them in the Profile screen to allow payouts.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.divider),
                  child: Text('Close', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            ] else ...[
              // Display Captured Bank/UPI Details
              if (_bankDetails != null) ...[
                Text('Payout Account Info', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bankAccount.toString().isNotEmpty) ...[
                        _buildProfileField(Icons.account_balance_rounded, 'Bank:', bankName),
                        const SizedBox(height: 6),
                        _buildProfileField(Icons.numbers_rounded, 'Acc No:', bankAccount),
                        const SizedBox(height: 6),
                        _buildProfileField(Icons.code_rounded, 'IFSC:', ifscCode),
                      ],
                      if (bankAccount.toString().isEmpty && upiId.toString().isNotEmpty) ...[
                        _buildProfileField(Icons.qr_code_rounded, 'UPI ID:', upiId),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Change payouts destination anytime from your Profile screen.',
                              style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal Amount (Min. ${widget.currencyFormat.format(_minThreshold)})',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                        hintText: 'Enter amount',
                        errorStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a payout amount';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'Please enter a valid positive amount';
                        }
                        if (parsed < _minThreshold) {
                          return 'Amount must be at least ₹${_minThreshold.toInt()}';
                        }
                        if (parsed > widget.availableBalance) {
                          return 'Amount cannot exceed available balance of ₹${widget.availableBalance.toInt()}';
                        }
                        return null;
                      },
                    ),
                    if (_backendError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _backendError!,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: _isLoading ? 'Submitting request...' : 'Confirm Withdrawal',
                        icon: Icons.check_circle_rounded,
                        gradient: AppGradients.primary,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _submitRequest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
