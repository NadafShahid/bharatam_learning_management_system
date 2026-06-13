import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animations.dart';
import '../../widgets/module_accordion.dart';
import '../../widgets/bunny_storage_image.dart';
import '../../services/subscription_service.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/instructor_avatar.dart';
import '../home/trainer_profile_screen.dart';

class CoursePlanDetailsScreen extends StatefulWidget {
  final CourseModel course;
  final String planType; // 'limited', 'onetime', 'lifetime'
  final double price;
  final VoidCallback? onPurchaseSuccess;

  const CoursePlanDetailsScreen({
    super.key,
    required this.course,
    required this.planType,
    required this.price,
    this.onPurchaseSuccess,
  });

  @override
  State<CoursePlanDetailsScreen> createState() => _CoursePlanDetailsScreenState();
}

class _CoursePlanDetailsScreenState extends State<CoursePlanDetailsScreen> {
  bool _isSubscribed = false;
  bool _isPurchasing = false;
  late AccessControl _accessControl = const AccessControl();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final UserService _userService = UserService();
  late Razorpay _razorpay;

  String get _planTitle => switch (widget.planType) {
        'limited' => 'Limited Time Access',
        'onetime' => 'One Time Access',
        'lifetime' => 'Life Time Access',
        _ => 'Course Access Plan',
      };

  String get _planDuration => switch (widget.planType) {
        'limited' => '30 Days Access',
        'onetime' => '1 Year Access',
        'lifetime' => 'Lifetime Access',
        _ => 'Unlimited Access',
      };

  String get _planSubtitle => switch (widget.planType) {
        'limited' => 'Perfect for quick learners who want 30 days of full access.',
        'onetime' => 'Standard option offering 365 days of full study access.',
        'lifetime' => 'Our ultimate package providing forever access to all content.',
        _ => '',
      };

  IconData get _planIcon => switch (widget.planType) {
        'limited' => Icons.access_time_rounded,
        'onetime' => Icons.calendar_today_rounded,
        'lifetime' => Icons.all_inclusive_rounded,
        _ => Icons.school_rounded,
      };

