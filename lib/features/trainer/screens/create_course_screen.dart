import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../services/course_service.dart';
import '../../../../services/category_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/bunny_stream_service.dart';

import '../../../../models/app_models.dart';

class CreateCourseScreen extends StatefulWidget {
  final CourseModel? existingCourse;

  const CreateCourseScreen({super.key, this.existingCourse});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _scrollController = ScrollController();
  final _categoryKey = GlobalKey();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _limitedPriceController = TextEditingController();
  final _oneTimePriceController = TextEditingController();
  final _lifetimePriceController = TextEditingController();
  final _limitedTimeDaysController = TextEditingController();
  final _courseService = CourseService();
  final _categoryService = CategoryService();
  final _userService = UserService();
  List<String> _categories = CategoryService.fallbackCategories;
  String? _selectedCategory;
  String _thumbnailUrl = '';
  bool _isSavingDraft = false;
  bool _isSubmitting = false;
  bool _isUploadingThumbnail = false;
  final List<_CourseFile> _courseFiles = [];

  @override
  void initState() {
    super.initState();
    _limitedTimeDaysController.text = '30';
    if (widget.existingCourse != null) {
      final c = widget.existingCourse!;
      _titleController.text = c.title;
      _descriptionController.text = c.description;
      _priceController.text = c.price.toString();
      _limitedPriceController.text = c.limitedTimePrice != null ? c.limitedTimePrice!.toStringAsFixed(0) : (c.price * 0.5).toStringAsFixed(0);
      _oneTimePriceController.text = c.oneTimePrice != null ? c.oneTimePrice!.toStringAsFixed(0) : c.price.toStringAsFixed(0);
      _lifetimePriceController.text = c.lifetimePrice != null ? c.lifetimePrice!.toStringAsFixed(0) : (c.price * 1.5).toStringAsFixed(0);
      _limitedTimeDaysController.text = c.limitedTimeDays != null ? c.limitedTimeDays!.toString() : '30';
      _selectedCategory = c.category;
      _thumbnailUrl = c.thumbnailUrl;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories =
            categories.isNotEmpty ? categories : CategoryService.fallbackCategories;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = CategoryService.fallbackCategories;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Optimize image size
    );
    
    if (image != null) {
      HapticFeedback.mediumImpact();
      setState(() => _isUploadingThumbnail = true);
      try {
        final file = File(image.path);
        final fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('course_thumbnails/$fileName');
        
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        
        setState(() {
          _thumbnailUrl = url;
          _isUploadingThumbnail = false;
        });
        _showMessage('Thumbnail uploaded successfully.');
      } catch (e) {
        setState(() => _isUploadingThumbnail = false);
        _showMessage('Failed to upload thumbnail. Please try again.', isError: true);
      }
    }
  }

