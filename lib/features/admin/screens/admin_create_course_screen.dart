import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../services/course_service.dart';
import '../../../../services/category_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/bunny_stream_service.dart';
import '../../../../models/app_models.dart';

/// Admin version of Create Course — auto-approved status.
class AdminCreateCourseScreen extends StatefulWidget {
  const AdminCreateCourseScreen({super.key});

  @override
  State<AdminCreateCourseScreen> createState() => _AdminCreateCourseScreenState();
}

class _AdminCreateCourseScreenState extends State<AdminCreateCourseScreen> {
  final _scrollController = ScrollController();
  final _categoryKey = GlobalKey();
  List<String> _categories = CategoryService.fallbackCategories;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _limitedPriceController = TextEditingController();
  final _oneTimePriceController = TextEditingController();
  final _lifetimePriceController = TextEditingController();
  final _limitedTimeDaysController = TextEditingController();
  
  final _courseService = CourseService();
  final _categoryService = CategoryService();
  final _userService = UserService();
  
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
    _loadCategories();
    // Load local draft if present
    _loadDraftLocally();
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

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _limitedPriceController.dispose();
    _oneTimePriceController.dispose();
    _lifetimePriceController.dispose();
    _limitedTimeDaysController.dispose();
    for (final f in _courseFiles) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
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

  Future<void> _saveDraftLocally() async {
    setState(() => _isSavingDraft = true);
    try {
      final draftData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'limitedTimePrice': _limitedPriceController.text.trim(),
        'oneTimePrice': _oneTimePriceController.text.trim(),
        'lifetimePrice': _lifetimePriceController.text.trim(),
        'limitedTimeDays': _limitedTimeDaysController.text.trim(),
        'thumbnailUrl': _thumbnailUrl,
        'files': _courseFiles.map((f) => {
          'filePath': f.file?.path ?? '',
          'originalName': f.originalName,
          'type': f.type == CourseContentType.video ? 'video' : 'pdf',
          'thumbnailUrl': f.thumbnailUrl,
          'isFree': f.isFree,
          'name': f.nameController.text,
        }).toList(),
      };
      
      const storage = FlutterSecureStorage();
      await storage.write(key: 'admin_course_draft', value: jsonEncode(draftData));
      _showMessage('Draft saved locally on this device!');
    } catch (e) {
      _showMessage('Failed to save draft locally.', isError: true);
    } finally {
      setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _loadDraftLocally() async {
    try {
      const storage = FlutterSecureStorage();
      final draftStr = await storage.read(key: 'admin_course_draft');
      if (draftStr != null) {
        final draftData = jsonDecode(draftStr);
        setState(() {
          _titleController.text = draftData['title'] ?? '';
          _descriptionController.text = draftData['description'] ?? '';
          _selectedCategory = draftData['category'];
          _limitedPriceController.text = draftData['limitedTimePrice'] ?? '';
          _oneTimePriceController.text = draftData['oneTimePrice'] ?? '';
          _lifetimePriceController.text = draftData['lifetimePrice'] ?? '';
          _limitedTimeDaysController.text = draftData['limitedTimeDays'] ?? '30';
          _thumbnailUrl = draftData['thumbnailUrl'] ?? '';
          
          _courseFiles.clear();
          final List filesData = draftData['files'] ?? [];
          for (final fData in filesData) {
            final path = fData['filePath'] as String;
            final file = path.isNotEmpty ? File(path) : null;
            final type = fData['type'] == 'pdf' ? CourseContentType.pdf : CourseContentType.video;
            final courseFile = _CourseFile(
              file: file,
              originalName: fData['originalName'] ?? '',
              type: type,
            );
            courseFile.thumbnailUrl = fData['thumbnailUrl'] ?? '';
            courseFile.isFree = fData['isFree'] ?? false;
            courseFile.nameController.text = fData['name'] ?? '';
            _courseFiles.add(courseFile);
          }
        });
        _showMessage('Draft loaded from local device.');
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _publishCourse() async {
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

    setState(() => _isSubmitting = true);
    try {
      // Admin courses are auto-approved immediately
      final String courseId = await _courseService.createCourse(
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
        trainerName: 'Admin',
        isApproved: true,
        approvalStatus: 'approved',
      );

      // Upload content files
      for (final item in _courseFiles) {
        if (item.videoUrl != null) {
          await _courseService.uploadCourseContent(
            courseId: courseId,
            title: item.nameController.text.trim().isEmpty ? item.originalName.split('.').first : item.nameController.text.trim(),
            contentType: item.type,
            storageUrl: item.videoUrl!,
            fileName: item.originalName,
            bunnyVideoId: item.videoUrl!,
            autoApprove: true,
            thumbnailUrl: item.thumbnailUrl,
            isFree: item.isFree,
          );
        } else if (item.file != null) {
          if (mounted) {
            setState(() => item.isUploading = true);
          }
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
              autoApprove: true,
              thumbnailUrl: item.thumbnailUrl,
              isFree: item.isFree,
            );
          } else {
            // PDF from device to Firebase Storage
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.originalName}';
            final ref = FirebaseStorage.instance.ref().child('courses/$courseId/pdfs/$fileName');
            
            final uploadTask = ref.putFile(item.file!);
            
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
              autoApprove: true,
              thumbnailUrl: item.thumbnailUrl,
              isFree: item.isFree,
            );
          }
          if (mounted) {
            setState(() => item.isUploading = false);
          }
        }
      }

      // Clear draft locally after successful upload
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'admin_course_draft');

      if (!mounted) return;
      Navigator.pop(context, true);
      _showMessage('Course and all content published successfully!');
    } catch (e) {
      if (mounted) _showMessage('Unable to publish course. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
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
            // Auto-approved badge
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Upload',
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: AppColors.success)),
                          Text('Course will be auto-approved and visible immediately.',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Thumbnail Picker
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thumbnail', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  TapScale(
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
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.primary, width: 2),
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
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.image_rounded,
                                          size: 36, color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Upload Thumbnail',
                                        style: AppTextStyles.titleMedium
                                            .copyWith(color: AppColors.primary)),
                                    const SizedBox(height: 4),
                                    Text('JPG, PNG up to 5MB', style: AppTextStyles.bodySmall),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Form Fields
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _buildTextField('Course Title', 'e.g. Vedic Mathematics Masterclass', controller: _titleController),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: _buildTextField('Description', 'Describe your course...', controller: _descriptionController, maxLines: 4),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category Selection
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: _categoryKey,
                child: _buildDropdown('Category', _categories),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Access Pricing
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pricing Tiers', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
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

            // Course Content Upload Section
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
                        border: Border.all(color: AppColors.divider.withValues(alpha: 0.05)),
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
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
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
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
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
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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

            // Submit / Draft Actions
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
                        if (!_isSavingDraft && !_isSubmitting) _saveDraftLocally();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: GradientButton(
                      text: _isSubmitting ? 'Publishing...' : 'Publish Course',
                      icon: Icons.publish_rounded,
                      borderRadius: AppRadius.pill,
                      isLoading: _isSubmitting,
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        if (!_isSavingDraft && !_isSubmitting) _publishCourse();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
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
              dropdownColor: AppColors.surface,
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