  Color get _accentColor => switch (widget.planType) {
        'limited' => AppColors.info,
        'onetime' => AppColors.primary,
        'lifetime' => AppColors.secondary,
        _ => AppColors.primary,
      };

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _checkSubscription();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    try {
      final userId = _userService.currentUserId;
      final realPurchases = await _userService.getUserPurchases(userId);
      if (mounted) {
        setState(() {
          _accessControl = AccessControl(purchases: realPurchases);
        });
      }
    } catch (_) {}
  }

  Future<void> _checkSubscription() async {
    try {
      final subscribed = await _subscriptionService.isSubscribed(widget.course.trainerId);
      if (mounted) {
        setState(() => _isSubscribed = subscribed);
      }
    } catch (_) {}
  }

  bool _isModuleUnlocked(ModuleModel module) {
    for (final p in _accessControl.purchases) {
      if (p.courseId == widget.course.id &&
          p.purchaseType == PurchaseType.course) {
        if (p.planType == 'limited') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 30) continue;
        } else if (p.planType == 'onetime') {
          final difference = DateTime.now().difference(p.purchasedAt).inDays;
          if (difference > 365) continue;
        }
        return true;
      }
      if (p.courseId == widget.course.id &&
          p.moduleId == module.id &&
          p.purchaseType == PurchaseType.module) {
        return true;
      }
    }
    return false;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final double amountPaid = widget.price;
    final double trainerShare = amountPaid * 0.8;
    final double platformCommission = amountPaid * 0.2;
    final transactionId = response.paymentId ?? 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    try {
      final purchaseRef = await FirebaseFirestore.instance.collection('purchases').add({
        'userId': _userService.currentUserId,
        'courseId': widget.course.id,
        'moduleId': null,
        'videoId': null,
        'purchaseType': 'course',
        'amountPaid': amountPaid,
        'trainerId': widget.course.trainerId,
        'trainerShare': trainerShare,
        'platformCommission': platformCommission,
        'transactionId': transactionId,
        'status': 'success',
        'purchasedAt': FieldValue.serverTimestamp(),
        'planType': widget.planType,
        'razorpayOrderId': response.orderId,
        'razorpaySignature': response.signature,
      });

      // Credit trainer share into their wallet balance
      await WalletService().creditTrainerWallet(
        purchaseId: purchaseRef.id,
        trainerId: widget.course.trainerId,
        trainerShare: trainerShare,
        amountPaid: amountPaid,
        description: 'Earnings from ${widget.course.title} (Course)',
      );

      if (widget.onPurchaseSuccess != null) {
        widget.onPurchaseSuccess!();
      }

      // Send WhatsApp Receipt
      WhatsAppService.sendPurchaseReceipt(
        courseTitle: widget.course.title,
        price: amountPaid,
        transactionId: transactionId,
        planType: widget.planType,
        purchaseType: 'course',
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save purchase details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message ?? "Unknown Error"} (Code: ${response.code})'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External Wallet selected: ${response.walletName}'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  Future<void> _handleBuyNow() async {
    HapticFeedback.heavyImpact();
    setState(() => _isPurchasing = true);

    String userEmail = 'student@example.com';
    String userPhone = '9999999999';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userService.currentUserId).get();
      if (userDoc.exists) {
        userEmail = userDoc.data()?['email'] ?? userEmail;
        userPhone = userDoc.data()?['phone'] ?? userPhone;
      }
    } catch (_) {}

    var options = {
      'key': 'rzp_test_SPs6AqG8E3r2Cp',
      'amount': (widget.price * 100).toInt(), // Razorpay expects amount in paise
      'name': 'Bharatam LMS',
      'description': 'Purchase Course: ${widget.course.title} ($_planTitle)',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isPurchasing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open payment gateway: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Text('Success!', style: AppTextStyles.headlineSmall),
          ],
        ),
        content: Text(
          'Congratulations! You have successfully unlocked ${widget.course.title} under the $_planTitle tier.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            child: Text('Start Learning', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx); // Pop Dialog
              Navigator.pop(context); // Pop Plan details Screen
              Navigator.pop(context); // Pop Bottom Sheet
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Plan Banner Card
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: widget.planType == 'lifetime'
                                ? AppGradients.secondary
                                : LinearGradient(colors: [_accentColor, _accentColor.withValues(alpha: 0.8)]),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: AppShadows.subtle,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_planIcon, color: Colors.white, size: 28),
                                  const SizedBox(width: AppSpacing.md),
                                  Text(
                                    _planTitle,
                                    style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _planDuration,
                                style: AppTextStyles.titleMedium.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _planSubtitle,
                                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // SECTION 1: ABOUT PAGE
                      Text('About this course', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.course.description,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      
                      Text("What you'll learn", style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      ...['Foundation concepts', 'Historical context', 'Practical applications', 'Advanced techniques']
                          .map((i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.check_rounded,
                                        size: 14, color: AppColors.success),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(i, style: AppTextStyles.bodyMedium),
                                ]),
                              )),
                      const SizedBox(height: AppSpacing.xxl),
                      
                      // Instructor Card
                      Text('Instructor', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.md),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrainerProfileScreen(
                                instructor: InstructorData(
                                  id: widget.course.trainerId,
                                  name: widget.course.trainerName,
                                  emoji: '👨‍🏫',
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: AppShadows.subtle,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: Color(0xFFF3E5F5)),
                                child: const Center(
                                    child: Text('👨‍🏫',
                                        style: TextStyle(fontSize: 28))),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.course.trainerName,
                                        style: AppTextStyles.titleMedium),
                                    const SizedBox(height: 4),
                                    Text('Expert Trainer',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(color: AppColors.textHint)),
                                  ],
                                ),
                              ),
                              TapScale(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  if (_isSubscribed) {
                                    await _subscriptionService.unsubscribe(widget.course.trainerId);
                                  } else {
                                    await _subscriptionService.subscribe(widget.course.trainerId);
                                  }
                                  setState(() => _isSubscribed = !_isSubscribed);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isSubscribed
                                        ? AppColors.surface
                                        : AppColors.primary,
                                    border: Border.all(
                                        color: _isSubscribed
                                            ? AppColors.border
                                            : AppColors.primary),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    _isSubscribed ? 'Subscribed' : 'Subscribe',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: _isSubscribed
                                          ? AppColors.primary
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.huge),

                      // SECTION 2: CURRICULUM MODULES
                      Row(
                        children: [
                          Text('Course Curriculum', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${widget.course.modules.length} Modules',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.course.modules.length,
                        itemBuilder: (context, index) {
                          final module = widget.course.modules[index];
                          final isModuleUnlocked = _isModuleUnlocked(module);
                          return ModuleAccordion(
                            module: module,
                            isUnlocked: isModuleUnlocked,
                            courseId: widget.course.id,
                            accessControl: _accessControl,
                            onVideoTap: (_) {},
                            onBuyModule: (_) {},
                            onBuyVideo: (_) {},
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.huge),

                      // SECTION 3: PRICING DETAILS & CHECKOUT SUMMARY
                      Text('Plan Pricing', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.md),
                      Container(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Base Plan Price', style: AppTextStyles.bodyMedium),
                                Text('₹${widget.price.toInt()}', style: AppTextStyles.titleMedium),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Taxes & GST (18%)', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                                Text('₹0', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Grand Total', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  '₹${widget.price.toInt()}',
                                  style: AppTextStyles.headlineMedium.copyWith(color: _accentColor, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120), // Bottom spacing for fixed Buy Now button
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Fixed Pinned Buy Now Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppShadows.bottomNav,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Plan Amount', style: AppTextStyles.labelSmall),
                        Text('₹${widget.price.toInt()}',
                            style: AppTextStyles.headlineMedium.copyWith(color: _accentColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: GradientButton(
                        text: _isPurchasing ? 'Processing...' : 'Buy Now',
                        borderRadius: AppRadius.pill,
                        gradient: widget.planType == 'lifetime'
                            ? AppGradients.secondary
                            : LinearGradient(colors: [_accentColor, _accentColor.withValues(alpha: 0.9)]),
                        icon: Icons.flash_on_rounded,
                        isLoading: _isPurchasing,
                        onPressed: () {
                          if (!_isPurchasing) {
                            _handleBuyNow();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            image: widget.course.thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: bunnyStorageNetworkImage(widget.course.thumbnailUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                  )
                : null,
            gradient: widget.course.thumbnailUrl.isEmpty
                ? LinearGradient(colors: [AppColors.textPrimary, AppColors.textPrimary.withValues(alpha: 0.8)])
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.course.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curriculum, About & Checkout',
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: Container(
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
          ),
        ),
      ],
    );
  }
}
