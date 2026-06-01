import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/category_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/gradient_button.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _categoryController = TextEditingController();
  final _categoryService = CategoryService();
  bool _isSaving = false;

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter category name.', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      await _categoryService.addCategory(name);
      _categoryController.clear();
      _showMessage('Category added successfully.');
    } catch (_) {
      _showMessage('Unable to add category. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Categories', style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Text('Add Category', style: AppTextStyles.labelLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: TextField(
                controller: _categoryController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isSaving) _addCategory();
                },
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  hintStyle:
                      AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: GradientButton(
                text: _isSaving ? 'Saving...' : 'Add Category',
                icon: Icons.add_rounded,
                isLoading: _isSaving,
                onPressed: () {
                  if (!_isSaving) _addCategory();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Text('Available Categories', style: AppTextStyles.labelLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: StreamBuilder<List<String>>(
                stream: _categoryService.watchCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? const <String>[];

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      categories.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }

                  if (categories.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < categories.length; i++) ...[
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.category_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              categories[i],
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          if (i != categories.length - 1)
                            Divider(
                              height: 1,
                              indent: 68,
                              color: AppColors.divider.withValues(alpha: 0.5),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          'No categories added yet',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        ),
      ),
    );
  }
}
