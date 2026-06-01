import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/status_badge.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../models/app_models.dart';
import '../../../../services/user_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _userService = UserService();
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('People', style: AppTextStyles.headlineLarge),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () => HapticFeedback.selectionClick(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _showFilterSheet(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.subtle,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.labelLarge,
                  onTap: (_) => HapticFeedback.selectionClick(),
                  tabs: const [Tab(text: 'Learners'), Tab(text: 'Trainers')],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildList(isTrainer: false),
                  _buildList(isTrainer: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.startsWith('+')) return phone;
    if (phone.length == 10) return '+91 $phone';
    return phone;
  }

  Widget _buildList({required bool isTrainer}) {
    return FutureBuilder<List<UserModel>>(
      key: ValueKey('${isTrainer ? 'trainers' : 'learners'}_$_reloadToken'),
      future: isTrainer ? _userService.getTrainers() : _userService.getLearners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              isTrainer ? 'No trainers found.' : 'No learners found.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isActive = !user.isBlocked;
            return FadeSlideIn(
              delay: Duration(milliseconds: 200 + index * 50),
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
                      width: 50, height: 50,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3E5F5)),
                      child: Center(child: Text(isTrainer ? '👨‍🏫' : '👨‍🎓', style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: AppTextStyles.titleMedium),
                          const SizedBox(height: 4),
                          Text(_formatPhone(user.phoneNumber), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(status: isActive ? BadgeStatus.active : BadgeStatus.blocked),
                        const SizedBox(height: 8),
                        TapScale(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            final updatedUser = UserModel(
                              id: user.id,
                              name: user.name,
                              phoneNumber: user.phoneNumber,
                              role: user.role,
                              profileImageUrl: user.profileImageUrl,
                              isBlocked: !user.isBlocked,
                              preferredLanguage: user.preferredLanguage,
                              bankName: user.bankName,
                              bankAccount: user.bankAccount,
                              ifscCode: user.ifscCode,
                              upiId: user.upiId,
                            );
                            await _userService.updateUserProfile(updatedUser);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(user.isBlocked ? 'User unblocked successfully' : 'User blocked successfully'),
                                  backgroundColor: user.isBlocked ? AppColors.success : AppColors.error,
                                ),
                              );
                              setState(() {
                                _reloadToken++;
                              });
                            }
                          },
                          child: Text(
                            isActive ? 'Block' : 'Unblock',
                            style: AppTextStyles.labelMedium.copyWith(color: isActive ? AppColors.error : AppColors.success),
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
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter Users', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              Text('Status', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('All'), selected: true, onSelected: (_) => HapticFeedback.selectionClick()),
                  ChoiceChip(label: const Text('Active'), selected: false, onSelected: (_) => HapticFeedback.selectionClick()),
                  ChoiceChip(label: const Text('Blocked'), selected: false, onSelected: (_) => HapticFeedback.selectionClick()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Registration Date', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('Any Time'), selected: true, onSelected: (_) => HapticFeedback.selectionClick()),
                  ChoiceChip(label: const Text('Last 7 Days'), selected: false, onSelected: (_) => HapticFeedback.selectionClick()),
                  ChoiceChip(label: const Text('Last 30 Days'), selected: false, onSelected: (_) => HapticFeedback.selectionClick()),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              GradientButton(
                text: 'Apply Filters',
                borderRadius: AppRadius.pill,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}