  Future<void> _pickVideoThumbnail(_CourseFile item) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    
    if (image != null) {
      HapticFeedback.mediumImpact();
      setState(() => item.isUploadingThumbnail = true);
      try {
        final file = File(image.path);
        final fileName = 'video_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('video_thumbnails/$fileName');
        
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        
        setState(() {
          item.thumbnailUrl = url;
          item.isUploadingThumbnail = false;
        });
        _showMessage('Video thumbnail uploaded successfully.');
      } catch (e) {
        setState(() => item.isUploadingThumbnail = false);
        _showMessage('Failed to upload video thumbnail. Please try again.', isError: true);
      }
    }
  }

  Future<void> _pickContent(CourseContentType type) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: type == CourseContentType.video ? FileType.video : FileType.custom,
        allowedExtensions: type == CourseContentType.pdf ? ['pdf'] : null,
      );

      if (result != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          for (final file in result.files) {
            if (file.path != null) {
              _courseFiles.add(_CourseFile(
                file: File(file.path!),
                originalName: file.name,
                type: type,
              ));
            }
          }
        });
      }
    } catch (e) {
      _showMessage('Unable to pick files.', isError: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _limitedPriceController.dispose();
    _oneTimePriceController.dispose();
    _lifetimePriceController.dispose();
    _limitedTimeDaysController.dispose();
    for (final f in _courseFiles) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Create Course', style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_isSavingDraft || _isSubmitting) {
              _showMessage('Please wait for uploads to complete.', isError: true);
              return;
            }
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Text('Thumbnail', style: AppTextStyles.labelLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: TapScale(
                onTap: () {
                  if (!_isUploadingThumbnail && !_isSavingDraft && !_isSubmitting) {
                    _pickThumbnail();
                  }
                },
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.primary, width: 1.5, style: BorderStyle.solid),
                    image: _thumbnailUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _isUploadingThumbnail
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                        )
                      : _thumbnailUrl.isNotEmpty
                          ? null
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppColors.primary),
                                const SizedBox(height: 8),
                                Text('Choose from Device', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _buildTextField('Course Title', 'Enter course title', controller: _titleController),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: _buildTextField('Description', 'Enter course description', controller: _descriptionController, maxLines: 4),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: _categoryKey,
                child: _buildDropdown('Category', _categories),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Limited Time (₹)', 'e.g. 499', controller: _limitedPriceController, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField('One Time (₹)', 'e.g. 999', controller: _oneTimePriceController, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField('Life Time (₹)', 'e.g. 1499', controller: _lifetimePriceController, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTextField('Limited Access Duration (Days)', 'e.g. 30', controller: _limitedTimeDaysController, keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FadeSlideIn(
              delay: const Duration(milliseconds: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    children: [
                      Text('Course Content', style: AppTextStyles.labelLarge),
                      Wrap(
                        spacing: 0,
                        children: [
                          TextButton.icon(
                            onPressed: (_isSavingDraft || _isSubmitting) ? null : () => _pickContent(CourseContentType.video),
                            icon: const Icon(Icons.video_call_rounded, size: 20, color: AppColors.primary),
                            label: Text('Add Video', style: TextStyle(color: AppColors.primary.withOpacity((_isSavingDraft || _isSubmitting) ? 0.5 : 1.0), fontSize: 13)),
                          ),
                          TextButton.icon(
                            onPressed: (_isSavingDraft || _isSubmitting) ? null : () => _pickContent(CourseContentType.pdf),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: AppColors.primary),
                            label: Text('Add PDF', style: TextStyle(color: AppColors.primary.withOpacity((_isSavingDraft || _isSubmitting) ? 0.5 : 1.0), fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_courseFiles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.divider.withOpacity(0.05)),
                      ),
                      child: Center(
                        child: Text('No videos or PDFs added yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _courseFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = _courseFiles[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    item.type == CourseContentType.video ? Icons.play_circle_fill_rounded : Icons.description_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: TextField(
                                      controller: item.nameController,
                                      enabled: !_isSavingDraft && !_isSubmitting,
                                      style: AppTextStyles.bodyMedium,
                                      decoration: const InputDecoration(
                                        hintText: 'Content Title',
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  if (!_isSavingDraft && !_isSubmitting)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 20),
                                      onPressed: () => setState(() => _courseFiles.removeAt(index)),
                                    ),
                                ],
                              ),
                              Divider(height: 12, thickness: 0.5, color: AppColors.divider),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Text(
                                      'Access Type:',
                                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                                    ),
                                    const Spacer(),
                                    ChoiceChip(
                                      label: const Text('Free Preview', style: TextStyle(fontSize: 12)),
                                      selected: item.isFree,
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      onSelected: (_isSavingDraft || _isSubmitting)
                                          ? null
                                          : (selected) {
                                              if (selected) {
                                                HapticFeedback.selectionClick();
                                                setState(() => item.isFree = true);
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('Paid Only', style: TextStyle(fontSize: 12)),
                                      selected: !item.isFree,
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      onSelected: (_isSavingDraft || _isSubmitting)
                                          ? null
                                          : (selected) {
                                              if (selected) {
                                                HapticFeedback.selectionClick();
                                                setState(() => item.isFree = false);
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                              if (item.type == CourseContentType.video) ...[
                                Divider(height: 12, thickness: 0.5, color: AppColors.divider),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Video Thumbnail:',
                                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      if (item.isUploadingThumbnail)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      else if (item.thumbnailUrl.isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(AppRadius.xs),
                                          child: Image.network(
                                            item.thumbnailUrl,
                                            width: 48,
                                            height: 36,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        TextButton(
                                          onPressed: (_isSavingDraft || _isSubmitting)
                                              ? null
                                              : () => _pickVideoThumbnail(item),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Change',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ] else
                                        ElevatedButton.icon(
                                          onPressed: (_isSavingDraft || _isSubmitting)
                                              ? null
                                              : () => _pickVideoThumbnail(item),
                                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 14),
                                          label: const Text('Add Thumbnail'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary.withOpacity(0.08),
                                            foregroundColor: AppColors.primary,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.sm),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (item.isUploading)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: item.progress,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      color: AppColors.primary,
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      text: 'Save Draft',
                      gradient: AppGradients.secondary,
                      isLoading: _isSavingDraft,
                      onPressed: () {
                        if (!_isSavingDraft && !_isSubmitting) _saveCourse(isDraft: true);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: GradientButton(
                      text: _isSubmitting ? 'Submitting...' : 'Submit',
                      isLoading: _isSubmitting,
                      onPressed: () {
                        if (!_isSavingDraft && !_isSubmitting) _saveCourse(isDraft: false);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {required TextEditingController controller, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enabled: !_isSavingDraft && !_isSubmitting,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    final dropdownItems = [
      ...items,
      if (_selectedCategory != null && !items.contains(_selectedCategory))
        _selectedCategory!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              hint: Text('Select $label', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              items: dropdownItems.map((e) => DropdownMenuItem(value: e, child: Text(e, style: AppTextStyles.bodyMedium))).toList(),
              onChanged: (_isSavingDraft || _isSubmitting) ? null : (value) => setState(() => _selectedCategory = value),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCourse({required bool isDraft}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Please enter course title.', isError: true);
      return;
    }

    final selectedCategory = _selectedCategory?.trim();
    if (selectedCategory == null || selectedCategory.isEmpty) {
      _scrollToCategory();
      _showMessage('Please select a category before uploading the course.', isError: true);
      return;
    }
    
    final description = _descriptionController.text.trim();
    final limitedPrice = double.tryParse(_limitedPriceController.text.trim()) ?? 0.0;
    final oneTimePrice = double.tryParse(_oneTimePriceController.text.trim()) ?? 0.0;
    final lifetimePrice = double.tryParse(_lifetimePriceController.text.trim()) ?? 0.0;
    final limitedDays = int.tryParse(_limitedTimeDaysController.text.trim()) ?? 30;
    // Fallback price for backward compatibility is oneTimePrice
    final price = oneTimePrice > 0 ? oneTimePrice : (limitedPrice > 0 ? limitedPrice : lifetimePrice);

    setState(() {
      if (isDraft) _isSavingDraft = true;
      else _isSubmitting = true;
    });
    try {
      String courseId;
      final status = isDraft ? 'draft' : 'pending';
      if (widget.existingCourse != null) {
        courseId = widget.existingCourse!.id;
        await _courseService.updateCourse(
          courseId: courseId,
          title: title,
          description: description,
          category: selectedCategory,
          price: price,
          limitedTimePrice: limitedPrice,
          oneTimePrice: oneTimePrice,
          lifetimePrice: lifetimePrice,
          limitedTimeDays: limitedDays,
          thumbnailUrl: _thumbnailUrl,
          approvalStatus: status,
        );
      } else {
        courseId = await _courseService.createCourse(
          title: title,
          description: description,
          category: selectedCategory,
          price: price,
          limitedTimePrice: limitedPrice,
          oneTimePrice: oneTimePrice,
          lifetimePrice: lifetimePrice,
          limitedTimeDays: limitedDays,
          thumbnailUrl: _thumbnailUrl,
          trainerId: _userService.currentUserId,
          trainerName: 'Trainer',
          approvalStatus: status,
        );
      }

      // Upload newly added files
      for (final item in _courseFiles) {
        if (item.videoUrl != null) {
          // Video URL input by the user, saved directly without Firebase storage upload
          await _courseService.uploadCourseContent(
            courseId: courseId,
            title: item.nameController.text.trim().isEmpty ? item.originalName.split('.').first : item.nameController.text.trim(),
            contentType: item.type,
            storageUrl: item.videoUrl!,
            fileName: item.originalName,
            bunnyVideoId: item.videoUrl!, // Using URL as ID for now
            autoApprove: false, // Always pending for newly created courses
            thumbnailUrl: item.thumbnailUrl,
            isFree: item.isFree,
          );
        } else if (item.file != null) {
          setState(() => item.isUploading = true);
          if (item.type == CourseContentType.video) {
            // Upload to Bunny Stream
            final bunnyService = BunnyStreamService();
            final bunnyResult = await bunnyService.uploadVideo(
              file: item.file!,
              title: item.nameController.text.trim().isEmpty ? item.originalName.split('.').first : item.nameController.text.trim(),
              onProgress: (progress) {
                if (mounted) {
                  setState(() {
                    item.progress = progress;
                  });
                }
              },
            );

            if (bunnyResult == null) {
              throw Exception('Failed to upload video to Bunny Stream');
            }

            await _courseService.uploadCourseContent(
              courseId: courseId,
              title: item.nameController.text.trim().isEmpty ? item.originalName.split('.').first : item.nameController.text.trim(),
              contentType: item.type,
              storageUrl: bunnyResult['storageUrl']!,
              fileName: item.originalName,
              bunnyVideoId: bunnyResult['bunnyVideoId']!,
              autoApprove: false, // Always pending for newly created courses
              thumbnailUrl: item.thumbnailUrl,
              isFree: item.isFree,
            );
          } else {
            // PDF/File from device to Firebase Storage
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.originalName}';
            final ref = FirebaseStorage.instance.ref().child('courses/$courseId/pdfs/$fileName');
            
            final uploadTask = ref.putFile(item.file!);
            
            // Listen to progress updates
            uploadTask.snapshotEvents.listen((event) {
              if (mounted) {
                setState(() {
                  item.progress = event.bytesTransferred / event.totalBytes;
                });
              }
            });

            await uploadTask;
            final url = await ref.getDownloadURL();
            
            await _courseService.uploadCourseContent(
              courseId: courseId,
              title: item.nameController.text.trim().isEmpty ? item.originalName.split('.').first : item.nameController.text.trim(),
              contentType: item.type,
              storageUrl: url,
              fileName: item.originalName,
              bunnyVideoId: '',
              autoApprove: false, // Always pending for newly created courses
              thumbnailUrl: item.thumbnailUrl,
              isFree: item.isFree,
            );
          }
          setState(() => item.isUploading = false);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      _showMessage(isDraft
          ? 'Course draft and content saved.'
          : 'Course and content submitted for admin approval.');
    } catch (e) {
      if (mounted) _showMessage('Unable to save course. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _scrollToCategory() {
    final context = _categoryKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }
}

class _CourseFile {
  final File? file;
  final String? videoUrl;
  final String originalName;
  final TextEditingController nameController;
  final CourseContentType type;
  bool isUploading = false;
  double progress = 0.0;
  String thumbnailUrl = '';
  bool isUploadingThumbnail = false;
  bool isFree = false;

  _CourseFile({
    this.file,
    this.videoUrl,
    required this.originalName,
    required this.type,
  }) : nameController = TextEditingController(text: originalName.split('.').first);

  void dispose() {
    nameController.dispose();
  }
}
